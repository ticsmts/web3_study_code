// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Script.sol";
import "../src/ZZNFTMarketV3.sol";
import "../src/ZZNFT.sol";
import "../src/ZZToken.sol";

/**
 * @title DeployScript
 * @dev 部署 ZZNFTMarketV3 项目合约
 *
 * 使用方式:
 * forge script script/Deploy.s.sol --rpc-url http://127.0.0.1:8545 --broadcast
 */
contract DeployScript is Script {
    function run() external {
        // 使用Anvil的第一个默认私钥
        uint256 deployerPrivateKey = vm.envOr(
            "PRIVATE_KEY",
            uint256(
                0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
            )
        );
        address deployer = vm.addr(deployerPrivateKey);

        console.log("Deployer address:", deployer);
        console.log("Deployer balance:", deployer.balance);

        vm.startBroadcast(deployerPrivateKey);

        // 1. 部署 ZZToken
        ZZTOKEN token = new ZZTOKEN();
        console.log("ZZTOKEN deployed at:", address(token));

        // 2. 部署 ZZNFT
        ZZNFT nft = new ZZNFT(
            "ZZ NFT Collection",
            "ZZNFT",
            "https://api.example.com/nft/"
        );
        console.log("ZZNFT deployed at:", address(nft));

        // 3. 部署 ZZNFTMarketV3 (deployer 作为 signer)
        ZZNFTMarketV3 market = new ZZNFTMarketV3(deployer);
        console.log("ZZNFTMarketV3 deployed at:", address(market));
        console.log("Signer (project owner):", deployer);

        // 4. 铸造一些测试 NFT
        nft.mint(deployer, 1);
        nft.mint(deployer, 2);
        nft.mint(deployer, 3);
        console.log("Minted NFT tokenIds: 1, 2, 3 to", deployer);

        // 5. 给第二个账户转一些代币（用于测试购买）
        address buyer = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8; // Anvil account #1
        token.transfer(buyer, 10000 ether);
        console.log("Transferred 10000 ZZ tokens to buyer:", buyer);

        vm.stopBroadcast();

        // 输出合约地址供前端使用
        console.log("\n========== Deployment Summary ==========");
        console.log("TOKEN_ADDRESS:", address(token));
        console.log("NFT_ADDRESS:", address(nft));
        console.log("MARKET_ADDRESS:", address(market));
        console.log("=========================================\n");
    }
}
