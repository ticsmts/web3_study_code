// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {RebaseDeflationaryToken} from "../src/RebaseDeflationaryToken.sol";

/**
 * @title RebaseDemo
 * @notice 演示 rebase 通缩效果的脚本
 *
 * 使用方法:
 * 1. 启动本地节点: anvil
 * 2. 运行脚本: forge script script/RebaseDemo.s.sol --rpc-url http://127.0.0.1:8545 --broadcast
 */
contract RebaseDemo is Script {
    function run() external {
        // 使用 Anvil 默认私钥
        uint256 deployerPrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        // 1. 部署合约
        console.log("=== Step 1: Deploy Token ===");
        RebaseDeflationaryToken token = new RebaseDeflationaryToken();
        console.log("Token deployed at:", address(token));

        // 2. 查看初始状态
        console.log("\n=== Step 2: Initial State ===");
        console.log("Total Supply:", token.totalSupply() / 1e18, "tokens");
        console.log(
            "Deployer Balance:",
            token.balanceOf(deployer) / 1e18,
            "tokens"
        );
        console.log("gonsPerFragment:", token.gonsPerFragment());

        // 3. 转账给测试地址
        address alice = address(0x70997970C51812dc3A010C7d01b50e0d17dc79C8);
        token.transfer(alice, 10_000_000 * 1e18); // 转 10M

        console.log("\n=== Step 3: After Transfer ===");
        console.log("Alice Balance:", token.balanceOf(alice) / 1e18, "tokens");
        console.log(
            "Deployer Balance:",
            token.balanceOf(deployer) / 1e18,
            "tokens"
        );

        vm.stopBroadcast();

        console.log("\n=== Step 4: Simulate Rebase (1 year later) ===");
        console.log("Use these commands to test rebase:");
        console.log("");
        console.log("# Warp time forward 1 year:");
        console.log(
            "cast rpc evm_increaseTime 31536000 --rpc-url http://127.0.0.1:8545"
        );
        console.log("cast rpc evm_mine --rpc-url http://127.0.0.1:8545");
        console.log("");
        console.log("# Call rebase:");
        console.log(
            'cast send [CONTRACT_ADDRESS] "rebase()" --rpc-url http://127.0.0.1:8545 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80'
        );
        console.log("");
        console.log("# Check balances after rebase:");
        console.log(
            'cast call [CONTRACT_ADDRESS] "totalSupply()" --rpc-url http://127.0.0.1:8545'
        );
        console.log(
            'cast call [CONTRACT_ADDRESS] "balanceOf(address)" [ALICE_ADDRESS] --rpc-url http://127.0.0.1:8545'
        );
    }
}
