// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {WeWakeCoin} from "../src/WeWakeCoin.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("Mock", "MCK") {}
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract WeWakeCoinTest is Test {
    WeWakeCoin public token;
    address public owner = address(0x1);
    address public team = address(0x2);
    address public eco = address(0x3);
    address public treasury = address(0x4);
    address public alice = address(0x5);
    address public bob = address(0x6);

    function setUp() public {
        vm.prank(owner);
        token = new WeWakeCoin(owner, team, eco, treasury);
    }

    function testTwoStepOwnership() public {
        address newOwner = address(0x9);
        vm.prank(owner);
        token.transferOwnership(newOwner);
        vm.prank(newOwner);
        token.acceptOwnership();
        assertEq(token.owner(), newOwner);
    }

    function testPauseAndTransferBlocked() public {
        vm.prank(owner);
        token.pause();

        vm.prank(team);
        vm.expectRevert(bytes("WeWake: token transfer while paused"));
        token.transfer(alice, 1);

        vm.prank(owner);
        token.unpause();

        uint256 teamBal = token.balanceOf(team);
        vm.prank(team);
        token.transfer(alice, 1);
        assertEq(token.balanceOf(alice), 1);
        assertEq(token.balanceOf(team), teamBal - 1);
    }

    function testDelegateVotes() public {
        address delegatee = bob;
        vm.prank(owner);
        token.delegate(delegatee);
        uint256 votes = token.getVotes(delegatee);
        assertEq(votes, token.balanceOf(owner));
    }

    function testRescueERC20() public {
        MockERC20 m = new MockERC20();
        m.mint(address(token), 1000);
        assertEq(m.balanceOf(address(token)), 1000);

        vm.prank(owner);
        token.rescueERC20(IERC20(address(m)), alice, 1000);

        assertEq(m.balanceOf(alice), 1000);
        assertEq(m.balanceOf(address(token)), 0);
    }
}
