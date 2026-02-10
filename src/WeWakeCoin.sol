// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {ERC20Votes} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import {ERC20Pausable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import {Nonces} from "@openzeppelin/contracts/utils/Nonces.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title WeWakeCoin
 * @dev ERC20 токен с механизмами голосования и отложенного сжигания токенов.
 */
/// @title WeWakeCoin
/// @notice ERC20 токен для токеномики WeWake, с поддержкой governance, pausable, two-step ownership, burn с таймлоком, recovery, без минтинга после деплоя.
contract WeWakeCoin is ERC20, ERC20Permit, ERC20Votes, ERC20Pausable, Ownable2Step {
    using SafeERC20 for IERC20;

    /**
     * @notice Get the current nonce for a given owner.
     * @dev Overrides ERC20Permit and Nonces to query validity.
     * @param owner The address of the account to check.
     * @return The current nonce.
     */
    function nonces(address owner) public view override(ERC20Permit, Nonces) returns (uint256) {
        return super.nonces(owner);
    }
    address public multisig;
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
    event ContractPaused(address indexed account);
    event ContractUnpaused(address indexed account);
    event TokensBurned(address indexed account, uint256 amount, uint256 totalSupply);
    event FinishBurn(uint256 timestamp, uint256 amount);

    // Константа времени блокировки: 2.5 дня
    // Использование времени (timestamp) надежнее, чем номер блока (block.number) для L2 сетей
    uint256 public constant BURN_TIMELOCK = 2 days + 12 hours;

    /**
     * @notice Initializes the contract and distributes initial supply.
     * @dev Mints 10% to team, 10% to eco, 10% to treasury, and 70% to owner. Sets initial owner and multisig.
     * @param owner_ Address of the initial owner and multisig wallet.
     * @param team_ Address of the team wallet.
     * @param eco_ Address of the ecosystem wallet.
     * @param treasury_ Address of the treasury wallet.
     */
    constructor(address owner_, address team_, address eco_, address treasury_)
uint256 private _burnPossibleFromTimestamp;
    // Сумма, заблокированная для сжигания при вызове `openBurn`.
    uint256 private _burnAmount;

        constructor(address owner_, address team_, address eco_, address treasury_)
            ERC20("WeWakeCoin", "WAKE")
            ERC20Permit("WeWakeCoin")
            Ownable2Step(owner_)
        {
        transferOwnership(owner_);
            // Токеномика: 10% team, 10% eco, 10% treasury, 70% owner (multисиг)
    /**
     * @notice Checks if the caller is an admin (owner or multisig).
     * @dev Internal function used by onlyAdmin modifier. Reverts if caller is not authorized.
     */
    function _checkAdmin() internal view {
        require(msg.sender == owner() || msg.sender == multisig, "WeWake: not admin");
    }

    /**
     * @notice Returns details about the active burn process.
     * @dev Useful for UI to display burn schedule.
     * @return possibleFromTimestamp Timestamp when burn determines execution (0 if not active).
     * @return amount Amount of tokens locked for burning
            transferOwnership(owner_);
        }
    modifier onlyAdmin() {
        _checkAdmin();
        _;
    }

    function _checkAdmin() internal view .
     * @dev Can only be called by admin. Triggers stopped state.
     */
    function pause() external onlyAdmin {
        _pause();
        emit ContractPaused(_msgSender());
    }

    /**
     * @notice Resumes all token transfers.
     * @dev Can only be called by admin. Returns to normal state.
     */

    /**
     * @notice Pauses all token transfers
     * @dev Only callable by contract owner (multisig). Used in emergency situations.
     * Requirements:
     * - Caller must be the owner
     * - Contract must not already be paused
     */
    /// @notice Приостановить все трансферы токенов (только multisig/owner)
    function pause() external onlyAdmin {
        _pause();
        emit ContractPaused(_msgSender());
    }

    /// @notice Возобновить все трансферы токенов (только multisig/owner)
    function unpause() external onlyAdmin {
        _unpause();
        emit ContractUnpaused(_msgSender());
    }

    /**
     * @notice Initiates a timelocked token burn process.
     * @dev Locks tokens in the contract. Burn can be executed after BURN_TIMELOCK.
     * @param amount Amount of tokens to lock for burning.
     */
    function openBurn(uint256 amount) external onlyAdmin whenNotPaused {
        if (_burnPossibleFromTimestamp != 0) revert BurnProcessAlreadyActive();
        if (amount == 0) revert BurnAmountZero();
        if (balanceOf(address(this)) < amount) revert InsufficientBalanceToBurn();
        _burnPossibleFromTimestamp = block.timestamp + BURN_TIMELOCK;
        _burnAmount = amount;
    }

    /**
     * @notice Executes the scheduled burn after timelock expires.
     * @dev Reverts if timelock hasn't passed or if no burn is active.
     */
    function finishBurn() external onlyAdmin whenNotPaused {
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
     * @notice Cancels an active burn process and returns tokens.
     * @dev Resets burn state variables and transfers tokens back to the admin.
     */
    function cancelBurn() external onlyAdmin whenNotPaused {
        uint256 amount = _burnAmount;
        _burnPossibleFromTimestamp = 0;
        _burnAmount = 0;
        if (amount > 0) {
            _transfer(address(this), msg.sender, amount);
        }covers ERC20 tokens mistakenly sent to this contract.
     * @dev Uses SafeERC20 for secure transfer. Cannot rescue WAKE tokens.
     * @param token Address of the token contract to rescue.
     * @param to Address where tokens will be sent.
     * @param amount Amount of tokens to transfer.
     */
     * - `token` cannot be this contract's address
     * - Contract must have sufficient balance of `token`
     */
    /// @notice Владелец может вернуть ошибочно отправленные токены (кроме WAKE)
    function rescueERC20(address token, address to, uint256 amount) external onlyAdmin {
        require(token != address(this), "WeWake: cannot rescue WAKE tokens");
        require(to != address(0), "WeWake: recipient is zero address");
        require(amount > 0, "WeWake: amount must be greater than 0");
        IERC20(token).safeTransfer(to, amount);
        emit TokensRescued(token, to, amount);
    }

    /**
     * @notice Recovers ETH sent to this contract.
     * @dev Uses low-level call to transfer ETH.
     * @param to Address where ETH will be sent.
     * @param amount Amount of ETH in wei to transfer.
     */
    function rescueEth(address payable to, uint256 amount) external onlyAdmin {
        require(to != address(0), "WeWake: zero address");
        require(amount > 0, "WeWake: amount must be greater than 0");
        (bool sent, ) = to.call{value: amount}("");
        require(sent, "WeWake: failed to send ETH");
    }

    /**
     * @notice Updates the multisig wallet address.
     * @dev Can only be called by the contract owner.
     * @param newMultisig Address of the new multisig wallet.
     */
    function setMultisSolidity overrides for inheritance conflict resolution) ---

    /**
     * @notice Hook that is called before any transfer of tokens.
     * @dev Checks for paused state and calls parent _update.
     * @param from Address sending tokens.
     * @param to Address receiving tokens.
     * @param amount Amount of tokens transferred.
     */    }

    // --- Overrides (требуются Solidity для разрешения конфликтов наследования) ---

    // --- Overrides для корректного наследования (Certik, OZ) ---

    function _update(address from, address to, uint256 amount)
        internal
        override(ERC20, ERC20Votes, ERC20Pausable)
    {
        if (paused()) revert("WeWake: token transfer while paused");
        super._update(from, to, amount);
    }

}
