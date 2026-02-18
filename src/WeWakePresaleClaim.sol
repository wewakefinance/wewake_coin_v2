// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {WeWakeVesting} from "./WeWakeVesting.sol";

/**
 * @title WeWakePresaleClaim
 * @notice Distributes Presale tokens via Merkle Proof with integrated vesting.
 */
contract WeWakePresaleClaim is Ownable {
    using SafeERC20 for IERC20;

    IERC20 public token;
    bytes32 public merkleRoot;
    
    // Vesting configuration for Presale
    uint64 public immutable vestingStart;
    uint64 public immutable vestingDuration;
    uint64 public immutable vestingCliff;

    mapping(address => bool) public hasClaimed;
    mapping(address => address) public userVestingContract;

    event Claimed(address indexed user, uint256 totalAmount, uint256 unlocked, address vestingContract);
    event MerkleRootUpdated(bytes32 newRoot);

    error AlreadyClaimed();
    error InvalidProof();

    constructor(
        address initialOwner,
        address token_,
        bytes32 merkleRoot_,
        uint64 start_,
        uint64 duration_,
        uint64 cliff_
    ) Ownable(initialOwner) {
        token = IERC20(token_);
        merkleRoot = merkleRoot_;
        vestingStart = start_;
        vestingDuration = duration_;
        vestingCliff = cliff_;
    }

    function setToken(address _token) external onlyOwner {
        token = IERC20(_token);
    }

    function setMerkleRoot(bytes32 _merkleRoot) external onlyOwner {
        merkleRoot = _merkleRoot;
        emit MerkleRootUpdated(_merkleRoot);
    }

    function claim(uint256 totalAmount, bytes32[] calldata proof) external {
        if (hasClaimed[msg.sender]) revert AlreadyClaimed();

        // Verify Merkle Proof
        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(msg.sender, totalAmount))));
        if (!MerkleProof.verify(proof, merkleRoot, leaf)) revert InvalidProof();

        hasClaimed[msg.sender] = true;

        // 10% Unlocked
        uint256 initialUnlock = totalAmount * 10 / 100;
        uint256 vestingAmount = totalAmount - initialUnlock;

        // Transfer unlocked tokens
        token.safeTransfer(msg.sender, initialUnlock);

        // Create Vesting Contract for the rest (90%)
        // Vesting contract receives tokens.
        
        // Deploy individual vesting wallet
        WeWakeVesting vesting = new WeWakeVesting(
            msg.sender,
            vestingStart,
            vestingDuration,
            vestingCliff
        );
        userVestingContract[msg.sender] = address(vesting);

        // Fund vesting wallet
        token.safeTransfer(address(vesting), vestingAmount);

        emit Claimed(msg.sender, totalAmount, initialUnlock, address(vesting));
    }

    // Recover leftover tokens
    function recoverTokens(address to, uint256 amount) external onlyOwner {
        token.safeTransfer(to, amount);
    }
}
