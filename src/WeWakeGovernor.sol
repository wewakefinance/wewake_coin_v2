// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Governor} from "@openzeppelin/contracts/governance/Governor.sol";
import {GovernorSettings} from "@openzeppelin/contracts/governance/extensions/GovernorSettings.sol";
import {GovernorCountingSimple} from "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";
import {GovernorVotes} from "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
import {GovernorVotesQuorumFraction} from "@openzeppelin/contracts/governance/extensions/GovernorVotesQuorumFraction.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";
import {GovernorTimelockControl} from "@openzeppelin/contracts/governance/extensions/GovernorTimelockControl.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

/**
 * @title WeWakeGovernor
 * @dev Governor implementation wired to an `IVotes` token and a `TimelockController`.
 */
contract WeWakeGovernor is
    Governor,
    GovernorSettings,
    GovernorCountingSimple,
    GovernorVotes,
    GovernorVotesQuorumFraction,
    GovernorTimelockControl
{
    /**
     * @notice Initializes the Governor contract with specific voting parameters.
     * @dev Sets up the Governor with the following settings:
     * - Token: The voting token (WeWakeCoin).
     * - Timelock: The controller that executes approved proposals.
     * - Voting Delay: 1 block (allows users a brief moment to prepare, but voting starts almost immediately).
     * - Voting Period: 45818 blocks.
     * - Proposal Threshold: 0 tokens.
     * - Quorum: 4%.
     *
     * @param token The address of the WeWakeCoin token implementing IVotes.
     * @param timelock The address of the TimelockController contract.
     */
    constructor(IVotes token, TimelockController timelock)
        Governor("WeWakeGovernor")
        GovernorSettings(1, 45818, 0)
        GovernorVotes(token)
        GovernorVotesQuorumFraction(4)
        GovernorTimelockControl(timelock)
    {}

    /**
     * @notice Delay between the proposal is created and the vote starts.
     * @dev Overrides GovernorSettings and Governor.
     * @return The delay in number of blocks (1 block).
     */
    function votingDelay() public view override(Governor, GovernorSettings) returns (uint256) {
        return super.votingDelay();
    }

    /**
     * @notice The duration of voting on a proposal.
     * @dev Overrides GovernorSettings and Governor.
     * @return The duration in number of blocks (45818 blocks, approx 1 week).
     */
    function votingPeriod() public view override(Governor, GovernorSettings) returns (uint256) {
        return super.votingPeriod();
    }

    /**
     * @notice Minimum number of votes required for a proposal to be successful.
     * @dev Overrides GovernorVotesQuorumFraction and Governor.
     * @param blockNumber The block number to check the quorum for.
     * @return The number of votes required.
     */
    function quorum(uint256 blockNumber) public view override(Governor, GovernorVotesQuorumFraction) returns (uint256) {
        return super.quorum(blockNumber);
    }

    /**
     * @notice The number of votes required in order for a voter to become a proposer.
     * @dev Overrides GovernorSettings and Governor.
     * @return The number of votes required (0 tokens).
     */
    function proposalThreshold() public view override(Governor, GovernorSettings) returns (uint256) {
        return super.proposalThreshold();
    }

    /**
     * @notice Current state of a proposal.
     * @dev Overrides GovernorTimelockControl and Governor.
     * @param proposalId The id of the proposal.
     * @return The current state (Pending, Active, Canceled, Defeated, Succeeded, Queued, Expired, Executed).
     */
    function state(uint256 proposalId) public view override(Governor, GovernorTimelockControl) returns (ProposalState) {
        return super.state(proposalId);
    }

    /**
     * @notice Checks if a proposal needs to be queued in the Timelock.
     * @dev Overrides GovernorTimelockControl and Governor.
     * @param proposalId The id of the proposal.
     * @return True if the proposal needs to be queued.
     */
    function proposalNeedsQueuing(uint256 proposalId) public view override(Governor, GovernorTimelockControl) returns (bool) {
        return super.proposalNeedsQueuing(proposalId);
    }

    /**
     * @notice Supports Interface check (ERC165).
     * @dev Overrides Governor.
     * @param interfaceId The interface identifier.
     * @return True if the interface is supported.
     */
    function supportsInterface(bytes4 interfaceId) public view override(Governor) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    /**
     * @notice Address of the executor (the Timelock).
     * @dev Overrides GovernorTimelockControl and Governor.
     * @return The address of the executor.
     */
    function _executor() internal view override(Governor, GovernorTimelockControl) returns (address) {
        return super._executor();
    }

    // --- Required overrides for GovernorTimelockControl ---

    /**
     * @notice Queues a proposal in the Timelock.
     * @dev Internal function to queue operations.
     * @param proposalId The id of the proposal.
     * @param targets The addresses of the contracts to call.
     * @param values The amounts of ETH to send.
     * @param calldatas The calldata for the calls.
     * @param descriptionHash The hash of the proposal description.
     * @return The proposal id.
     */
    function _queueOperations(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) returns (uint48) {
        return super._queueOperations(proposalId, targets, values, calldatas, descriptionHash);
    }

    /**
     * @notice Executes a proposal via the Timelock.
     * @dev Internal function to execute operations.
     * @param proposalId The id of the proposal.
     * @param targets The addresses of the contracts to call.
     * @param values The amounts of ETH to send.
     * @param calldatas The calldata for the calls.
     * @param descriptionHash The hash of the proposal description.
     */
    function _executeOperations(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) {
        super._executeOperations(proposalId, targets, values, calldatas, descriptionHash);
    }

    /**
     * @notice Cancels a proposal.
     * @dev Internal function to cancel operations.
     * @param targets The addresses of the contracts to call.
     * @param values The amounts of ETH to send.
     * @param calldatas The calldata for the calls.
     * @param descriptionHash The hash of the proposal description.
     * @return The proposal id.
     */
    function _cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) returns (uint256) {
        return super._cancel(targets, values, calldatas, descriptionHash);
    }
}
