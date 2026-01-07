// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {UniswapV2Factory} from "../src/core/UniswapV2Factory.sol";
import {UniswapV2Router02} from "../src/periphery/UniswapV2Router02.sol";
import {UniswapV2Pair} from "../src/core/UniswapV2Pair.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";

/**
 * @title SwapTest
 * @notice 测试MiniDex swap功能 Test MiniDex swap functionality
 */
contract SwapTest is Test {
    UniswapV2Factory factory;
    UniswapV2Router02 router;
    MockERC20 tokenA;
    MockERC20 tokenB;
    MockERC20 weth;

    address user = address(0x1234);

    function setUp() public {
        // Deploy Factory
        factory = new UniswapV2Factory(address(this));

        // Deploy tokens
        weth = new MockERC20("Wrapped Ether", "WETH", 1000000 ether);
        tokenA = new MockERC20("Mock USDC", "USDC", 10000000 ether);
        tokenB = new MockERC20("Mock DAI", "DAI", 10000000 ether);

        // Deploy Router
        router = new UniswapV2Router02(address(factory), address(weth));

        // Create pair and add liquidity
        tokenA.approve(address(router), 10000 ether);
        tokenB.approve(address(router), 10000 ether);

        router.addLiquidity(
            address(tokenA),
            address(tokenB),
            10000 ether,
            10000 ether,
            0,
            0,
            address(this),
            block.timestamp + 1000
        );

        // Give user some tokens
        tokenA.mint(user, 1000 ether);
    }

    function test_SwapExactTokensForTokens() public {
        vm.startPrank(user);

        // Approve router
        tokenA.approve(address(router), 100 ether);

        // Get balance before
        uint256 balanceBefore = tokenB.balanceOf(user);

        // Swap 100 USDC for DAI
        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);

        uint[] memory amounts = router.swapExactTokensForTokens(
            100 ether, // amountIn
            90 ether, // amountOutMin (expect ~99 due to 0.3% fee)
            path,
            user,
            block.timestamp + 1000
        );

        vm.stopPrank();

        // Verify swap succeeded
        uint256 balanceAfter = tokenB.balanceOf(user);
        uint256 received = balanceAfter - balanceBefore;

        console.log("Swapped 100 USDC");
        console.log("Received DAI:", received / 1e18);
        console.log("Expected ~99 DAI (after 0.3% fee)");

        assertGt(received, 90 ether, "Should receive more than 90 DAI");
        assertLt(received, 100 ether, "Should receive less than 100 DAI (fee)");
    }

    function test_AddRemoveLiquidity() public {
        // Get pair
        address pairAddr = factory.getPair(address(tokenA), address(tokenB));
        UniswapV2Pair pair = UniswapV2Pair(pairAddr);

        uint256 lpBalance = pair.balanceOf(address(this));
        console.log("LP Token Balance:", lpBalance / 1e18);

        assertGt(lpBalance, 0, "Should have LP tokens");

        // Remove half liquidity
        pair.approve(address(router), lpBalance / 2);

        (uint amountA, uint amountB) = router.removeLiquidity(
            address(tokenA),
            address(tokenB),
            lpBalance / 2,
            0,
            0,
            address(this),
            block.timestamp + 1000
        );

        console.log("Removed liquidity - TokenA:", amountA / 1e18);
        console.log("Removed liquidity - TokenB:", amountB / 1e18);

        assertGt(amountA, 0, "Should receive tokenA");
        assertGt(amountB, 0, "Should receive tokenB");
    }

    function test_GetAmountsOut() public view {
        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);

        uint[] memory amounts = router.getAmountsOut(100 ether, path);

        console.log("Input: 100 USDC");
        console.log("Expected Output:", amounts[1] / 1e18, "DAI");

        assertGt(amounts[1], 0, "Should have output amount");
    }
}
