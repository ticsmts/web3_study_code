// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {BigBankV2} from "../src/BigBankV2.sol";

contract DeployScript is Script {
    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envOr(
            "PRIVATE_KEY",
            uint256(
                0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
            )
        );

        vm.startBroadcast(deployerPrivateKey);

        BigBankV2 bank = new BigBankV2();

        console.log("BigBankV2 deployed at:", address(bank));
        console.log("Owner:", bank.owner());

        vm.stopBroadcast();
    }
}
