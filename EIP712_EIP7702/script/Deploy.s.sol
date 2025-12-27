// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/ZZTokenV2.sol";
import "../src/TokenBankV3.sol";

contract DeployScript is Script {
    function run() external {
        // 从环境变量获取私钥，或使用 Anvil 默认账户
        uint256 deployerPrivateKey = vm.envOr(
            "PRIVATE_KEY",
            uint256(
                0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
            )
        );

        vm.startBroadcast(deployerPrivateKey);

        address deployer = vm.addr(deployerPrivateKey);

        // 1. 部署 ZZTokenV2
        ZZTokenV2 token = new ZZTokenV2(
            "ZZ Token V2",
            "ZZ",
            deployer, // initialOwner
            deployer, // initialReceiver
            21000000 * 10 ** 18 // initialSupply: 21,000,000 tokens
        );

        console.log("ZZTokenV2 deployed at:", address(token));
        console.log("Initial supply:", token.totalSupply() / 10 ** 18, "ZZ");

        // 2. 部署 TokenBankV3
        TokenBankV3 bank = new TokenBankV3(address(token));

        console.log("TokenBankV3 deployed at:", address(bank));
        console.log("Bank token address:", address(bank.token()));

        // 3. 为测试账户分配一些代币 (Anvil 账户 #1)
        address testAccount = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
        if (testAccount != deployer) {
            token.transfer(testAccount, 100000 * 10 ** 18);
            console.log("Transferred 100,000 ZZ to test account:", testAccount);
        }

        vm.stopBroadcast();

        // 输出部署信息
        console.log("\n=== Deployment Summary ===");
        console.log("Network: Local Anvil");
        console.log("Deployer:", deployer);
        console.log("ZZTokenV2:", address(token));
        console.log("TokenBankV3:", address(bank));
        console.log("\nSave these addresses for frontend configuration!");
    }
}
