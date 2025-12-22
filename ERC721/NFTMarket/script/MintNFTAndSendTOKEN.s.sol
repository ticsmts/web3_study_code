pragma solidity ^0.8.30;
import "forge-std/Script.sol";
import "../src/ZZNFTMarketV2.sol";
import "../src/ZZNFT.sol";
import "../src/ZZTOKEN.sol";

contract RunOnSepolia is Script {

    //address seller = address(0xD0C0e860BDB02F7dEC247CaA225e6BC83877dFC5);
    //address buyer = address(0x1261Fe1553426e5abbFb2676d406Da45538b6097);


    function run() external {
        uint256 pk1 = vm.envUint("PRIVATE_KEY");    // mint NFT 的人（需要有 mint 权限）
        uint256 pkBuyer = vm.envUint("PRIVATE_KEY_2");  // 买家
        uint256 pkSeller = vm.envUint("PRIVATE_KEY_3"); // 卖家（NFT owner）

        address addr1 = vm.addr(pk1);
        address buyer = vm.addr(pkBuyer);
        address seller = vm.addr(pkSeller);

        console2.log("pk1 address   =", addr1);
        console2.log("seller address=", seller);
        console2.log("buyer address =", buyer);


        
        // 获取合约地址
        ZZNFTMarketV2 market = ZZNFTMarketV2(0x67ac7d5b683bAfAF357d79084F89C44bC8743228);
        ZZNFT nft = ZZNFT(0x92b758d4b5E356492E918a0F2E39eaeBdCE879B4);
        ZZTOKEN token = ZZTOKEN(0x5C4829789Cb5d86b15034D7E8C8ddDcb45890Cff);
        
        uint256 tokenId;
        uint256 price = 1000 ether; 
    
        for(uint256 i = 10; i < 15; i++){
            
            tokenId = i;
            //铸造nft
            vm.startBroadcast(pk1);
            nft.mint(seller, tokenId);
            vm.stopBroadcast();

        }
        
        //给A地址转代币
        vm.startBroadcast(pk1);
        token.transfer(buyer, 50000 ether);
        vm.stopBroadcast();
    }


}
