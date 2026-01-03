// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Script.sol";
import "../src/NFTMarketV2.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title UpgradeToV2
 * @dev 将 NFT 市场从 V1 升级到 V2
 *
 * 升级步骤：
 * 1. 部署新的 V2 实现合约
 * 2. 调用代理合约的 upgradeToAndCall 升级到 V2
 *
 * 使用方式:
 * MARKET_PROXY=<proxy_address> forge script script/UpgradeToV2.s.sol --rpc-url http://127.0.0.1:8545 --broadcast
 */
contract UpgradeToV2 is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envOr(
            "PRIVATE_KEY",
            uint256(
                0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
            )
        );

        // 获取代理合约地址（需要通过环境变量或硬编码）
        address marketProxy = vm.envOr(
            "MARKET_PROXY",
            address(0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0) // 默认 Anvil 第四个部署的合约
        );

        console.log("Market Proxy:", marketProxy);
        console.log("Current version:", NFTMarketV1(marketProxy).version());

        vm.startBroadcast(deployerPrivateKey);

        // 1. 部署 V2 实现合约
        NFTMarketV2 marketV2Impl = new NFTMarketV2();
        console.log("NFTMarketV2 Implementation:", address(marketV2Impl));

        // 2. 升级代理合约到 V2 并调用 initializeV2()
        // 使用 UUPSUpgradeable 的 upgradeToAndCall
        UUPSUpgradeable(marketProxy).upgradeToAndCall(
            address(marketV2Impl),
            abi.encodeWithSelector(NFTMarketV2.initializeV2.selector)
        );

        console.log("Upgraded to V2!");
        console.log("New version:", NFTMarketV2(marketProxy).version());

        vm.stopBroadcast();

        console.log("\n========== Upgrade Summary ==========");
        console.log("MARKET_PROXY:", marketProxy);
        console.log("NEW_IMPL:", address(marketV2Impl));
        console.log("VERSION:", NFTMarketV2(marketProxy).version());
        console.log("=====================================\n");
    }
}
