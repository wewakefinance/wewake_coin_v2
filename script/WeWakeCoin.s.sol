// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Script, console} from "lib/forge-std/src/Script.sol";
import {WeWakeCoin} from "../src/WeWakeCoin.sol";

contract WeWakeCoinScript is Script {
    function run() external {
        address daoMultisig = vm.envAddress("DAO_MULTISIG");

        // Start broadcasting transactions
        vm.startBroadcast();

        // Deploy the contract
        // TODO: Укажите реальные адреса team, eco, treasury
        address team = address(0x2);
        address eco = address(0x3);
        address treasury = address(0x4);
        WeWakeCoin token = new WeWakeCoin(daoMultisig, team, eco, treasury);

        // Stop broadcasting transactions
        vm.stopBroadcast();

        // Log the deployed address
        console.log("WeWakeCoin deployed at:", address(token));
    }
}
