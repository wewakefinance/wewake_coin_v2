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

    /**
     * @notice Emitted when ERC20 tokens are rescued from the contract
     * @param token Address of the rescued token
     * @param to Recipient of the rescued tokens
     * @param amount Amount of tokens rescued
     */
    event TokensRescued(address indexed token, address indexed to, uint256 amount);

    /**
     * @notice Emitted when contract is paused
     * @param account Address that triggered the pause
     */
    event ContractPaused(address indexed account);

    // Константа времени блокировки: 2.5 дня
    // Использование времени (timestamp) надежнее, чем номер блока (block.number) для L2 сетей
    uint256 public constant BURN_TIMELOCK = 2 days + 12 hours;

    // Временная метка, после которой возможно сжигание. 0, если процесс не запущен.
    uint256 private _burnPossibleFromTimestamp;
    // Сумма, заблокированная для сжигания при вызове `openBurn`.
    uint256 private _burnAmount;

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
            amount = _burnAmount;
        }
    }

    /**
     * @notice Pauses all token transfers
     * @dev Only callable by contract owner (multisig). Used in emergency situations.
     * Requirements:
     * - Caller must be the owner
     * - Contract must not already be paused
     */
    function pause() external onlyOwner {
        _pause();
        emit ContractPaused(_msgSender());
    }

    /**
     * @notice Unpauses all token transfers
     * @dev Only callable by contract owner (multisig)
     * Requirements:
     * - Caller must be the owner
     * - Contract must be paused
     */
    function unpause() external onlyOwner {
        _unpause();
        emit ContractUnpaused(_msgSender());
    }

    /**
     * @notice Burns tokens from caller's balance with enhanced logging
     * @param amount Amount of tokens to burn
     * @dev Overrides ERC20Burnable.burn to add custom event
     * Requirements:
     * - Caller must have at least `amount` tokens
     */
    function burn(uint256 amount) public override {
        super.burn(amount);
        emit TokensBurned(_msgSender(), amount, totalSupply());
    }

    /**
     * @notice Завершает процесс сжигания после истечения таймлока.
     */
    function finishBurn() external {
        uint256 unlockTime = _burnPossibleFromTimestamp;
        
        if (unlockTime == 0) revert BurnProcessNotInitiated();
        if (block.timestamp < unlockTime) revert BurnTimelockNotExpired(block.timestamp, unlockTime);

        uint256 amountToBurn = _burnAmount;

        _burn(address(this), amountToBurn);
        _burnAmount = 0;
        _burnPossibleFromTimestamp = 0;

        emit FinishBurn(block.timestamp, amountToBurn);
    }

    /**
     * @notice Rescues ERC20 tokens mistakenly sent to this contract
     * @param token Address of the ERC20 token to rescue
     * @param to Recipient address for the rescued tokens
     * @param amount Amount of tokens to rescue
     * @dev Only callable by contract owner (multisig)
     * 
     * Security considerations:
     * - Cannot rescue WAKE tokens to prevent owner from stealing user funds
     * - Only rescues tokens that were mistakenly sent to contract
     * 
     * Requirements:
     * - Caller must be the owner
     * - `token` cannot be this contract's address
     * - Contract must have sufficient balance of `token`
     */
    function rescueERC20(address token, address to, uint256 amount) external onlyOwner {
        require(token != address(this), "WeWake: cannot rescue WAKE tokens");
        require(to != address(0), "WeWake: recipient is zero address");
        require(amount > 0, "WeWake: amount must be greater than 0");

        IERC20(token).safeTransfer(to, amount);
        emit TokensRescued(token, to, amount);
    }

    // --- Overrides (требуются Solidity для разрешения конфликтов наследования) ---

    function nonces(address owner) public view virtual override(ERC20Permit, Nonces) returns (uint256) {
        return super.nonces(owner);
    }

    function _update(address from, address to, uint256 amount) internal override(ERC20, ERC20Votes) {
        super._update(from, to, amount);
    }
}
