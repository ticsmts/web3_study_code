// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test, console} from "forge-std/Test.sol";
import {ZZTOKEN} from "../src/ZZTOKEN.sol";

contract ZZTOKENTest is Test {
    ZZTOKEN public token;
    address public owner;
    address public user1;
    address public user2;

    function setUp() public {
        owner = address(this);
        user1 = address(0x1);
        user2 = address(0x2);

        token = new ZZTOKEN();
    }

    function test_InitialSupply() public view {
        assertEq(token.totalSupply(), 100000000 * 1e18);
        assertEq(token.balanceOf(owner), 100000000 * 1e18);
    }

    function test_Transfer() public {
        uint256 amount = 1000 * 1e18;

        token.transfer(user1, amount);

        assertEq(token.balanceOf(user1), amount);
        assertEq(token.balanceOf(owner), 100000000 * 1e18 - amount);
    }

    function test_TransferEmitsEvent() public {
        uint256 amount = 1000 * 1e18;

        vm.expectEmit(true, true, false, true);
        emit ZZTOKEN.Transfer(owner, user1, amount);

        token.transfer(user1, amount);
    }

    function test_MultipleTransfers() public {
        // 模拟生成多条转账
        for (uint256 i = 1; i <= 10; i++) {
            address recipient = address(uint160(i));
            uint256 amount = i * 1e18;
            token.transfer(recipient, amount);
        }

        // 验证第5个地址的余额
        assertEq(token.balanceOf(address(5)), 5 * 1e18);
    }
}
