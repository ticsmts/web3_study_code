// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";

import {ZZToken} from "../contracts/ZZToken.sol";
import {StakingPool} from "../contracts/StakingPool.sol";
import {MockWETH} from "../contracts/mocks/MockWETH.sol";
import {MockLendingPool} from "../contracts/mocks/MockLendingPool.sol";

contract StakingPoolTest is Test {
    ZZToken private zz;
    StakingPool private staking;
    MockWETH private weth;
    MockLendingPool private pool;

    address private alice = address(0xA11CE);
    address private bob = address(0xB0B);

    function setUp() public {
        weth = new MockWETH();
        pool = new MockLendingPool();
        zz = new ZZToken();
        staking = new StakingPool(address(zz), address(weth), address(pool));
        zz.setMinter(address(staking));
    }

    function testStakeAndClaimSingleUser() public {
        vm.deal(alice, 1 ether);
        vm.prank(alice);
        staking.stake{value: 1 ether}();

        vm.roll(block.number + 10);

        vm.prank(alice);
        staking.claim();

        assertEq(zz.balanceOf(alice), 100 ether);
    }

    function testRewardsSplitByTimeAndAmount() public {
        vm.deal(alice, 1 ether);
        vm.deal(bob, 1 ether);

        vm.prank(alice);
        staking.stake{value: 1 ether}();

        vm.roll(block.number + 10);

        vm.prank(bob);
        staking.stake{value: 1 ether}();

        vm.roll(block.number + 10);

        vm.prank(alice);
        staking.claim();

        vm.prank(bob);
        staking.claim();

        assertEq(zz.balanceOf(alice), 150 ether);
        assertEq(zz.balanceOf(bob), 50 ether);
    }

    function testUnstakeReturnsEth() public {
        vm.deal(alice, 1 ether);
        vm.prank(alice);
        staking.stake{value: 1 ether}();

        vm.roll(block.number + 1);

        vm.prank(alice);
        staking.unstake(1 ether);

        assertEq(alice.balance, 1 ether);
        assertEq(staking.balanceOf(alice), 0);
    }
}