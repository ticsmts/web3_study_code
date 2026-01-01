// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {BigBankV2} from "../src/BigBankV2.sol";

contract BigBankV2Test is Test {
    BigBankV2 public bank;

    address public owner = address(this);
    // Use addresses far from HEAD (address(1)) to avoid collision
    address public user1 = address(0x1001);
    address public user2 = address(0x1002);
    address public user3 = address(0x1003);

    function setUp() public {
        bank = new BigBankV2();

        // 给测试用户一些 ETH
        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);
        vm.deal(user3, 100 ether);
    }

    // 允许测试合约接收 ETH
    receive() external payable {}

    // ============ 存款测试 ============

    function test_DepositViaDeposit() public {
        vm.prank(user1);
        bank.deposit{value: 1 ether}();

        assertEq(bank.balances(user1), 1 ether);
    }

    function test_DepositViaReceive() public {
        vm.prank(user1);
        (bool success, ) = address(bank).call{value: 1 ether}("");
        assertTrue(success);

        assertEq(bank.balances(user1), 1 ether);
    }

    function test_RevertIfDepositTooSmall() public {
        vm.prank(user1);
        vm.expectRevert("Deposit must be >= 0.001 ETH");
        bank.deposit{value: 0.0001 ether}();
    }

    function test_MultipleDeposits() public {
        vm.startPrank(user1);
        bank.deposit{value: 1 ether}();
        bank.deposit{value: 2 ether}();
        vm.stopPrank();

        assertEq(bank.balances(user1), 3 ether);
    }

    // ============ 链表测试 ============

    function test_SingleUserInTopList() public {
        vm.prank(user1);
        bank.deposit{value: 1 ether}();

        (address[] memory users, uint256[] memory amounts) = bank
            .getTopDepositors();

        assertEq(users.length, 1);
        assertEq(users[0], user1);
        assertEq(amounts[0], 1 ether);
    }

    function test_TopListSortedByBalance() public {
        vm.prank(user1);
        bank.deposit{value: 1 ether}();

        vm.prank(user2);
        bank.deposit{value: 3 ether}();

        vm.prank(user3);
        bank.deposit{value: 2 ether}();

        (address[] memory users, uint256[] memory amounts) = bank
            .getTopDepositors();

        assertEq(users.length, 3);
        // user2 (3 ETH) > user3 (2 ETH) > user1 (1 ETH)
        assertEq(users[0], user2);
        assertEq(amounts[0], 3 ether);
        assertEq(users[1], user3);
        assertEq(amounts[1], 2 ether);
        assertEq(users[2], user1);
        assertEq(amounts[2], 1 ether);
    }

    function test_TopListMaxSize10() public {
        // 创建 15 个用户存款
        for (uint256 i = 1; i <= 15; i++) {
            address user = address(uint160(i + 100));
            vm.deal(user, 100 ether);
            vm.prank(user);
            bank.deposit{value: i * 0.1 ether}();
        }

        (address[] memory users, ) = bank.getTopDepositors();

        // 只保留前10名
        assertEq(users.length, 10);
        assertEq(bank.listSize(), 10);
    }

    function test_TopListUpdatesOnAdditionalDeposit() public {
        vm.prank(user1);
        bank.deposit{value: 1 ether}();

        vm.prank(user2);
        bank.deposit{value: 3 ether}();

        // user1 再存款，超过 user2
        vm.prank(user1);
        bank.deposit{value: 5 ether}();

        (address[] memory users, uint256[] memory amounts) = bank
            .getTopDepositors();

        // user1 (6 ETH) > user2 (3 ETH)
        assertEq(users[0], user1);
        assertEq(amounts[0], 6 ether);
        assertEq(users[1], user2);
        assertEq(amounts[1], 3 ether);
    }

    // ============ 管理功能测试 ============

    function test_OnlyOwnerCanWithdraw() public {
        vm.prank(user1);
        bank.deposit{value: 5 ether}();

        vm.prank(user1);
        vm.expectRevert("Not owner");
        bank.withdraw(1 ether, payable(user1));
    }

    function test_OwnerWithdraw() public {
        vm.prank(user1);
        bank.deposit{value: 5 ether}();

        uint256 balanceBefore = address(owner).balance;
        bank.withdraw(2 ether, payable(owner));
        uint256 balanceAfter = address(owner).balance;

        assertEq(balanceAfter - balanceBefore, 2 ether);
    }

    function test_SetAdmin() public {
        bank.setAdmin(user1);
        assertEq(bank.owner(), user1);
    }

    function test_OnlyOwnerCanSetAdmin() public {
        vm.prank(user1);
        vm.expectRevert("Not owner");
        bank.setAdmin(user2);
    }

    // ============ 查询功能测试 ============

    function test_GetBalance() public {
        vm.prank(user1);
        bank.deposit{value: 2.5 ether}();

        assertEq(bank.getBalance(user1), 2.5 ether);
    }

    function test_GetMyBalance() public {
        vm.prank(user1);
        bank.deposit{value: 1.5 ether}();

        vm.prank(user1);
        assertEq(bank.getMyBalance(), 1.5 ether);
    }

    function test_GetTotalBalance() public {
        vm.prank(user1);
        bank.deposit{value: 1 ether}();

        vm.prank(user2);
        bank.deposit{value: 2 ether}();

        assertEq(bank.getTotalBalance(), 3 ether);
    }
}
