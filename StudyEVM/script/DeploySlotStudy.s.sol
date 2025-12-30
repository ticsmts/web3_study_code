// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/SlotStudy.sol";

contract DeploySlotStudy is Script {
    function run() external returns (esRNT) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        esRNT slotStudy = new esRNT();

        vm.stopBroadcast();

        console.log("esRNT (SlotStudy) deployed at:", address(slotStudy));

        return slotStudy;
    }
}
