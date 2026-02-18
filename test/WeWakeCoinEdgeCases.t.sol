// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test} from "forge-std/Test.sol";
import {WeWakeCoin} from "../src/WeWakeCoin.sol";

contract RejectEther {
    receive() external payable {
        revert("No ETH thanks");
    }
}

contract WeWakeCoinEdgeCasesTest is Test {
    WeWakeCoin public token;
    address public owner;
    address public team = address(0x2);
    address public eco = address(0x3);
    address public treasury = address(0x4);
    address public alice = address(0x5);

    function setUp() public {
        owner = address(this);
        // Deploy token with this contract as owner (msg.sender)
        token = new WeWakeCoin(owner, team, eco, treasury);
    }

    function testBurnTimelockEnforced() public {
        uint256 amount = 1000;
        vm.prank(owner);
        // Transfer tokens to contract for burn
        bool success = token.transfer(address(token), amount);
        assertTrue(success);
        
        vm.prank(owner);
        token.openBurn(amount);
        // Try to finish burn before timelock
        vm.prank(owner);
        vm.expectRevert(); // Reverts with BurnTimelockNotExpired
        token.finishBurn();
        
        // Fast-forward past timelock
        vm.warp(block.timestamp + token.BURN_TIMELOCK() + 1);
        
        vm.prank(owner);
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
        vm.expectRevert("WeWake: not admin");
        token.pause();
        token.pause();
        assertTrue(token.paused());
        token.unpause();
        assertFalse(token.paused());
    }

    function testRescueETH() public {
        vm.deal(address(token), 1 ether);
        uint256 before = alice.balance;
        token.rescueEth(payable(alice), 1 ether);
        assertEq(alice.balance, before + 1 ether);
    }

    function testOpenBurnReverts() public {
        // 1. Amount 0
        vm.expectRevert(WeWakeCoin.BurnAmountZero.selector);
        token.openBurn(0);

        // 2. Insufficient balance
        uint256 ts = token.totalSupply();
        vm.expectRevert(WeWakeCoin.InsufficientBalanceToBurn.selector);
        token.openBurn(ts * 2);

        uint256 validAmount = 1000;
        token.transfer(address(token), validAmount);
        
        // 3. Already active
        token.openBurn(validAmount);
        vm.expectRevert(WeWakeCoin.BurnProcessAlreadyActive.selector);
        token.openBurn(validAmount);
    }

    function testFinishBurnReverts() public {
        
        // 1. Burn process not initiated
        vm.expectRevert(WeWakeCoin.BurnProcessNotInitiated.selector);
        token.finishBurn();
        
        // Setup valid burn
        uint256 validAmount = 1000;
        // Need tokens on contract
        token.transfer(address(token), validAmount);

        token.openBurn(validAmount);

        // 2. Timelock not expired
        // No warp or insufficient warp
        vm.expectRevert(abi.encodeWithSelector(WeWakeCoin.BurnTimelockNotExpired.selector, block.timestamp, block.timestamp + token.BURN_TIMELOCK()));
        token.finishBurn();
    }

    function testRescueReverts() public {
        
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
    }

    function testRescueEthReverts() public {
        vm.startPrank(owner);
        
        // 1. Zero address
        vm.expectRevert(bytes("WeWake: zero address"));
        token.rescueEth(payable(address(0)), 1 ether);
        
        // 2. Amount 0
        vm.expectRevert(bytes("WeWake: amount must be greater than 0"));
        token.rescueEth(payable(alice), 0);
        
        vm.stopPrank();
    }

    function testRescueEthFailsOnRevert() public {
        vm.deal(address(token), 1 ether);
        RejectEther rejector = new RejectEther();
        
        vm.expectRevert(bytes("WeWake: failed to send ETH"));
        token.rescueEth(payable(address(rejector)), 1 ether);
    }

    function testNoncesUsage() public view {
        // Просто вызываем для покрытия
        token.nonces(address(this));
    }
}
