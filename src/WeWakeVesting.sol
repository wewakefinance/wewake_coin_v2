// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {VestingWallet} from "@openzeppelin/contracts/finance/VestingWallet.sol";
import {VestingWalletCliff} from "@openzeppelin/contracts/finance/VestingWalletCliff.sol";

/**
 * @title WeWakeVesting
 * @notice Vesting wallet for WeWakeCoin token distribution with Cliff support.
 */
contract WeWakeVesting is VestingWalletCliff {
    /**
     * @dev Set the beneficiary, start timestamp, total duration (including cliff) and cliff duration.
     * @param beneficiary_ The address of the beneficiary.
     * @param startTimestamp_ The timestamp when the vesting schedule begins.
     * @param durationSeconds_ The duration of the vesting period.
     * @param cliffSeconds_ The duration of the cliff period in seconds.
     */
    constructor(
        address beneficiary_,
        uint64 startTimestamp_,
        uint64 durationSeconds_,
        uint64 cliffSeconds_
    ) VestingWallet(beneficiary_, startTimestamp_, durationSeconds_) VestingWalletCliff(cliffSeconds_) {}
}
