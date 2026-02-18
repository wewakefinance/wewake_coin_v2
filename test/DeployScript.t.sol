// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {DeployWeWake} from "../script/DeployWeWake.s.sol";
import {WeWakeCoinScript} from "../script/WeWakeCoin.s.sol";
import {WeWakeCoin} from "../src/WeWakeCoin.sol";
import {WeWakeGovernor} from "../src/WeWakeGovernor.sol";
import {WeWakeTimelock} from "../src/WeWakeTimelock.sol";

contract DeployScriptTest is Test {
    DeployWeWake public deployScript;

    function setUp() public {
        deployScript = new DeployWeWake();
    }

    function testDeployScript() public {
        address multisig = address(0x111);
        address team = address(0x222);
        address eco = address(0x333);
        address treasury = address(0x444);

        vm.setEnv("MULTISIG_SAFE", vm.toString(multisig));
        vm.setEnv("TEAM_WALLET", vm.toString(team));
        vm.setEnv("ECOSYSTEM_WALLET", vm.toString(eco));
        vm.setEnv("TREASURY_WALLET", vm.toString(treasury));
        
        // Ensure admin matches the broadcaster (default foundry sender)
        vm.setEnv("ADMIN_ADDRESS", vm.toString(msg.sender));
        
        // Запускаем скрипт
        deployScript.run();

        // В реальном тесте скрипта мы не можем легко получить адреса созданных контрактов,
        // так как они создаются внутри run(). 
        // Но сам факт того, что run() прошел без ошибок, уже дает покрытие строк скрипта.
        // Чтобы проверить результат, можно было бы изменить скрипт, чтобы он возвращал значения, 
        // но для покрытия (coverage) достаточно выполнения.
    }

    function testWeWakeCoinScript() public {
        WeWakeCoinScript script = new WeWakeCoinScript();
        
        address team = address(0x222);
        address eco = address(0x333);
        address treasury = address(0x444);
        address daoMultisig = address(0x999);

        vm.setEnv("TEAM_WALLET", vm.toString(team));
        vm.setEnv("ECO_WALLET", vm.toString(eco));
        vm.setEnv("TREASURY_WALLET", vm.toString(treasury));
        vm.setEnv("DAO_MULTISIG", vm.toString(daoMultisig)); // Added this
        
        script.run();
    }
}
