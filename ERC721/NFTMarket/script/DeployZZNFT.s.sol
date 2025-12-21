// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std/Script.sol";
import "../src/ZZNFT.sol";

/*
forge script script/DeployZZNFT.s.sol:DeployZZNFT  --rpc-url sepolia -vvv 

forge script script/DeployZZNFT.s.sol:DeployZZNFT  --rpc-url sepolia -vvv --broadcast

forge verify-contract --watch --chain sepolia 0x92b758d4b5E356492E918a0F2E39eaeBdCE879B4 src/ZZNFT.sol:ZZNFT --verifier etherscan --etherscan-api-key $ETHERSCAN_API_KEY

//部署后合约地址： 0x92b758d4b5E356492E918a0F2E39eaeBdCE879B4

 */
contract DeployZZNFT is Script{
    function run() external returns (ZZNFT deployed){
        uint256 pk = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(pk);
        deployed = new ZZNFT("ZZNFT", "ZZNFT", "ipfs://QmZ4F9WkgKzLxmiVUdrpJrxhrnUBjwGz9eT4br91BqjTf1/");
        vm.stopBroadcast();
    }
}