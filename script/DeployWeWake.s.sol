// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {WeWakeCoin} from "../src/WeWakeCoin.sol";
import {WeWakeGovernor} from "../src/WeWakeGovernor.sol";
import {WeWakeTimelock} from "../src/WeWakeTimelock.sol";

contract DeployWeWake is Script {
    function run() external returns (WeWakeCoin, WeWakeTimelock, WeWakeGovernor) {
        // --- Настройки ---
        address multisigSafe = vm.envAddress("MULTISIG_SAFE");
        address team = vm.envAddress("TEAM_WALLET");
        address ecosystem = vm.envAddress("ECOSYSTEM_WALLET");
        address treasury = vm.envAddress("TREASURY_WALLET");

        vm.startBroadcast();
        // In test context, msg.sender will be the broadcaster after startBroadcast()
        address admin = vm.envOr("ADMIN_ADDRESS", msg.sender);
        
        // Debug
        // console2.log("Admin for timelock:", admin);
        // console2.log("Msg.sender:", msg.sender);

        // 1. Деплой токена (владелец временно deployer)
        WeWakeCoin token = new WeWakeCoin(admin, team, ecosystem, treasury);

        // 2. Деплой Timelock (админ временно deployer)
        address[] memory proposers = new address[](0);
        address[] memory executors = new address[](0);
        WeWakeTimelock timelock = new WeWakeTimelock(2 days, proposers, executors, admin);

        // 3. Деплой Governor
        WeWakeGovernor governor = new WeWakeGovernor(token, timelock);

        // --- Настройка ролей ---
        // Governor должен быть Proposer
        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        // Governor должен быть Executor (если GovernorTimelockControl требует)
        // Но обычно executor - это 0x0 или специфический адрес.
        // GovernorTimelockControl: governor calls timelock via execute.
        // The governor needs to be proposer.
        
        // TimelockExecutorRole is usually open (address(0)) so anyone can execute ready proposals.
        timelock.grantRole(timelock.EXECUTOR_ROLE(), address(0));
        timelock.grantRole(timelock.CANCELLER_ROLE(), address(governor));

        // --- Передача прав Safe ---
        // Токен: передаем права Safe
        token.transferOwnership(multisigSafe);
        
        // Timelock: передаем права Safe (revoke deployer, grant Safe)
        timelock.grantRole(timelock.DEFAULT_ADMIN_ROLE(), multisigSafe);
        timelock.revokeRole(timelock.DEFAULT_ADMIN_ROLE(), admin);

        vm.stopBroadcast();

        return (token, timelock, governor);
    }
}
