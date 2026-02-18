// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

/**
 * @title WeWakeTimelock
 * @dev Minimal TimelockController wrapper for WeWake governance.
 */
contract WeWakeTimelock is TimelockController {
    /**
     * @notice Initializes the TimelockController with specific roles.
     * @dev The TimelockController controls the execution of proposals after a delay.
     * @param minDelay The minimum time (in seconds) that must pass between queuing and execution.
     * @param proposers List of addresses that can propose operations (usually the Governor).
     * @param executors List of addresses that can execute operations (usually any address or specific keepers).
     * @param admin The address that can grant and revoke roles (usually the deployer or a multisig).
     */
    constructor(
        uint256 minDelay,
        address[] memory proposers,
        address[] memory executors,
        address admin
    ) TimelockController(minDelay, proposers, executors, admin) {}
}
