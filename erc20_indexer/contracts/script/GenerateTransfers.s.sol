// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {ZZTOKEN} from "../src/ZZTOKEN.sol";

contract GenerateTransfersScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address tokenAddress = vm.envAddress("TOKEN_ADDRESS");

        ZZTOKEN token = ZZTOKEN(tokenAddress);

        vm.startBroadcast(deployerPrivateKey);

        console.log("Starting to generate 100 transfer transactions...");
        console.log("Token address:", tokenAddress);
        console.log("Deployer balance:", token.balanceOf(msg.sender));

        // 生成100条转账交易到不同地址
        for (uint256 i = 1; i <= 100; i++) {
            // 生成确定性的接收地址
            address recipient = address(
                uint160(uint256(keccak256(abi.encodePacked("recipient", i))))
            );
            // 每次转账金额为 i * 1e18 (i个token)
            uint256 amount = i * 1e18;

            token.transfer(recipient, amount);

            if (i % 20 == 0) {
                console.log("Generated", i, "transfers");
            }
        }

        console.log("Successfully generated 100 transfers");
        console.log("Remaining deployer balance:", token.balanceOf(msg.sender));

        vm.stopBroadcast();
    }
}
