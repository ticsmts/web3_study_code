// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {BigBankV2} from "../src/BigBankV2.sol";
import {BigBankV2Automation} from "../src/BigBankV2Automation.sol";

contract BigBankV2AutomationTest is Test {
    BigBankV2 public bank;
    BigBankV2Automation public automation;

    address public owner = address(this);
    address public recipient = address(0x2001);
    address public user1 = address(0x1001);

    uint256 public constant THRESHOLD = 0.1 ether;

    function setUp() public {
        // 部署 BigBankV2
        bank = new BigBankV2();

        // 部署 Automation 合约
        automation = new BigBankV2Automation(
            address(bank),
            recipient,
            THRESHOLD
        );

        // 设置 Automation 合约地址
        bank.setAutomationContract(address(automation));

        // 给测试用户一些 ETH
        vm.deal(user1, 100 ether);
        vm.deal(recipient, 0);
    }

    // 允许测试合约接收 ETH
    receive() external payable {}

    // ============ checkUpkeep 测试 ============

    function test_CheckUpkeepReturnsFalseWhenBelowThreshold() public {
        // 存入少于阈值的金额
        vm.prank(user1);
        bank.deposit{value: 0.05 ether}();

        (bool upkeepNeeded, ) = automation.checkUpkeep("");
        assertFalse(upkeepNeeded);
    }

    function test_CheckUpkeepReturnsTrueWhenAboveThreshold() public {
        // 存入超过阈值的金额
        vm.prank(user1);
        bank.deposit{value: 0.2 ether}();

        // 跳过最小间隔
        vm.warp(block.timestamp + 1 hours);

        (bool upkeepNeeded, ) = automation.checkUpkeep("");
        assertTrue(upkeepNeeded);
    }

    function test_CheckUpkeepReturnsFalseWhenIntervalNotMet() public {
        // 存入超过阈值的金额
        vm.prank(user1);
        bank.deposit{value: 0.2 ether}();

        // 不跳过时间，间隔未满足
        (bool upkeepNeeded, ) = automation.checkUpkeep("");
        // 由于 lastPerformTime 默认为 0，所以第一次检查应该返回 true
        // 执行一次后再检查
        vm.warp(block.timestamp + 1 hours);
        automation.performUpkeep("");

        // 立即再次检查，间隔未满足
        vm.prank(user1);
        bank.deposit{value: 0.2 ether}();

        (upkeepNeeded, ) = automation.checkUpkeep("");
        assertFalse(upkeepNeeded);
    }

    // ============ performUpkeep 测试 ============

    function test_PerformUpkeepTransfersHalfBalance() public {
        // 存入 1 ETH
        vm.prank(user1);
        bank.deposit{value: 1 ether}();

        // 跳过最小间隔
        vm.warp(block.timestamp + 1 hours);

        uint256 recipientBalanceBefore = recipient.balance;
        uint256 bankBalanceBefore = address(bank).balance;

        // 执行 upkeep
        automation.performUpkeep("");

        uint256 recipientBalanceAfter = recipient.balance;
        uint256 bankBalanceAfter = address(bank).balance;

        // 验证转移了一半
        assertEq(recipientBalanceAfter - recipientBalanceBefore, 0.5 ether);
        assertEq(bankBalanceBefore - bankBalanceAfter, 0.5 ether);
    }

    function test_PerformUpkeepRevertsWhenBelowThreshold() public {
        // 存入少于阈值的金额
        vm.prank(user1);
        bank.deposit{value: 0.05 ether}();

        // 跳过最小间隔
        vm.warp(block.timestamp + 1 hours);

        vm.expectRevert(BigBankV2Automation.ThresholdNotMet.selector);
        automation.performUpkeep("");
    }

    function test_PerformUpkeepRevertsWhenIntervalNotMet() public {
        // 存入超过阈值的金额
        vm.prank(user1);
        bank.deposit{value: 0.2 ether}();

        // 跳过最小间隔并执行第一次
        vm.warp(block.timestamp + 1 hours);
        automation.performUpkeep("");

        // 再次存款
        vm.prank(user1);
        bank.deposit{value: 0.2 ether}();

        // 立即尝试执行，应该失败
        vm.expectRevert(BigBankV2Automation.IntervalNotMet.selector);
        automation.performUpkeep("");
    }

    // ============ 管理功能测试 ============

    function test_OnlyOwnerCanSetThreshold() public {
        vm.prank(user1);
        vm.expectRevert(BigBankV2Automation.NotOwner.selector);
        automation.setThreshold(1 ether);
    }

    function test_OwnerCanSetThreshold() public {
        automation.setThreshold(1 ether);
        assertEq(automation.threshold(), 1 ether);
    }

    function test_CanPerformUpkeepReturnsCorrectStatus() public {
        // 跳过最小间隔时间，确保 intervalMet 为 true
        vm.warp(block.timestamp + 1 hours);

        // 初始状态：余额为 0
        (bool thresholdMet, bool intervalMet) = automation.canPerformUpkeep();
        assertFalse(thresholdMet);
        assertTrue(intervalMet);

        // 存款后
        vm.prank(user1);
        bank.deposit{value: 0.2 ether}();

        (thresholdMet, intervalMet) = automation.canPerformUpkeep();
        assertTrue(thresholdMet);
        assertTrue(intervalMet);
    }

    // ============ Authorization 测试 ============

    function test_AutomationContractCanWithdraw() public {
        vm.prank(user1);
        bank.deposit{value: 1 ether}();

        // Automation 合约可以调用 withdraw
        vm.prank(address(automation));
        bank.withdraw(0.5 ether, payable(recipient));

        assertEq(recipient.balance, 0.5 ether);
    }

    function test_RandomAddressCannotWithdraw() public {
        vm.prank(user1);
        bank.deposit{value: 1 ether}();

        // 非授权地址不能调用 withdraw
        vm.prank(user1);
        vm.expectRevert("Not authorized");
        bank.withdraw(0.5 ether, payable(user1));
    }
}
