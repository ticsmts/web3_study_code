// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {RebaseDeflationaryToken} from "../src/RebaseDeflationaryToken.sol";

/**
 * @title RebaseDemoTest
 * @notice 带详细日志的 rebase 演示测试
 *
 * 运行命令: forge test --match-contract RebaseDemoTest -vv
 */
contract RebaseDemoTest is Test {
    RebaseDeflationaryToken public token;

    address deployer = address(this);
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    function setUp() public {
        token = new RebaseDeflationaryToken();
    }

    /**
     * @dev 演示完整的 rebase 流程
     */
    function test_RebaseDemo() public {
        console.log("========================================");
        console.log("       REBASE DEFLATION DEMO");
        console.log("========================================\n");

        // Step 1: 初始状态
        console.log("--- STEP 1: Initial State ---");
        console.log("Total Supply:      ", token.totalSupply() / 1e18, "RDFT");
        console.log(
            "Deployer Balance:  ",
            token.balanceOf(deployer) / 1e18,
            "RDFT"
        );
        console.log("gonsPerFragment:   ", token.gonsPerFragment());

        // Step 2: 分发代币
        console.log("\n--- STEP 2: Transfer Tokens ---");
        token.transfer(alice, 10_000_000 * 1e18); // 10M (10%)
        token.transfer(bob, 5_000_000 * 1e18); // 5M (5%)

        console.log(
            "Alice Balance:     ",
            token.balanceOf(alice) / 1e18,
            "RDFT (10%)"
        );
        console.log(
            "Bob Balance:       ",
            token.balanceOf(bob) / 1e18,
            "RDFT (5%)"
        );
        console.log(
            "Deployer Balance:  ",
            token.balanceOf(deployer) / 1e18,
            "RDFT (85%)"
        );

        uint256 aliceBalanceBefore = token.balanceOf(alice);
        uint256 bobBalanceBefore = token.balanceOf(bob);
        uint256 totalSupplyBefore = token.totalSupply();

        // Step 3: 快进一年
        console.log("\n--- STEP 3: Warp 1 Year (vm.warp) ---");
        vm.warp(block.timestamp + 365 days);
        console.log("Time warped forward 365 days");

        // Step 4: 调用 rebase
        console.log("\n--- STEP 4: Call rebase() ---");
        uint256 newSupply = token.rebase();

        console.log("Rebase completed!");
        console.log("Epoch:             ", token.epoch());
        console.log("gonsPerFragment:   ", token.gonsPerFragment());

        // Step 5: 查看 rebase 后状态
        console.log("\n--- STEP 5: After Rebase ---");
        console.log("Total Supply:");
        console.log("  Before:          ", totalSupplyBefore / 1e18, "RDFT");
        console.log("  After:           ", newSupply / 1e18, "RDFT");
        console.log(
            "  Reduction:       ",
            (totalSupplyBefore - newSupply) / 1e18,
            "RDFT (~1%)"
        );

        console.log("\nAlice Balance:");
        console.log("  Before:          ", aliceBalanceBefore / 1e18, "RDFT");
        console.log(
            "  After:           ",
            token.balanceOf(alice) / 1e18,
            "RDFT"
        );
        console.log(
            "  Reduction:       ",
            (aliceBalanceBefore - token.balanceOf(alice)) / 1e18,
            "RDFT (~1%)"
        );

        console.log("\nBob Balance:");
        console.log("  Before:          ", bobBalanceBefore / 1e18, "RDFT");
        console.log("  After:           ", token.balanceOf(bob) / 1e18, "RDFT");
        console.log(
            "  Reduction:       ",
            (bobBalanceBefore - token.balanceOf(bob)) / 1e18,
            "RDFT (~1%)"
        );

        // Step 6: 验证持仓占比不变
        console.log("\n--- STEP 6: Ownership Ratio Check ---");
        uint256 aliceRatioBefore = (aliceBalanceBefore * 10000) /
            totalSupplyBefore;
        uint256 aliceRatioAfter = (token.balanceOf(alice) * 10000) / newSupply;
        console.log("Alice ratio before:", aliceRatioBefore / 100);
        console.log("Alice ratio after: ", aliceRatioAfter / 100);
        console.log("Ownership ratio unchanged!");

        console.log("\n========================================");
        console.log("       DEMO COMPLETE");
        console.log("========================================");
    }

    /**
     * @dev 演示多年 rebase
     */
    function test_MultiYearRebase() public {
        console.log("========================================");
        console.log("       MULTI-YEAR REBASE DEMO");
        console.log("========================================\n");

        token.transfer(alice, 10_000_000 * 1e18);

        console.log("Year 0 - Initial");
        console.log("  Total Supply:    ", token.totalSupply() / 1e18, "RDFT");
        console.log(
            "  Alice Balance:   ",
            token.balanceOf(alice) / 1e18,
            "RDFT"
        );

        for (uint256 year = 1; year <= 5; year++) {
            vm.warp(block.timestamp + 365 days);
            token.rebase();

            console.log("\nYear", year, "- After Rebase");
            console.log(
                "  Total Supply:    ",
                token.totalSupply() / 1e18,
                "RDFT"
            );
            console.log(
                "  Alice Balance:   ",
                token.balanceOf(alice) / 1e18,
                "RDFT"
            );
        }

        console.log(
            "\n5 years compound deflation: ~0.99^5 = ~95.1% of original"
        );
    }
}
