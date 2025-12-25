// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/MultiSigWallet.sol";
import "./Target.sol";

contract MultiSigWalletTest is Test {
    MultiSigWallet wallet;
    Target target;

    address owner1 = address(0x111);
    address owner2 = address(0x222);
    address owner3 = address(0x333);
    address outsider = address(0x999);
    address[] owners;

    function setUp() public {
        //address[] memory owners;
        // owners[0] = owner1;
        // owners[1] = owner2;
        // owners[2] = owner3;
        owners.push(owner1);
        owners.push(owner2);    
        owners.push(owner3);

        wallet = new MultiSigWallet(owners, 2);
        target = new Target();

        // 给多签打点 ETH，测试 value 转账/调用
        vm.deal(address(wallet), 10 ether);
    }

    function test_submit_ok() public {
        bytes memory data = abi.encodeWithSelector(Target.setX.selector, 42);

        vm.prank(owner1);
        uint256 txId = wallet.submit(address(target), 1 ether, data);

        // txId 应为 0（第一个提案）
        assertEq(txId, 0);

        // 读 public array 里的 struct：wallet.transactions(0)
        (address to, uint256 value, bytes memory d, bool executed, uint256 num) = wallet.transactions(0);
        assertEq(to, address(target));
        assertEq(value, 1 ether);
        assertEq(executed, false);
        assertEq(num, 0);
        assertEq(keccak256(d), keccak256(data));
    }

    function test_nonOwner_cannot_submit() public {
        vm.prank(outsider);
        vm.expectRevert("not owner");
        wallet.submit(address(target), 0, "");
    }

    function test_confirm_and_prevent_double_confirm() public {
        vm.prank(owner1);
        uint256 txId = wallet.submit(address(target), 0, "");

        vm.prank(owner2);
        wallet.confirm(txId);

        // 重复 confirm
        vm.prank(owner2);
        vm.expectRevert("tx already confirmed");
        wallet.confirm(txId);

        // 确认数为 1
        (, , , , uint256 num) = wallet.transactions(txId);
        assertEq(num, 1);
    }

    function test_cannot_execute_before_threshold() public {
        vm.prank(owner1);
        uint256 txId = wallet.submit(address(target), 0, "");

        vm.prank(owner2);
        wallet.confirm(txId);

        // 只有 1 个确认，不够 2
        vm.prank(outsider);
        vm.expectRevert("not enough confirmations");
        wallet.execute(txId);
    }

    function test_anyone_can_execute_after_threshold() public {
        bytes memory data = abi.encodeWithSelector(Target.setX.selector, 777);

        vm.prank(owner1);
        uint256 txId = wallet.submit(address(target), 1 ether, data);

        vm.prank(owner2);
        wallet.confirm(txId);

        vm.prank(owner3);
        wallet.confirm(txId);

        // outsider 执行（题目要求）
        vm.prank(outsider);
        wallet.execute(txId);

        // 目标合约状态改变 + 收到 1 ether
        assertEq(target.x(), 777);
        assertEq(address(target).balance, 1 ether);

        // executed 变 true
        (, , , bool executed, ) = wallet.transactions(txId);
        assertTrue(executed);
    }

    function test_cannot_execute_twice() public {
        vm.prank(owner1);
        uint256 txId = wallet.submit(address(target), 0, "");

        vm.prank(owner2);
        wallet.confirm(txId);
        vm.prank(owner3);
        wallet.confirm(txId);

        vm.prank(outsider);
        wallet.execute(txId);

        vm.prank(outsider);
        vm.expectRevert("tx already executed");
        wallet.execute(txId);
    }
}
