// SPDX-License-Identifier: MIT

/* 
__        __      _    _          _      
\ \      / /__ __| |__| | ___  __| | ___ 
 \ \ /\ / / _ \ '__|  __| |/ _ \/ _` |/ _ \
  \ V  V /  __/ |  | |  | |  __/ (_| |  __/
   \_/\_/ \___|_|   \__|_|\___|\__,_|\___|
                                           
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {ERC20Votes} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Nonces} from "@openzeppelin/contracts/utils/Nonces.sol";

/**
 * @title WeWakeCoin
 * @dev ERC20 токен с механизмами голосования и отложенного сжигания токенов.
 */
contract WeWakeCoin is ERC20, ERC20Permit, ERC20Votes, Ownable {
    // --- Ошибки (Custom Errors) для экономии газа ---
    error BurnProcessAlreadyActive();
    error BurnAmountZero();
    error InsufficientBalanceToBurn();
    error BurnProcessNotInitiated();
    error BurnTimelockNotExpired(uint256 current, uint256 required);

    // --- События ---
    event OpenBurn(uint256 burnPossibleFromTimestamp, uint256 amount);
    event FinishBurn(uint256 timestamp, uint256 amount);

    // Константа времени блокировки: 2.5 дня
    // Использование времени (timestamp) надежнее, чем номер блока (block.number) для L2 сетей
    uint256 public constant BURN_TIMELOCK = 2 days + 12 hours;

    // Временная метка, после которой возможно сжигание. 0, если процесс не запущен.
    uint256 private _burnPossibleFromTimestamp;

    constructor(address initialOwner) 
        ERC20("WeWakeCoin", "WAKE") 
        ERC20Permit("WeWakeCoin") 
        Ownable(initialOwner) 
    {
        // 2.15 миллиарда токенов. Используем underscores для читаемости.
        _mint(initialOwner, 2_150_000_000 * 10**decimals());
    }

    /**
     * @notice Возвращает информацию о текущем процессе сжигания.
     */
    function burnInfo() external view returns (uint256 possibleFromTimestamp, uint256 amount) {
        if (_burnPossibleFromTimestamp != 0) {
            possibleFromTimestamp = _burnPossibleFromTimestamp;
            amount = balanceOf(address(this));
        }
    }

    /**
     * @notice Запускает процесс сжигания. Токены блокируются на контракте.
     * @dev Доступно только владельцу.
     * @param amount Количество токенов для сжигания.
     */
    function openBurn(uint256 amount) external onlyOwner {
        if (_burnPossibleFromTimestamp != 0) revert BurnProcessAlreadyActive();
        if (amount == 0) revert BurnAmountZero();
        if (amount > balanceOf(msg.sender)) revert InsufficientBalanceToBurn();

        // Переводим токены на контракт для блокировки
        _transfer(msg.sender, address(this), amount);

        _burnPossibleFromTimestamp = block.timestamp + BURN_TIMELOCK;
        emit OpenBurn(_burnPossibleFromTimestamp, amount);
    }

    /**
     * @notice Завершает процесс сжигания после истечения таймлока.
     */
    function finishBurn() external {
        uint256 unlockTime = _burnPossibleFromTimestamp;
        
        if (unlockTime == 0) revert BurnProcessNotInitiated();
        if (block.timestamp < unlockTime) revert BurnTimelockNotExpired(block.timestamp, unlockTime);

        uint256 amountToBurn = balanceOf(address(this));
        
        _burn(address(this), amountToBurn);
        _burnPossibleFromTimestamp = 0;
        
        emit FinishBurn(block.timestamp, amountToBurn);
    }

    // --- Overrides (требуются Solidity для разрешения конфликтов наследования) ---

    function nonces(address owner) public view virtual override(ERC20Permit, Nonces) returns (uint256) {
        return super.nonces(owner);
    }

    function _update(address from, address to, uint256 amount) internal override(ERC20, ERC20Votes) {
        super._update(from, to, amount);
    }
}
