// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {WeWakeCoin} from "../src/WeWakeCoin.sol";
import {WeWakeGovernor} from "../src/WeWakeGovernor.sol";
import {WeWakeTimelock} from "../src/WeWakeTimelock.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract WeWakeGovernanceTest is Test {
    WeWakeCoin public token;
    WeWakeTimelock public timelock;
    WeWakeGovernor public governor;
    address public multisig = address(0xA);
    address public team = address(0x2);
    address public eco = address(0x3);
    address public treasury = address(0x4);
    address public alice = address(0x5);
    address public bob = address(0x6);

    function setUp() public {
        token = new WeWakeCoin(multisig, team, eco, treasury);
        address[] memory proposers = new address[](1);
        proposers[0] = multisig;
        address[] memory executors = new address[](1);
        executors[0] = address(0);
        timelock = new WeWakeTimelock(2 days, proposers, executors, multisig);
        governor = new WeWakeGovernor(token, timelock);
    }

    function testGovernorQuorum() public {
        uint256 blockNum = block.number;
        uint256 quorumVotes = governor.quorum(blockNum);
        assertEq(quorumVotes, token.totalSupply() * 4 / 100); // 4% quorum
    }

    function testProposalLifecycle() public {
        // Delegate votes to multisig
        vm.prank(multisig);
        token.delegate(multisig);
        // Prepare proposal: call pause() on token
        bytes memory callData = abi.encodeWithSignature("pause()");
        address[] memory targets = new address[](1);
        targets[0] = address(token);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = callData;
        string memory description = "Pause token via governance";
        // Propose
        vm.prank(multisig);
        uint256 proposalId = governor.propose(targets, values, calldatas, description);
        // Fast-forward to voting start
        vm.roll(block.number + governor.votingDelay());
        // Vote
        vm.prank(multisig);
        governor.castVote(proposalId, 1); // 1 = For
        // Fast-forward to voting end
        vm.roll(block.number + governor.votingPeriod());
        // Queue
        bytes32 descHash = keccak256(bytes(description));
        vm.prank(multisig);
        governor.queue(targets, values, calldatas, descHash);
        // Fast-forward timelock
        vm.warp(block.timestamp + 2 days + 1);
        // Execute
        vm.prank(multisig);
        governor.execute(targets, values, calldatas, descHash);
        // Check paused
        assertTrue(token.paused());
    }
}
