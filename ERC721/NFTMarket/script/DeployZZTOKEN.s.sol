// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std/Script.sol";
import "../src/ZZTOKEN.sol";

/*
forge script script/DeployZZTOKEN.s.sol:DeployZZTOKEN  --rpc-url sepolia -vvv 

forge script script/DeployZZTOKEN.s.sol:DeployZZTOKEN  --rpc-url sepolia -vvv --broadcast

forge verify-contract --watch --chain sepolia 0x5C4829789Cb5d86b15034D7E8C8ddDcb45890Cff src/ZZTOKEN.sol:ZZTOKEN --verifier etherscan --etherscan-api-key $ETHERSCAN_API_KEY

//部署后合约地址： 0x5C4829789Cb5d86b15034D7E8C8ddDcb45890Cff

 */
contract DeployZZTOKEN is Script{
    function run() external returns (ZZTOKEN deployed){
        uint256 pk = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(pk);
        deployed = new ZZTOKEN();
        vm.stopBroadcast();
    }
}