// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std/Script.sol";
import "../src/ZZNFTMarketV2.sol";

/*
初始化：
forge init
1. 在.env中配置SEPOLIA_RPC_URL=wss://ethereum-sepolia-rpc.publicnode.com 
2. foundry.toml 配置
[rpc_endpoints]
sepolia = "${SEPOLIA_RPC_URL}"

[etherscan]
sepolia = { key = "${ETHERSCAN_API_KEY}" }

编译：
forge build


部署：
forge script script/DeployZZNFTMarketV2.s.sol:DeployZZNFTMarketV2  --rpc-url sepolia -vvv 

forge script script/DeployZZNFTMarketV2.s.sol:DeployZZNFTMarketV2  -vvv --rpc-url sepolia --broadcast

部署验证：
forge script script/DeployOpenZeppelinERC20.s.sol:DeployOpenZeppelinERC20 --broadcast --verify --etherscan-api-key $ETHERSCAN_API_KEY -vvv


================================

# foundry直接开源验证, 根据Deploy脚本带参数: 
forge verify-contract --watch --chain sepolia 0x67ac7d5b683bAfAF357d79084F89C44bC8743228 src/ZZNFTMarketV2.sol:ZZNFTMarketV2 --verifier etherscan --etherscan-api-key $ETHERSCAN_API_KEY

//部署后合约地址:  0x67ac7d5b683bAfAF357d79084F89C44bC8743228

*/

contract DeployZZNFTMarketV2 is Script{
    function run() external returns (ZZNFTMarketV2 deployed){
        uint256 pk = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(pk);
        deployed = new ZZNFTMarketV2();
        vm.stopBroadcast();
    }
}

