// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Script.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../src/InscriptionFactoryV1.sol";

/**
 * @title DeployFactoryV1
 * @dev 部署脚本：InscriptionFactoryV1 到 Sepolia 测试网
 *
 * 使用方法：
 * forge script script/DeployFactoryV1.s.sol:DeployFactoryV1 \
 *     --rpc-url sepolia \
 *     --broadcast \
 *     --verify
 */
contract DeployFactoryV1 is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("Deployer address:", deployer);
        console.log("Deployer balance:", deployer.balance);

        vm.startBroadcast(deployerPrivateKey);

        // 1. 部署实现合约
        InscriptionFactoryV1 factoryImpl = new InscriptionFactoryV1();
        console.log("Implementation deployed at:", address(factoryImpl));

        // 2. 准备初始化数据
        bytes memory initData = abi.encodeWithSelector(
            InscriptionFactoryV1.initialize.selector,
            deployer // owner
        );

        // 3. 部署代理合约
        ERC1967Proxy proxy = new ERC1967Proxy(address(factoryImpl), initData);
        console.log("Proxy deployed at:", address(proxy));

        // 4. 验证部署
        InscriptionFactoryV1 factory = InscriptionFactoryV1(address(proxy));
        console.log("Factory owner:", factory.owner());
        console.log("Factory version:", factory.version());

        vm.stopBroadcast();

        console.log("");
        console.log("=== Deployment Summary ===");
        console.log("Implementation:", address(factoryImpl));
        console.log("Proxy (use this):", address(proxy));
    }
}
