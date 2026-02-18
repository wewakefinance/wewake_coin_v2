// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Script, console, console2} from "forge-std/Script.sol";
import {WeWakeCoin} from "../src/WeWakeCoin.sol";
import {WeWakeGovernor} from "../src/WeWakeGovernor.sol";
import {WeWakeTimelock} from "../src/WeWakeTimelock.sol";
import {WeWakeVesting} from "../src/WeWakeVesting.sol";
import {WeWakePresaleClaim} from "../src/WeWakePresaleClaim.sol";

contract DeployWeWake is Script {
    // Vesting Addresses
    address liquidityVesting;
    address ecoVesting;
    address treasuryVesting;
    address rewardsVesting;
    address stakingVesting;
    address reserveVesting;
    address teamVesting;
    address marketingVesting;

    function run() external returns (
        WeWakeCoin token,
        WeWakeTimelock timelock,
        WeWakeGovernor governor,
        WeWakePresaleClaim presaleClaim
    ) {
        address admin = vm.envOr("ADMIN_ADDRESS", msg.sender);
        bytes32 merkleRoot = vm.envOr("MERKLE_ROOT", bytes32(0));

        vm.startBroadcast();

        // 1. Timelock
        timelock = new WeWakeTimelock(
            2 days,
            new address[](0),
            new address[](0),
            admin // Use resolved admin address. In test, set ADMIN_ADDRESS to Broadcaster (0x180...).
        );

        // 2. Vesting Wallets (Scoped to avoid stack too deep)
        uint64 start = uint64(block.timestamp);
        uint64 month = 30 days;
        
        {
            liquidityVesting = address(new WeWakeVesting(admin, start, 0, 0));
            ecoVesting = address(new WeWakeVesting(admin, start, 24 * month, 6 * month));
            treasuryVesting = address(new WeWakeVesting(admin, start, 36 * month, 12 * month));
            rewardsVesting = address(new WeWakeVesting(admin, start, 24 * month, 0));
        }
        {
            stakingVesting = address(new WeWakeVesting(admin, start, 36 * month, 0));
            reserveVesting = address(new WeWakeVesting(admin, start, 48 * month, 12 * month));
            teamVesting = address(new WeWakeVesting(admin, start, 48 * month, 12 * month));
            marketingVesting = address(new WeWakeVesting(admin, start, 12 * month, 0));
        }

        // 3. Presale Claim
        // Pass admin as initial owner
        presaleClaim = new WeWakePresaleClaim(
            admin,
            address(0), 
            merkleRoot,
            start,
            12 * month,
            3 * month
        );

        // 4. Token Deployment
        // Note: We use `msg.sender` as initial owner.
        // But run() caller (msg.sender) != Broadcaster (0x180...).
        // But broadcast tx comes from Broadcaster.
        // So we should set initial owner to Broadcaster (admin).
        
        token = new WeWakeCoin(admin, WeWakeCoin.InitialDistribution({
            presale: address(presaleClaim),
            liquidity: liquidityVesting,
            ecosystem: ecoVesting,
            treasury: treasuryVesting,
            rewards: rewardsVesting,
            staking: stakingVesting,
            reserve: reserveVesting,
            team: teamVesting,
            marketing: marketingVesting
        }));

        // 5. Connect Presale
        presaleClaim.setToken(address(token));

        // 6. Governor Deployment
        governor = new WeWakeGovernor(token, timelock);

        // 7. Setup Roles & Ownership
        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        timelock.grantRole(timelock.EXECUTOR_ROLE(), address(0)); 
        timelock.grantRole(timelock.CANCELLER_ROLE(), address(governor));

        timelock.grantRole(timelock.DEFAULT_ADMIN_ROLE(), address(timelock)); 
        
        // This fails if broadcaster (0x180...) != admin (0x180...). Matches in test.
        timelock.renounceRole(timelock.DEFAULT_ADMIN_ROLE(), admin);

        token.transferOwnership(address(timelock));
        presaleClaim.transferOwnership(address(timelock));
        
        console2.log("Token:", address(token));
        console2.log("Timelock:", address(timelock));
        console2.log("Governor:", address(governor));
        console2.log("PresaleClaim:", address(presaleClaim));

        vm.stopBroadcast();
    }
}
