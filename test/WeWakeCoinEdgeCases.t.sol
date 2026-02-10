// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {WeWakeCoin} from "../src/WeWakeCoin.sol";

contract RejectEther {
    receive() external payable {
        revert("No ETH thanks");
    }
}

contract WeWakeCoinEdgeCasesTest is Test {
    WeWakeCoin public token;
    address public owner = address(0x1);
    address public team = address(0x2);
    address public eco = address(0x3);
    address public treasury = address(0x4);
    address public multisig = address(0xA);
    address public alice = address(0x5);

    function setUp() public {
        // Deploy token with this contract as owner (msg.sender)
        token = new WeWakeCoin(address(this), team, eco, treasury);
        token.setMultisig(multisig);
    }

    function testBurnTimelockEnforced() public {
        uint256 amount = 1000;
        // Перевести токены на контракт для burn
        bool success = token.transfer(address(token), amount);
        assertTrue(success);
        token.openBurn(amount);
        // Try to finish burn before timelock
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
        uint256 balanceBefore = token.balanceOf(address(this));
        bool success = token.transfer(address(token), amount);
        assertTrue(success);
        token.openBurn(amount);
        // Cancel burn
        token.cancelBurn();
        // Burn info should be reset
        (uint256 ts, uint256 amt) = token.burnInfo();
        assertEq(ts, 0);
        assertEq(amt, 0);
        // Owner balance restored
        assertEq(token.balanceOf(address(this)), balanceBefore);
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
        token.rescueEth(payable(alice), 1 ether);
        assertEq(alice.balance, before + 1 ether);
    }

    function testOpenBurnReverts() public {
        vm.startPrank(multisig);
        
        // 1. Amount 0
        vm.expectRevert(WeWakeCoin.BurnAmountZero.selector);
        token.openBurn(0);

        // 2. Insufficient balance
        uint256 ts = token.totalSupply();
        vm.expectRevert(WeWakeCoin.InsufficientBalanceToBurn.selector);
        token.openBurn(ts); 

        uint256 validAmount = 1000;
        vm.stopPrank();
        
        token.transfer(address(token), validAmount);
        
        vm.startPrank(multisig);
        
        // 3. Already active
        token.openBurn(validAmount);
        vm.expectRevert(WeWakeCoin.BurnProcessAlreadyActive.selector);
        token.openBurn(validAmount);
        
        vm.stopPrank();
    }

    function testRescueReverts() public {
        vm.startPrank(multisig);
        
        // 1. Cannot rescue WAKE
        vm.expectRevert(bytes("WeWake: cannot rescue WAKE tokens"));
        token.rescueERC20(address(token), alice, 100);
        
        // 2. Zero address
        address mockToken = address(0x123); 
        vm.expectRevert(bytes("WeWake: recipient is zero address"));
        token.rescueERC20(mockToken, address(0), 100);
        
        // 3. Amount 0
        vm.expectRevert(bytes("WeWake: amount must be greater than 0"));
        token.rescueERC20(mockToken, alice, 0);
        
        vm.stopPrank();
    }

    function testRescueEthReverts() public {
        vm.startPrank(multisig);
        
        // 1. Zero address
        vm.expectRevert(bytes("WeWake: zero address"));
        token.rescueEth(payable(address(0)), 1 ether);
        
        // 2. Amount 0
        vm.expectRevert(bytes("WeWake: amount must be greater than 0"));
        token.rescueEth(payable(alice), 0);
        
        vm.stopPrank();
    }

    function testSetMultisigReverts() public {
        // Test zero address
        vm.expectRevert(bytes("WeWake: zero address"));
        token.setMultisig(address(0));
    }

    function testRescueEthFailsOnRevert() public {
        vm.deal(address(token), 1 ether);
        RejectEther rejector = new RejectEther();
        
        vm.prank(multisig);
        vm.expectRevert(bytes("WeWake: failed to send ETH"));
        token.rescueEth(payable(address(rejector)), 1 ether);
    }

    function testNoncesUsage() public view {
        // Просто вызываем для покрытия
        token.nonces(address(this));
    }
}
