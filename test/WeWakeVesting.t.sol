// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {WeWakeVesting} from "../src/WeWakeVesting.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockToken is ERC20 {
    constructor() ERC20("Mock", "MCK") {
        _mint(msg.sender, 1_000_000 ether);
    }
}

contract WeWakeVestingTest is Test {
    MockToken public token;
    WeWakeVesting public vesting;
    address public beneficiary;
    uint64 public start;
    uint64 public duration;

    function setUp() public {
        vm.warp(100); // Set initial timestamp to avoid 0 issues

        beneficiary = makeAddr("beneficiary");
        start = uint64(block.timestamp);
        duration = 365 days; // 1 year vesting

        token = new MockToken();
        vesting = new WeWakeVesting(beneficiary, start, duration);

        // Fund the vesting contract
        token.transfer(address(vesting), 1000 ether);
    }

    function testInitialization() public {
        assertEq(vesting.owner(), beneficiary);
        assertEq(vesting.start(), start);
        assertEq(vesting.duration(), duration);
    }

    function testVestingSchedule() public {
        // At start: 0 vested
        assertEq(vesting.vestedAmount(address(token), uint64(block.timestamp)), 0);
        
        // Halfway: 50% vested (Approx)
        vm.warp(start + duration / 2);
        uint256 vested = vesting.vestedAmount(address(token), uint64(block.timestamp));
        assertApproxEqAbs(vested, 500 ether, 1 ether);

        // Full duration: 100% vested
        vm.warp(start + duration);
        assertEq(vesting.vestedAmount(address(token), uint64(block.timestamp)), 1000 ether);
    }

    function testRelease() public {
        // Move to 50% time
        vm.warp(start + duration / 2);
        
        uint256 vested = vesting.vestedAmount(address(token), uint64(block.timestamp));
        vesting.release(address(token));

        assertEq(token.balanceOf(beneficiary), vested);
        assertEq(token.balanceOf(address(vesting)), 1000 ether - vested);
    }
}
