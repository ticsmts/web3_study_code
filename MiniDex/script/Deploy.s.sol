// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {UniswapV2Factory} from "../src/core/UniswapV2Factory.sol";
import {UniswapV2Router02} from "../src/periphery/UniswapV2Router02.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {UniswapV2Pair} from "../src/core/UniswapV2Pair.sol";

/**
 * @title Deploy Script for MiniDex
 * @notice 部署Uniswap V2克隆 - Deploy Uniswap V2 Clone
 *
 * 部署流程 Deployment Flow:
 * 1. 部署Factory合约 / Deploy Factory contract
 * 2. 计算并记录init_code_hash / Calculate and log init_code_hash
 * 3. 部署Router02合约 / Deploy Router02 contract
 * 4. 部署测试代币 / Deploy test tokens
 * 5. 创建交易对 / Create pairs
 * 6. 添加初始流动性 / Add initial liquidity
 */
contract Deploy is Script {
    UniswapV2Factory public factory;
    UniswapV2Router02 public router;
    MockERC20 public tokenA; // Mock USDC
    MockERC20 public tokenB; // Mock DAI
    MockERC20 public weth; // Mock WETH

    function run() public {
        uint256 deployerPrivateKey = vm.envOr(
            "PRIVATE_KEY",
            uint256(
                0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
            )
        );
        address deployer = vm.addr(deployerPrivateKey);

        console.log("==========================================");
        console.log("Deploying MiniDex (Uniswap V2 Clone)");
        console.log("Deployer:", deployer);
        console.log("==========================================\n");

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy Factory
        console.log("Step 1: Deploying Factory...");
        factory = new UniswapV2Factory(deployer); // deployer is feeToSetter
        console.log("Factory deployed at:", address(factory));

        // 2. Calculate and log init_code_hash
        // ⚠️ CRITICAL: This hash must be updated in UniswapV2Library.pairFor()
        console.log("\n==========================================");
        console.log("CRITICAL: INIT_CODE_HASH");
        console.log("==========================================");
        bytes32 initCodeHash = keccak256(type(UniswapV2Pair).creationCode);
        console.log("Pair init_code_hash:");
        console.logBytes32(initCodeHash);
        console.log("\\n[!] IMPORTANT: Copy this hash to:");
        console.log("    src/periphery/UniswapV2Library.sol");
        console.log("    Line ~45: INIT_CODE_PAIR_HASH variable");
        console.log("==========================================\n");

        // Also verify using factory method
        bytes32 factoryHash = factory.pairCodeHash();
        console.log("Verification - Factory pairCodeHash:");
        console.logBytes32(factoryHash);
        require(initCodeHash == factoryHash, "Hash mismatch!");
        console.log("[OK] Hash verified!\n");

        // 3. Deploy Mock WETH
        console.log("Step 2: Deploying Mock WETH...");
        weth = new MockERC20("Wrapped Ether", "WETH", 1000000 * 1e18);
        console.log("WETH deployed at:", address(weth));

        // 4. Deploy Router02
        console.log("\nStep 3: Deploying Router02...");
        router = new UniswapV2Router02(address(factory), address(weth));
        console.log("Router02 deployed at:", address(router));

        // 5. Deploy Test Tokens
        console.log("\nStep 4: Deploying Test Tokens...");
        tokenA = new MockERC20("Mock USDC", "USDC", 10000000 * 1e18); // 10M USDC
        tokenB = new MockERC20("Mock DAI", "DAI", 10000000 * 1e18); // 10M DAI
        console.log("USDC deployed at:", address(tokenA));
        console.log("DAI deployed at:", address(tokenB));

        // 6. Create Pairs
        console.log("\nStep 5: Creating Trading Pairs...");
        address pairAB = factory.createPair(address(tokenA), address(tokenB));
        console.log("USDC/DAI Pair:", pairAB);

        address pairAW = factory.createPair(address(tokenA), address(weth));
        console.log("USDC/WETH Pair:", pairAW);

        address pairBW = factory.createPair(address(tokenB), address(weth));
        console.log("DAI/WETH Pair:", pairBW);

        // 7. Add Initial Liquidity
        console.log("\nStep 6: Adding Initial Liquidity...");

        // Add USDC/DAI liquidity: 1000 USDC + 1000 DAI
        tokenA.approve(address(router), 1000 * 1e18);
        tokenB.approve(address(router), 1000 * 1e18);
        router.addLiquidity(
            address(tokenA),
            address(tokenB),
            1000 * 1e18,
            1000 * 1e18,
            0,
            0,
            deployer,
            block.timestamp + 1000
        );
        console.log("[OK] Added 1000 USDC + 1000 DAI");

        // Add USDC/WETH liquidity: 30000 USDC + 10 WETH (1 WETH = 3000 USDC)
        tokenA.approve(address(router), 30000 * 1e18);
        weth.approve(address(router), 10 * 1e18);
        router.addLiquidity(
            address(tokenA),
            address(weth),
            30000 * 1e18,
            10 * 1e18,
            0,
            0,
            deployer,
            block.timestamp + 1000
        );
        console.log("[OK] Added 30000 USDC + 10 WETH (1 WETH = 3000 USDC)");

        // Add DAI/WETH liquidity: 30000 DAI + 10 WETH (1 WETH = 3000 DAI)
        tokenB.approve(address(router), 30000 * 1e18);
        weth.approve(address(router), 10 * 1e18);
        router.addLiquidity(
            address(tokenB),
            address(weth),
            30000 * 1e18,
            10 * 1e18,
            0,
            0,
            deployer,
            block.timestamp + 1000
        );
        console.log("[OK] Added 30000 DAI + 10 WETH (1 WETH = 3000 DAI)");

        vm.stopBroadcast();

        // Print Summary
        console.log("\n==========================================");
        console.log("DEPLOYMENT SUMMARY");
        console.log("==========================================");
        console.log("Factory:", address(factory));
        console.log("Router02:", address(router));
        console.log("WETH:", address(weth));
        console.log("USDC:", address(tokenA));
        console.log("DAI:", address(tokenB));
        console.log("\nPairs:");
        console.log("  USDC/DAI:", pairAB);
        console.log("  USDC/WETH:", pairAW);
        console.log("  DAI/WETH:", pairBW);
        console.log("\nTotal Pairs Created:", factory.allPairsLength());
        console.log("==========================================\n");
        console.log("Deployment complete!");
    }
}
