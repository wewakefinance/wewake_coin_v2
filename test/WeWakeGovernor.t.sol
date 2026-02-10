// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {WeWakeCoin} from "../src/WeWakeCoin.sol";
import {WeWakeGovernor} from "../src/WeWakeGovernor.sol";
import {WeWakeTimelock} from "../src/WeWakeTimelock.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

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

    function testVoteAgainst() public {
        token.delegate(address(this));
        
        bytes memory callData = abi.encodeWithSignature("pause()");
        address[] memory targets = new address[](1);
        targets[0] = address(token);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = callData;
        string memory description = "Pause 2";
        
        uint256 proposalId = governor.propose(targets, values, calldatas, description);
        
        vm.roll(governor.proposalSnapshot(proposalId) + 1);
        
        // Vote Against (0)
        governor.castVote(proposalId, 0);
        
        vm.roll(governor.proposalDeadline(proposalId) + 1);
        
        // Should be defeated because quorum not reached (wait, if I vote against, does it count for quorum? Yes usually)
        // But support is 0. 
        // 4% quorum. If I hold 70% of tokens, my 0 vote makes quorum correct? 
        // Logic: if (forVotes > againstVotes) and (forVotes + abstainVotes >= quorum).
        // Wait, different implementations exist. Standard GovernorCountingSimple:
        // Returns true if `forVotes > againstVotes` AND `forVotes + againstVotes + abstainVotes >= quorum` (if counting simple)
        // Let's check state.
        assertTrue(governor.state(proposalId) == IGovernor.ProposalState.Defeated);
    }

    function testGovernorCoverage() public {
        // 1. View functions validation
        assertEq(governor.votingDelay(), 1);
        assertEq(governor.votingPeriod(), 45818);
        assertEq(governor.proposalThreshold(), 0);

        // 2. Interface support (ERC165)
        assertTrue(governor.supportsInterface(type(IGovernor).interfaceId));
        assertTrue(governor.supportsInterface(type(IERC165).interfaceId));

        // 3. Cancel Proposal Flow
        token.delegate(address(this));
        
        address[] memory targets = new address[](1);
        targets[0] = address(token);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = "";
        string memory description = "Cancel Me";
        
        // Create proposal
        uint256 proposalId = governor.propose(targets, values, calldatas, description);
        
        // Assert state is Pending (since we start at block - 1, and just mined, votingDelay=1)
        // Actually votingDelay=1 means start is next block. So now it is Pending.
        require(governor.state(proposalId) == IGovernor.ProposalState.Pending, "Should be Pending");
        
        // Cancel logic
        bytes32 descHash = keccak256(bytes(description));
        
        // GovernorTimelockControl allows proposer to cancel
        // vm.expectEmit(true, true, true, true);
        // emit IGovernor.ProposalCanceled(proposalId);
        governor.cancel(targets, values, calldatas, descHash);
        
        require(governor.state(proposalId) == IGovernor.ProposalState.Canceled, "Should be Canceled");
    }
}
