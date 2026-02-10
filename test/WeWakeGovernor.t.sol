// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {WeWakeCoin} from "../src/WeWakeCoin.sol";
import {WeWakeGovernor} from "../src/WeWakeGovernor.sol";
import {WeWakeTimelock} from "../src/WeWakeTimelock.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";

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
        // Deploy token with this contract as owner (msg.sender)
        token = new WeWakeCoin(address(this), team, eco, treasury);
        address[] memory proposers = new address[](1);
        proposers[0] = address(this);
        address[] memory executors = new address[](1);
        executors[0] = address(0);
        timelock = new WeWakeTimelock(2 days, proposers, executors, address(this));
        governor = new WeWakeGovernor(token, timelock);
        
        // Grant PROPOSER_ROLE to governor so it can queue operations
        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        timelock.grantRole(timelock.CANCELLER_ROLE(), address(governor));
        timelock.grantRole(timelock.EXECUTOR_ROLE(), address(governor));

        // Grant multisig role to timelock so it can execute admin functions (like pause)
        token.setMultisig(address(timelock));
    }

    function testGovernorQuorum() public {
        // ERC5805 requires blockNum < current block
        vm.roll(block.number + 1);
        uint256 blockNum = block.number - 1;
        uint256 quorumVotes = governor.quorum(blockNum);
        assertEq(quorumVotes, token.totalSupply() * 4 / 100); // 4% quorum
    }

    function testProposalLifecycle() public {
        // Delegate votes to address(this)
        token.delegate(address(this));
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
        uint256 proposalId = governor.propose(targets, values, calldatas, description);
        // Получить voteStart и voteEnd
        uint256 voteStart = governor.proposalSnapshot(proposalId);
        uint256 voteEnd = governor.proposalDeadline(proposalId);
        // Перемотать к началу голосования
        vm.roll(voteStart + 1);
        // Проверить, что голосование открыто
        require(governor.state(proposalId) == IGovernor.ProposalState.Active, "Voting not active");
        // Vote
        governor.castVote(proposalId, 1); // 1 = For
        // Перемотать к концу голосования
        vm.roll(voteEnd + 1);
        // Queue
        bytes32 descHash = keccak256(bytes(description));
        governor.queue(targets, values, calldatas, descHash);
        // Fast-forward timelock
        vm.warp(block.timestamp + 2 days + 1);
        // Execute
        governor.execute(targets, values, calldatas, descHash);
        // Check paused
        assertTrue(token.paused());
    }
}
