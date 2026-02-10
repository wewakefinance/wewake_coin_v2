// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {WeWakeCoin} from "../src/WeWakeCoin.sol";

contract WeWakeCoinEdgeCasesTest is Test {
    WeWakeCoin public token;
    address public owner = address(0x1);
    address public team = address(0x2);
    address public eco = address(0x3);
    address public treasury = address(0x4);
    address public multisig = address(0xA);
    address public alice = address(0x5);

    function setUp() public {
        token = new WeWakeCoin(owner, team, eco, treasury);
        token.setMultisig(multisig);
    }

    function testBurnTimelockEnforced() public {
        uint256 amount = 1000;
        vm.prank(owner);
        token.openBurn(amount);
        // Try to finish burn before timelock
        vm.prank(owner);
        vm.expectRevert();
        token.finishBurn();
        // Fast-forward past timelock
        vm.warp(block.timestamp + token.BURN_TIMELOCK() + 1);
        vm.prank(multisig);
        token.finishBurn();
        // Burn info should be reset
        (uint256 ts, uint256 amt) = token.burnInfo();
        assertEq(ts, 0);
        assertEq(amt, 0);
    }

    function testCancelBurnReturnsTokens() public {
        uint256 amount = 500;
        vm.prank(owner);
        token.openBurn(amount);
        // Cancel burn
        vm.prank(owner);
        token.cancelBurn();
        // Burn info should be reset
        (uint256 ts, uint256 amt) = token.burnInfo();
        assertEq(ts, 0);
        assertEq(amt, 0);
        // Owner balance restored
        assertEq(token.balanceOf(owner), (1_000_000_000 * 10**token.decimals()) * 10 / 100);
    }

    function testOnlyAdminCanPause() public {
        vm.prank(alice);
        vm.expectRevert();
        token.pause();
        vm.prank(multisig);
        token.pause();
        assertTrue(token.paused());
    }

    function testRescueETH() public {
        vm.deal(address(token), 1 ether);
        uint256 before = alice.balance;
        vm.prank(multisig);
        token.rescueETH(payable(alice), 1 ether);
        assertEq(alice.balance, before + 1 ether);
    }
}
