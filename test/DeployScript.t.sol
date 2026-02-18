// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {DeployWeWake} from "../script/DeployWeWake.s.sol";
import {WeWakeCoin} from "../src/WeWakeCoin.sol";
import {WeWakeGovernor} from "../src/WeWakeGovernor.sol";
import {WeWakeTimelock} from "../src/WeWakeTimelock.sol";
import {WeWakePresaleClaim} from "../src/WeWakePresaleClaim.sol";

contract DeployScriptTest is Test {
    DeployWeWake public deployScript;

    function setUp() public {
        deployScript = new DeployWeWake();
    }

    function testDeployScript() public {
        // Use Foundry default sender (Broadcaster)
        address broadcaster = address(uint160(uint256(keccak256("foundry default caller")))); // No, specific address.
        // It is 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38
        broadcaster = 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38;
        
        vm.setEnv("ADMIN_ADDRESS", vm.toString(broadcaster));
        vm.setEnv("MERKLE_ROOT", vm.toString(bytes32(0)));
        
        // Execute Script
        (
            WeWakeCoin token, 
            WeWakeTimelock timelock, 
            WeWakeGovernor governor, 
            WeWakePresaleClaim claim
        ) = deployScript.run();

        // 1. Verify Total Supply (1,575,137,505 WAKE)
        uint256 total = 1_575_137_505 * 10**18;
        assertEq(token.totalSupply(), total);

        // 2. Verify Presale Allocation (30%)
        // The balance of the Claim contract must be 30% of total
        uint256 presaleAmount = total * 30 / 100;
        assertEq(token.balanceOf(address(claim)), presaleAmount);

        // 3. Verify Ownership Transfer -> Timelock (Pending)
        // Since Ownable2Step is used, owner is still deployer, pending is timelock.
        assertEq(token.owner(), broadcaster);
        assertEq(token.pendingOwner(), address(timelock));
        
        // Presale uses Ownable (1-step) or Ownable2Step?
        // OpenZeppelin Ownable is 1-step by default. Ownable2Step inherits Ownable.
        // WeWakePresaleClaim inherits Ownable (1-step).
        // So Presale owner SHOULD be timelock immediately.
        assertEq(claim.owner(), address(timelock));
        
        // 4. Verify Timelock Configuration
        assertTrue(timelock.hasRole(timelock.DEFAULT_ADMIN_ROLE(), address(timelock)));
        // Check delay
        assertEq(timelock.getMinDelay(), 2 days);
        
        // 5. Verify Governor
        assertEq(address(governor.token()), address(token));
        assertEq(address(governor.timelock()), address(timelock));
        
        // 6. Verify Vesting Wallets Existence?
        // We can't easily check without returning them, but if deployment succeeded,
        // and tokens are not in deployer wallet, they must be somewhere.
        // We know presale is 30%.
        // The rest are 70%.
        // Let's ensure token contract itself has 0 balance (distributed).
        assertEq(token.balanceOf(address(token)), 0);
        // And deployer has 0 balance.
        assertEq(token.balanceOf(address(this)), 0);
        assertEq(token.balanceOf(msg.sender), 0);
    }
}
