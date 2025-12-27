// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {ZZTokenV2} from "../src/ZZTokenV2.sol";

/**
forge script script/DeployZZTokenV2.s.sol:DeployZZTokenV2 --rpc-url anvil  --broadcast

cast call 0x5FbDB2315678afecb367f032d93F642f64180aa3 "name()(string)" --rpc-url anvil

 */
contract DeployZZTokenV2 is Script {
    uint256 deployerPk = vm.envUint("PRIVATE_KEY");
    address deployer = vm.addr(deployerPk);
    function run() external {
        string memory name_ = vm.envOr("ZZ_NAME", string("ZZToken"));
        string memory symbol_ = vm.envOr("ZZ_SYMBOL", string("ZZ"));
        address initialOwner_ = vm.envOr("ZZ_OWNER", deployer);
        address initialReceiver_ = vm.envOr("ZZ_RECEIVER", msg.sender);

        uint256 initialSupply_ = vm.envOr("ZZ_INITIAL_SUPPLY", uint256(2100_000_000 ether));

        uint256 deployerPk = vm.envUint("PRIVATE_KEY");
        console2.log("deployer from PRIVATE_KEY:", deployer);

        vm.startBroadcast(deployerPk);

        ZZTokenV2 token = new ZZTokenV2(
            name_,
            symbol_,
            initialOwner_,
            initialReceiver_,
            initialSupply_
        );

        vm.stopBroadcast();

        console2.log("ZZTokenV2 deployed at:", address(token));
        console2.log("name:", token.name());
        console2.log("symbol:", token.symbol());
        console2.log("owner:", token.owner());
        console2.log("receiver balance:", token.balanceOf(initialReceiver_));
        console2.log("DOMAIN_SEPARATOR:", uint256(token.DOMAIN_SEPARATOR()));
    }
}
