// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "forge-std/Script.sol";
import "../src/OpenZeppelinERC20.sol";

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
forge script script/DeployOpenZeppelinERC20.s.sol:DeployOpenZeppelinERC20  --rpc-url sepolia -vvv 

forge script script/DeployOpenZeppelinERC20.s.sol:DeployOpenZeppelinERC20  -vvv --rpc-url sepolia --broadcast

部署验证：
forge script script/DeployOpenZeppelinERC20.s.sol:DeployOpenZeppelinERC20 --broadcast --verify --etherscan-api-key $ETHERSCAN_API_KEY -vvv

  

================================

合约开源验证：
cast abi-encode "constructor(string,string)" "OpenZeppelinERC20" "OZE"
//输出：0x0000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000114f70656e5a657070656c696e455243323000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000034f5a450000000000000000000000000000000000000000000000000000000000

forge verify-contract  0x60cbc463da83627419f7c244fd16f8f85b8c57d8  src/OpenZeppelinERC20.sol:OpenZeppelinERC20  --chain sepolia --compiler-version v0.8.25  --constructor-args 0x0000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000114f70656e5a657070656c696e455243323000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000034f5a450000000000000000000000000000000000000000000000000000000000  --etherscan-api-key xxx
forge verify-check lal9emkyymjkua99uavdx5qr761yvxq91sifmk4dmpcdgvngm8

*/

contract DeployOpenZeppelinERC20 is Script{
    function run() external returns (OpenZeppelinERC20 deployed){
        uint256 pk = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(pk);
        deployed = new OpenZeppelinERC20("OpenZeppelinERC20", "OZE");
        vm.stopBroadcast();
    }
}