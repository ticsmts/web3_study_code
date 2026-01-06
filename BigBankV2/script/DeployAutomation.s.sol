// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {BigBankV2Automation} from "../src/BigBankV2Automation.sol";

contract DeployAutomationScript is Script {
    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envOr(
            "PRIVATE_KEY",
            uint256(
                0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
            )
        );

        // BigBankV2 合约地址（从环境变量获取或使用已部署的地址）
        address bankAddress = vm.envOr(
            "BANK_ADDRESS",
            address(0xa805FD120EB3D78A17a6AAcFD920294C3B3959B8)
        );

        // 转账接收地址（默认为部署者地址）
        address recipient = vm.envOr(
            "RECIPIENT_ADDRESS",
            vm.addr(deployerPrivateKey)
        );

        // 触发阈值（默认 0.1 ETH）
        uint256 threshold = vm.envOr("THRESHOLD", uint256(0.1 ether));

        vm.startBroadcast(deployerPrivateKey);

        BigBankV2Automation automation = new BigBankV2Automation(
            bankAddress,
            recipient,
            threshold
        );

        console.log("BigBankV2Automation deployed at:", address(automation));
        console.log("Bank address:", bankAddress);
        console.log("Recipient:", recipient);
        console.log("Threshold:", threshold);

        vm.stopBroadcast();
    }
}
