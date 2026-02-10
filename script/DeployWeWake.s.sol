// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {WeWakeCoin} from "../src/WeWakeCoin.sol";
import {WeWakeGovernor} from "../src/WeWakeGovernor.sol";
import {WeWakeTimelock} from "../src/WeWakeTimelock.sol";

contract DeployWeWake is Script {
    function run() external {
        // --- Настройки ---
        address multisig = vm.envAddress("MULTISIG_SAFE");
        address team = vm.envAddress("TEAM_WALLET");
        address ecosystem = vm.envAddress("ECOSYSTEM_WALLET");
        address treasury = vm.envAddress("TREASURY_WALLET");

        // --- Деплой токена ---
        vm.startBroadcast();
        WeWakeCoin token = new WeWakeCoin(multisig, team, ecosystem, treasury);

        // --- Деплой TimelockController ---
        address[] memory proposers = new address[](1);
        proposers[0] = multisig;
        address[] memory executors = new address[](1);
        executors[0] = address(0); // open executor (anyone)
        address admin = multisig;
        WeWakeTimelock timelock = new WeWakeTimelock(2 days, proposers, executors, admin);

        // --- Деплой Governor ---
        WeWakeGovernor governor = new WeWakeGovernor(token, timelock);

        // --- Вывод адресов ---
        console2.log("WeWakeCoin:", address(token));
        console2.log("WeWakeTimelock:", address(timelock));
        console2.log("WeWakeGovernor:", address(governor));
        vm.stopBroadcast();
    }
}
