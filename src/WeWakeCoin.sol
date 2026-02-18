// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

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
 * @dev ERC20 contract with governance, scheduled burning, and pausing mechanisms.
 * @notice ERC20 token for WeWake tokenomics, supporting governance, pausable transfers, two-step ownership, timelocked burning, recovery, and no minting after deploy.
 */
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

    // --- Custom Errors for Gas Efficiency ---

    /// @notice Error thrown when trying to start a burn while another is active.
    error BurnProcessAlreadyActive();

    /// @notice Error thrown when the burn amount is zero.
    error BurnAmountZero();

    /// @notice Error thrown when the contract balance is less than the burn amount.
    error InsufficientBalanceToBurn();

    /// @notice Error thrown when trying to finish a burn that wasn't started.
    error BurnProcessNotInitiated();

    /// @notice Error thrown when trying to finish a burn before the timelock expires.
    /// @param current The current block timestamp.
    /// @param required The timestamp when the burn can be executed.
    error BurnTimelockNotExpired(uint256 current, uint256 required);

    /**
     * @notice Emitted when ERC20 tokens are rescued from the contract.
     * @param token Address of the rescued token.
     * @param to Recipient of the rescued tokens.
     * @param amount Amount of tokens rescued.
     */
    event TokensRescued(address indexed token, address indexed to, uint256 amount);

    /**
     * @notice Emitted when the contract is paused.
     * @param account The address that triggered the pause.
     */
    event ContractPaused(address indexed account);

    /**
     * @notice Emitted when the contract is unpaused.
     * @param account The address that triggered the unpause.
     */
    event ContractUnpaused(address indexed account);

    /**
     * @notice Emitted when tokens are burned.
     * @param account The address from which tokens were burned.
     * @param amount The amount of tokens burned.
     * @param totalSupply The new total supply after burning.
     */
    event TokensBurned(address indexed account, uint256 amount, uint256 totalSupply);

    /**
     * @notice Emitted when a scheduled burn is executed.
     * @param timestamp The time when the burn was executed.
     * @param amount The amount of tokens burned.
     */
    event FinishBurn(uint256 timestamp, uint256 amount);

    /**
     * @notice Timelock duration for the burn process.
     * @dev Set to 2.5 days (2 days + 12 hours). Using timestamp is safer than blocks for L2s.
     */
    uint256 public constant BURN_TIMELOCK = 2 days + 12 hours;

    /**
     * @notice Timestamp when the burn process can be finalized.
     * @dev 0 if no burn process is active.
     */
    uint256 private _burnPossibleFromTimestamp;

    /**
     * @notice Amount of tokens locked for the pending burn process.
     */
    uint256 private _burnAmount;

    /**
     * @notice Struct to hold initial distribution addresses.
     */
    struct InitialDistribution {
        address presale;
        address liquidity;
        address ecosystem;
        address treasury;
        address rewards;
        address staking;
        address reserve;
        address team;
        address marketing;
    }

    /**
     * @notice Initializes the contract and distributes initial supply.
     * @dev Mints tokens strictly according to the tokenomics distribution.
     * @param owner_ Address of the initial owner (should be a multisig wallet / Timelock).
     * @param dist Struct containing addresses for all 9 categories.
     */
    constructor(address owner_, InitialDistribution memory dist)
        ERC20("WeWakeCoin", "WAKE")
        ERC20Permit("WeWakeCoin")
        Ownable2Step(owner_)
    {
        // Check for zero addresses
        if (
            dist.presale == address(0) ||
            dist.liquidity == address(0) ||
            dist.ecosystem == address(0) ||
            dist.treasury == address(0) ||
            dist.rewards == address(0) ||
            dist.staking == address(0) ||
            dist.reserve == address(0) ||
            dist.team == address(0) ||
            dist.marketing == address(0)
        ) revert("WeWake: zero address in distribution");

        uint256 total = 1_575_137_505 * 10**decimals();
        
        // Distribution (Total 100%)
        // Presale: 30%
        _mint(dist.presale, total * 30 / 100);
        // Liquidity: 10%
        _mint(dist.liquidity, total * 10 / 100);
        // Ecosystem: 14%
        _mint(dist.ecosystem, total * 14 / 100);
        // Treasury: 10% + 6% (Unallocated) = 16%
        _mint(dist.treasury, total * 16 / 100);
        // User Rewards: 8%
        _mint(dist.rewards, total * 8 / 100);
        // Staking Emissions: 8%
        _mint(dist.staking, total * 8 / 100);
        // Strategic Reserve: 4%
        _mint(dist.reserve, total * 4 / 100);
        // Team: 4%
        _mint(dist.team, total * 4 / 100);
        // Marketing: 6%
        _mint(dist.marketing, total * 6 / 100);
    }

    /**
     * @notice Restricts access to only the contract owner.
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyAdmin() {
        _checkAdmin();
        _;
    }

    /**
     * @notice Checks if the caller is an admin (owner).
     * @dev Internal function used by onlyAdmin modifier. Reverts if caller is not authorized.
     */
    function _checkAdmin() internal view {
        require(msg.sender == owner(), "WeWake: not admin");
    }

    /**
     * @notice Returns details about the active burn process.
     * @dev Useful for UI to display burn schedule.
     * @return possibleFromTimestamp Timestamp when burn determines execution (0 if not active).
     * @return amount Amount of tokens locked for burning.
     */
    function burnInfo() external view returns (uint256 possibleFromTimestamp, uint256 amount) {
        if (_burnPossibleFromTimestamp != 0) {
            possibleFromTimestamp = _burnPossibleFromTimestamp;
            amount = _burnAmount;
        }
    }

    /**
     * @notice Pauses all token transfers.
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
        }
    }

    /**
     * @notice Recovers ERC20 tokens mistakenly sent to this contract.
     * @dev Uses SafeERC20 for secure transfer. Cannot rescue WAKE tokens.
     * @param token Address of the token contract to rescue.
     * @param to Address where tokens will be sent.
     * @param amount Amount of tokens to transfer.
     */
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

    // --- Overrides (Solidity overrides for inheritance conflict resolution) ---

    /**
     * @notice Hook that is called before any transfer of tokens.
     * @dev Checks for paused state and calls parent _update.
     * @param from Address sending tokens.
     * @param to Address receiving tokens.
     * @param amount Amount of tokens transferred.
     */
    function _update(address from, address to, uint256 amount)
        internal
        override(ERC20, ERC20Votes, ERC20Pausable)
    {
        if (paused()) revert("WeWake: token transfer while paused");
        super._update(from, to, amount);
    }
}
