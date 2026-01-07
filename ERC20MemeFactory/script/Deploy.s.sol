// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Script.sol";
import "../src/MemeToken.sol";
import "../src/MemeFactory.sol";

/**
 * @title Deploy
 * @dev 部署脚本 / Deployment script
 *
 * 使用方法 / Usage:
 * 1. 启动 Anvil: anvil
 * 2. 部署: forge script script/Deploy.s.sol:Deploy --rpc-url http://127.0.0.1:8545 --broadcast
 */
contract Deploy is Script {
    function run() external {
        // 获取部署私钥 / Get deployment private key
        uint256 deployerPrivateKey = vm.envOr(
            "PRIVATE_KEY",
            uint256(
                0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
            )
        );

        // 获取 Router 和 WETH 地址 / Get Router and WETH addresses
        // 默认使用 MiniDex 本地部署地址 / Default to MiniDex local deployment addresses
        address router = vm.envOr("ROUTER_ADDRESS", address(0));
        address weth = vm.envOr("WETH_ADDRESS", address(0));

        vm.startBroadcast(deployerPrivateKey);

        // 1. 部署 MemeToken 实现合约 / Deploy MemeToken implementation
        MemeToken tokenImplementation = new MemeToken();
        console.log(
            "MemeToken Implementation deployed at:",
            address(tokenImplementation)
        );

        // 2. 如果没有提供 Router 和 WETH，部署 Mock 合约
        // If Router and WETH not provided, deploy mock contracts
        if (router == address(0) || weth == address(0)) {
            console.log("Warning: Using mock addresses for testing");
            // 使用测试地址 / Use test addresses
            router = address(0x1);
            weth = address(0x2);
        }

        // 3. 部署 MemeFactory / Deploy MemeFactory
        MemeFactory factory = new MemeFactory(
            address(tokenImplementation),
            router,
            weth
        );
        console.log("MemeFactory deployed at:", address(factory));

        vm.stopBroadcast();

        // 输出部署信息 / Output deployment info
        console.log("\n========== Deployment Summary ==========");
        console.log("MemeToken Implementation:", address(tokenImplementation));
        console.log("MemeFactory:", address(factory));
        console.log("Router:", router);
        console.log("WETH:", weth);
        console.log("Owner:", vm.addr(deployerPrivateKey));
        console.log("=========================================\n");
    }
}

/**
 * @title DeployWithMiniDex
 * @dev 与 MiniDex 集成的部署脚本 / Deployment script with MiniDex integration
 *
 * 需要先部署 MiniDex，然后设置环境变量：
 * $env:ROUTER_ADDRESS="0x..."
 * $env:WETH_ADDRESS="0x..."
 * forge script script/Deploy.s.sol:DeployWithMiniDex --rpc-url http://127.0.0.1:8545 --broadcast
 */
contract DeployWithMiniDex is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envOr(
            "PRIVATE_KEY",
            uint256(
                0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
            )
        );

        // MiniDex 合约地址必须提供 / MiniDex addresses must be provided
        address router = vm.envAddress("ROUTER_ADDRESS");
        address weth = vm.envAddress("WETH_ADDRESS");

        require(router != address(0), "ROUTER_ADDRESS not set");
        require(weth != address(0), "WETH_ADDRESS not set");

        vm.startBroadcast(deployerPrivateKey);

        // 1. 部署 MemeToken 实现合约
        MemeToken tokenImplementation = new MemeToken();
        console.log("MemeToken Implementation:", address(tokenImplementation));

        // 2. 部署 MemeFactory
        MemeFactory factory = new MemeFactory(
            address(tokenImplementation),
            router,
            weth
        );
        console.log("MemeFactory:", address(factory));

        vm.stopBroadcast();

        console.log("\n========== Deployment Complete ==========");
        console.log("MemeToken Implementation:", address(tokenImplementation));
        console.log("MemeFactory:", address(factory));
        console.log("Router:", router);
        console.log("WETH:", weth);
        console.log("==========================================\n");
    }
}
