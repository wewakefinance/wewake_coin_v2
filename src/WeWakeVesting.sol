// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {VestingWallet} from "@openzeppelin/contracts/finance/VestingWallet.sol";

/**
 * @title WeWakeVesting
 * @notice Vesting wallet for WeWakeCoin token distribution.
 * @dev This contract handles the vesting schedule for team, ecosystem, and treasury allocations.
 * It is based on OpenZeppelin's VestingWallet.
 */
contract WeWakeVesting is VestingWallet {
    constructor(address beneficiary, uint64 startTimestamp, uint64 durationSeconds)
        VestingWallet(beneficiary, startTimestamp, durationSeconds)
    {}
}
