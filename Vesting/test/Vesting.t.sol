// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/Vesting.sol";
import "../src/MockERC20.sol";

contract VestingTest is Test {
    Vesting public vesting;
    MockERC20 public token;
    address public beneficiary = address(0x123);
    uint256 public INITIAL_BALANCE = 1_000_000 * 10 ** 18;

    function setUp() public {
        token = new MockERC20("Test Token", "TT", INITIAL_BALANCE);
        vesting = new Vesting(token, beneficiary);

        // Transfer 100万 tokens to Vesting contract
        token.transfer(address(vesting), INITIAL_BALANCE);
    }

    function test_Initialization() public {
        assertEq(address(vesting.token()), address(token));
        assertEq(vesting.beneficiary(), beneficiary);
        assertEq(token.balanceOf(address(vesting)), INITIAL_BALANCE);
    }

    function test_CliffPeriod() public {
        // Warp to 11 months + 29 days (less than 12 months)
        vm.warp(block.timestamp + 12 * 30 days - 1);

        vm.expectRevert("No tokens are due for release");
        vesting.release();
    }

    function test_Month13Release() public {
        // Warp to start of Month 13 (exactly 12 * 30 days)
        vm.warp(block.timestamp + 12 * 30 days);

        uint256 expected = INITIAL_BALANCE / 24;
        vesting.release();

        assertEq(token.balanceOf(beneficiary), expected);
        assertEq(vesting.released(), expected);
    }

    function test_Month24Release() public {
        // Warp to start of Month 24 (12 month cliff + 11 months passed = 23 * 30 days)
        // Wait, start of Month 24 is 23 months passed.
        // Months since cliff: 23 - 12 = 11.
        // Vested months: 11 + 1 = 12.
        // Expected: 12/24 = 50%
        vm.warp(block.timestamp + 23 * 30 days);

        uint256 expected = INITIAL_BALANCE / 2;
        vesting.release();

        assertEq(token.balanceOf(beneficiary), expected);
    }

    function test_FullRelease() public {
        // Warp to 36 months (12 + 24)
        vm.warp(block.timestamp + 36 * 30 days);

        vesting.release();

        assertEq(token.balanceOf(beneficiary), INITIAL_BALANCE);
        assertEq(token.balanceOf(address(vesting)), 0);
    }

    function test_IncrementalRelease() public {
        uint256 monthlyAmount = INITIAL_BALANCE / 24;
        uint256 startTime = block.timestamp;

        // Release monthly
        for (uint256 i = 0; i < 24; i++) {
            vm.warp(startTime + (12 + i) * 30 days);
            vesting.release();

            uint256 expectedTotal = (i + 1) * monthlyAmount;
            // Handle precision if total isn't perfectly divisible by 24
            if (i == 23) {
                assertEq(token.balanceOf(beneficiary), INITIAL_BALANCE);
            } else {
                uint256 contractVested = (INITIAL_BALANCE * (i + 1)) / 24;
                assertEq(token.balanceOf(beneficiary), contractVested);
            }
        }
    }

    function test_IncrementalReleaseRelative() public {
        uint256 monthlyAmount = INITIAL_BALANCE / 24;

        // Jump to cliff end
        vm.warp(block.timestamp + 12 * 30 days);

        for (uint256 i = 1; i <= 24; i++) {
            vesting.release();
            if (i < 24) {
                vm.warp(block.timestamp + 30 days);
            }
        }

        assertEq(token.balanceOf(beneficiary), INITIAL_BALANCE);
    }
}
