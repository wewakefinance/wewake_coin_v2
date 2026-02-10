// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title WeWakeCoin
 * @author WeWake Finance Team
 * @notice Official WeWake (WAKE) token implementation with governance capabilities
 * @dev ERC20 token with extensions: Votes, Permit, Pausable, Burnable
 * 
 * Security Features:
 * - Fixed supply (no minting after deployment)
 * - Ownable2Step for secure ownership transfer
 * - Pausable for emergency stops
 * - ERC20Permit for gasless approvals
 * - ERC20Votes for DAO governance
 * - Token recovery mechanism for mistaken transfers
 * 
 * Certik Audit Compliance:
 * - Full NatSpec documentation
 * - OpenZeppelin v5.0+ battle-tested contracts
 * - No centralized mint functions
 * - Comprehensive event logging
 * - Role-based access control
 */
contract WeWakeCoin is ERC20, ERC20Burnable, ERC20Pausable, ERC20Permit, ERC20Votes, Ownable2Step {
    using SafeERC20 for IERC20;

    /// @notice Total supply of WAKE tokens (1 billion with 18 decimals)
    uint256 private constant TOTAL_SUPPLY = 1_000_000_000 * 10**18;

    /// @notice Team allocation (15% - vested)
    uint256 private constant TEAM_ALLOCATION = 150_000_000 * 10**18;

    /// @notice Ecosystem & Community allocation (30%)
    uint256 private constant ECOSYSTEM_ALLOCATION = 300_000_000 * 10**18;

    /// @notice Treasury & Operations allocation (20%)
    uint256 private constant TREASURY_ALLOCATION = 200_000_000 * 10**18;

    /// @notice Public Sale allocation (15%)
    uint256 private constant PUBLIC_SALE_ALLOCATION = 150_000_000 * 10**18;

    /// @notice Private Sale allocation (10%)
    uint256 private constant PRIVATE_SALE_ALLOCATION = 100_000_000 * 10**18;

    /// @notice Liquidity Pool allocation (10%)
    uint256 private constant LIQUIDITY_ALLOCATION = 100_000_000 * 10**18;

    /**
     * @notice Emitted when tokens are burned with additional context
     * @param burner Address that burned tokens
     * @param amount Amount of tokens burned
     * @param totalSupplyAfterBurn Remaining total supply after burn
     */
    event TokensBurned(address indexed burner, uint256 amount, uint256 totalSupplyAfterBurn);

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

    /**
     * @notice Emitted when contract is unpaused
     * @param account Address that triggered the unpause
     */
    event ContractUnpaused(address indexed account);

    /**
     * @notice Constructor initializes the WeWake token with fixed supply distribution
     * @param teamWallet Address receiving team allocation
     * @param ecosystemWallet Address receiving ecosystem allocation
     * @param treasuryWallet Address receiving treasury allocation
     * @param publicSaleWallet Address receiving public sale allocation
     * @param privateSaleWallet Address receiving private sale allocation
     * @param liquidityWallet Address receiving liquidity allocation
     * @param initialOwner Address that will become the contract owner (should be multisig)
     * 
     * @dev All allocations are minted once during deployment. No future minting possible.
     * @dev Initial owner should be a Gnosis Safe multisig for security
     */
    constructor(
        address teamWallet,
        address ecosystemWallet,
        address treasuryWallet,
        address publicSaleWallet,
        address privateSaleWallet,
        address liquidityWallet,
        address initialOwner
    ) 
        ERC20("WeWake", "WAKE")
        ERC20Permit("WeWake")
        Ownable(initialOwner)
    {
        require(teamWallet != address(0), "WeWake: team wallet is zero address");
        require(ecosystemWallet != address(0), "WeWake: ecosystem wallet is zero address");
        require(treasuryWallet != address(0), "WeWake: treasury wallet is zero address");
        require(publicSaleWallet != address(0), "WeWake: public sale wallet is zero address");
        require(privateSaleWallet != address(0), "WeWake: private sale wallet is zero address");
        require(liquidityWallet != address(0), "WeWake: liquidity wallet is zero address");
        require(initialOwner != address(0), "WeWake: initial owner is zero address");

        // Mint all tokens according to tokenomics
        _mint(teamWallet, TEAM_ALLOCATION);
        _mint(ecosystemWallet, ECOSYSTEM_ALLOCATION);
        _mint(treasuryWallet, TREASURY_ALLOCATION);
        _mint(publicSaleWallet, PUBLIC_SALE_ALLOCATION);
        _mint(privateSaleWallet, PRIVATE_SALE_ALLOCATION);
        _mint(liquidityWallet, LIQUIDITY_ALLOCATION);

        // Verify total supply matches expected amount
        assert(totalSupply() == TOTAL_SUPPLY);
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
     * @notice Burns tokens from specified account with enhanced logging
     * @param account Account to burn tokens from
     * @param amount Amount of tokens to burn
     * @dev Overrides ERC20Burnable.burnFrom to add custom event
     * Requirements:
     * - Caller must have allowance for at least `amount` tokens from `account`
     * - `account` must have at least `amount` tokens
     */
    function burnFrom(address account, uint256 amount) public override {
        super.burnFrom(account, amount);
        emit TokensBurned(account, amount, totalSupply());
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

    /**
     * @notice Returns the current nonce for an address (used in permit)
     * @param owner Address to query nonce for
     * @return Current nonce value
     */
    function nonces(address owner) public view override(ERC20Permit, Nonces) returns (uint256) {
        return super.nonces(owner);
    }

    /**
     * @dev Internal function to update token balances
     * @param from Source address
     * @param to Destination address
     * @param value Amount of tokens
     * 
     * Combines checks from ERC20Pausable and ERC20Votes
     */
    function _update(address from, address to, uint256 value)
        internal
        override(ERC20, ERC20Pausable, ERC20Votes)
    {
        super._update(from, to, value);
    }

    /**
     * @notice Returns the clock for governance (block number based)
     * @return Current block number
     * @dev Used by ERC20Votes for snapshot tracking
     */
    function clock() public view override returns (uint48) {
        return uint48(block.number);
    }

    /**
     * @notice Returns the clock mode for governance
     * @return Machine-readable description of the clock
     * @dev Used by ERC20Votes for snapshot tracking
     */
    // solhint-disable-next-line func-name-mixedcase
    function CLOCK_MODE() public pure override returns (string memory) {
        return "mode=blocknumber&from=default";
    }
}