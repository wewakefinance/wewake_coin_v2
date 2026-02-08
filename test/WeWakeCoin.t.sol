// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test, console} from "lib/forge-std/src/Test.sol";
import {WeWakeCoin} from "../src/WeWakeCoin.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract WeWakeCoinTest is Test {
    WeWakeCoin coin;

    address owner = address(0x1);
    address user = address(0x2);

    function setUp() public {
        vm.startPrank(owner);
        coin = new WeWakeCoin(owner);
        vm.stopPrank();
    }

    function testOpenBurnRevertsIfNotEnoughTokens() public {
        uint256 balance = coin.balanceOf(owner);

        vm.startPrank(owner);
        // Ожидаем кастомную ошибку
        vm.expectRevert(WeWakeCoin.InsufficientBalanceToBurn.selector);
        coin.openBurn(balance + 1);
        vm.stopPrank();
    }

    function testOpenBurnRevertsIfNotOwner() public {
        // 1. Сначала дадим пользователю токены, чтобы исключить ошибку нехватки баланса
        vm.prank(owner);
        coin.transfer(user, 100 ether);

        // 2. Теперь пробуем сжечь от лица user
        vm.startPrank(user);
        // 3. Ожидаем ошибку именно Ownable (библиотечную)
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user));
        coin.openBurn(100 ether);
        vm.stopPrank();
    }

    function testOpenBurnRevertsIfZeroAmount() public {
        vm.startPrank(owner);
        vm.expectRevert(WeWakeCoin.BurnAmountZero.selector);
        coin.openBurn(0);
        vm.stopPrank();
    }

    function testOpenBurnRevertsIfAlreadyOpen() public {
        vm.startPrank(owner);
        coin.openBurn(100 ether);
        
        vm.expectRevert(WeWakeCoin.BurnProcessAlreadyActive.selector);
        coin.openBurn(100 ether);
        vm.stopPrank();
    }

    function testOpenBurnTransfersAndSetsTimestamp() public {
        uint256 amount = 200 ether;
        uint256 currentTimestamp = block.timestamp;

        vm.startPrank(owner);
        coin.openBurn(amount);
        vm.stopPrank();

        (uint256 burnTimestamp, uint256 burnAmount) = coin.burnInfo();
        
        assertEq(burnAmount, amount);
        // Проверяем, что таймлок установлен на 2.5 дня вперед
        assertEq(burnTimestamp, currentTimestamp + 2 days + 12 hours);
        assertEq(coin.balanceOf(address(coin)), amount);
    }

    function testFinishBurnRevertsIfNotOpen() public {
        vm.startPrank(owner);
        vm.expectRevert(WeWakeCoin.BurnProcessNotInitiated.selector);
        coin.finishBurn();
        vm.stopPrank();
    }

    function testFinishBurnRevertsIfTooEarly() public {
        vm.startPrank(owner);
        coin.openBurn(100 ether);
        
        (uint256 unlockTime, ) = coin.burnInfo();
        
        // Ожидаем ошибку с параметрами (текущее время, требуемое время)
        vm.expectRevert(
            abi.encodeWithSelector(
                WeWakeCoin.BurnTimelockNotExpired.selector, 
                block.timestamp, 
                unlockTime
            )
        );
        coin.finishBurn();
        vm.stopPrank();
    }

    function testFinishBurnWorksAfterTimePassed() public {
        uint256 amount = 100 ether;
        
        vm.startPrank(owner);
        coin.openBurn(amount);

        // Перематываем время на 2.5 дня + 1 секунду
        vm.warp(block.timestamp + 2 days + 12 hours + 1);

        uint256 beforeTotalSupply = coin.totalSupply();
        uint256 beforeContractBalance = coin.balanceOf(address(coin));

        coin.finishBurn();
        vm.stopPrank();

        assertEq(coin.balanceOf(address(coin)), 0);
        // Total Supply должен уменьшиться на сожженную сумму
        assertEq(coin.totalSupply(), beforeTotalSupply - beforeContractBalance);
        
        // Проверяем, что состояние сбросилось
        (uint256 ts, uint256 amt) = coin.burnInfo();
        assertEq(ts, 0);
        assertEq(amt, 0);
    }

    function testFinishBurnDoesNotBurnExtraTokens() public {
        uint256 burnAmount = 100 ether;
        uint256 extra = 50 ether;

        // Owner opens burn and also sends `extra` to `user`
        vm.startPrank(owner);
        coin.openBurn(burnAmount);
        coin.transfer(user, extra);
        vm.stopPrank();

        // `user` sends extra tokens to the contract address
        vm.startPrank(user);
        coin.transfer(address(coin), extra);
        vm.stopPrank();

        // Move time forward and finish burn
        vm.startPrank(owner);
        vm.warp(block.timestamp + 2 days + 12 hours + 1);

        uint256 beforeTotalSupply = coin.totalSupply();

        coin.finishBurn();
        vm.stopPrank();

        // Contract should keep the extra tokens sent by `user`
        assertEq(coin.balanceOf(address(coin)), extra);
        // Total supply should decrease only by the originally locked burnAmount
        assertEq(coin.totalSupply(), beforeTotalSupply - burnAmount);
    }

    function testVotingPowerTransfer() public {
        vm.startPrank(owner);
        uint256 ownerVotesBefore = coin.getVotes(owner);
        coin.delegate(owner); 
        uint256 ownerVotesAfter = coin.getVotes(owner);
        assertEq(ownerVotesAfter - ownerVotesBefore, coin.balanceOf(owner));
        vm.stopPrank();
    }

    function testCancelBurnReturnsTokensToOwner() public {
        uint256 amount = 120 ether;
        vm.startPrank(owner);
        uint256 ownerBefore = coin.balanceOf(owner);
        coin.openBurn(amount);
        // Owner decides to cancel before timelock
        coin.cancelBurn();
        vm.stopPrank();

        // Contract should have zero balance and owner should have the tokens back
        assertEq(coin.balanceOf(address(coin)), 0);
        assertEq(coin.balanceOf(owner), ownerBefore);

        (uint256 ts, uint256 amt) = coin.burnInfo();
        assertEq(ts, 0);
        assertEq(amt, 0);
    }

    function testCancelBurnRevertsIfNotOwner() public {
        vm.startPrank(owner);
        coin.openBurn(50 ether);
        vm.stopPrank();

        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user));
        coin.cancelBurn();
        vm.stopPrank();
    }

    function testNoncesReturnsZeroForNewAddress() public {
        assertEq(coin.nonces(address(0x3)), 0);
    }
}
