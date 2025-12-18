// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/Bank.sol";

contract BankTest is Test {
    Bank bank;

    address alice = address(0x1);
    address bob = address(0x2);
    address carol = address(0x3);
    address dave = address(0x4);


    function setUp() public{
        bank = new Bank();

        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
        vm.deal(carol, 10 ether);
        vm.deal(dave, 10 ether);
    }

    //测试存款后bank账本中存款人余额及bank.balance是否正常更新
    function test_DepositUpdatesBalance() public{
        vm.prank(alice);
        bank.deposit{value: 1 ether}();

        assertEq(bank.balances(alice), 1 ether);
        assertEq(address(bank).balance, 1 ether);
    }

    //测试通过Receive方法存款, 模拟metamask直接转账
    function test_DepositViaReceive() public {
        vm.prank(alice);
        (bool ok, ) = address(bank).call{value: 2 ether}("");
        require(ok);

        assertEq(bank.balances(alice), 2 ether);
    }

    //测试工具函数
    function _deposit(address user, uint256 amount) internal  { 
        vm.prank(user);
        bank.deposit{value: amount}();
    }

    //只有一个用户，top3是否正常
    function test_Top3_OneUser() public {
        _deposit(alice, 1 ether);
        Bank.TopDepositor[3] memory top = bank.getTopDepositors();

        assertEq(top[0].user, alice);
        assertEq(top[0].amount, 1 ether);
    }

    //测试有两个用户时，top3是否正常
    function test_Top3_TwoUser() public {
        _deposit(alice, 1 ether);
        _deposit(bob, 2 ether);

        Bank.TopDepositor[3] memory top = bank.getTopDepositors();
        assertEq(top[0].user, bob);
        assertEq(top[1].user, alice);
    }

    //测试有三个用户时，top3是否正常
    function test_Top3_ThreeUser() public {
        _deposit(alice, 1 ether);
        _deposit(bob, 2 ether);
        _deposit(carol, 3 ether);
        
        Bank.TopDepositor[3] memory top = bank.getTopDepositors();
        assertEq(top[0].user, carol);
        assertEq(top[1].user, bob);
        assertEq(top[2].user, alice);
    }

    //测试有4个用户，top3是否正常
    function test_Top3_FourUser() public{
        _deposit(alice, 1 ether);
        _deposit(bob, 2 ether);
        _deposit(carol, 3 ether);
        _deposit(dave, 4 ether);
        
        Bank.TopDepositor[3] memory top = bank.getTopDepositors();
        assertEq(top[0].user, dave);
        assertEq(top[1].user, carol);
        assertEq(top[2].user, bob);
    }

    //测试一个用户多次存款是否正常
    function test_Top3_MultiDeposit() public{
        _deposit(alice, 1 ether);
        _deposit(bob, 2 ether);
        _deposit(carol, 3 ether);
        _deposit(alice, 3 ether);
        
        Bank.TopDepositor[3] memory top = bank.getTopDepositors();
        assertEq(top[0].user, alice);
        assertEq(top[1].user, carol);
        assertEq(top[2].user, bob);
    }


    //测试只有管理员可以取款
    function test_withdraw_Admin() public {
        _deposit(alice, 2 ether);
        uint256 before = address(bob).balance;

        bank.withdraw(1 ether, payable(bob));
        assertEq(bob.balance, before + 1 ether);
    }

    function test_withdraw_NotAdmin() public{
        _deposit(alice, 2 ether);
        vm.prank(bob);
        vm.expectRevert("Not owner");
        bank.withdraw(1 ether, payable(bob));
    }

}