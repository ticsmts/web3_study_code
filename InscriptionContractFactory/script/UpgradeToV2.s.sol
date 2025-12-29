// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Script.sol";
import "../src/InscriptionFactoryV1.sol";
import "../src/InscriptionFactoryV2.sol";
import "../src/InscriptionTokenV2.sol";

/**
 * @title UpgradeToV2
 * @dev 升级脚本：将代理从 V1 升级到 V2
 *
 * 使用方法：
 * forge script script/UpgradeToV2.s.sol:UpgradeToV2 \
 *     --rpc-url sepolia \
 *     --broadcast \
 *     --verify
 */
contract UpgradeToV2 is Script {
    // 已部署的代理地址 (EIP-55 checksum)
    address payable constant PROXY_ADDRESS =
        payable(0x50180de3322F3309Db32f19D5537C3698EEE9078);

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("Deployer address:", deployer);
        console.log("Proxy address:", PROXY_ADDRESS);

        vm.startBroadcast(deployerPrivateKey);

        // 1. 部署 InscriptionTokenV2 实现 (用于 Clone)
        InscriptionTokenV2 tokenV2Impl = new InscriptionTokenV2();
        console.log(
            "TokenV2 Implementation deployed at:",
            address(tokenV2Impl)
        );

        // 2. 部署 InscriptionFactoryV2 实现
        InscriptionFactoryV2 factoryV2Impl = new InscriptionFactoryV2();
        console.log(
            "FactoryV2 Implementation deployed at:",
            address(factoryV2Impl)
        );

        // 3. 升级代理到 V2
        InscriptionFactoryV1 proxyAsV1 = InscriptionFactoryV1(PROXY_ADDRESS);
        proxyAsV1.upgradeToAndCall(address(factoryV2Impl), "");
        console.log("Proxy upgraded to V2");

        // 4. 初始化 V2 (设置 tokenImplementation)
        InscriptionFactoryV2 proxyAsV2 = InscriptionFactoryV2(PROXY_ADDRESS);
        proxyAsV2.initializeV2(address(tokenV2Impl));
        console.log("V2 initialized with token implementation");

        // 5. 验证升级
        console.log("Factory version:", proxyAsV2.version());
        console.log("Token implementation:", proxyAsV2.tokenImplementation());

        vm.stopBroadcast();

        console.log("");
        console.log("=== Upgrade Summary ===");
        console.log("Proxy (unchanged):", PROXY_ADDRESS);
        console.log("V2 Implementation:", address(factoryV2Impl));
        console.log("TokenV2 Implementation:", address(tokenV2Impl));
    }
}
