// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Script.sol";
import "../src/ZZToken.sol";
import "../src/ZZNFT.sol";
import "../src/AirdropMerkleNFTMarket.sol";

/**
 * @title Deploy Script
 * @dev 部署 AirdropMerkleNFTMarket 相关合约
 *
 * 使用方法:
 * 1. 启动 Anvil: anvil
 * 2. 部署: forge script script/Deploy.s.sol --rpc-url http://127.0.0.1:8545 --broadcast
 */
contract DeployScript is Script {
    function run() external {
        // 使用 Anvil 默认账户
        uint256 deployerPrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        address deployer = vm.addr(deployerPrivateKey);

        console.log("Deployer:", deployer);

        vm.startBroadcast(deployerPrivateKey);

        // 1. 部署 Token
        ZZTOKEN token = new ZZTOKEN();
        console.log("Token deployed at:", address(token));

        // 2. 部署 NFT
        ZZNFT nft = new ZZNFT("ZZNFT", "ZZNFT", "https://example.com/nft/");
        console.log("NFT deployed at:", address(nft));

        // 3. 计算 Merkle Root (单地址白名单: deployer)
        // 对于单地址白名单，root = keccak256(abi.encodePacked(address))
        bytes32 merkleRoot = keccak256(abi.encodePacked(deployer));
        console.log("Merkle Root (deployer only):");
        console.logBytes32(merkleRoot);

        // 4. 部署 Market
        AirdropMerkleNFTMarket market = new AirdropMerkleNFTMarket(merkleRoot);
        console.log("Market deployed at:", address(market));

        // 5. 铸造一些 NFT 给 deployer 用于测试
        nft.mintTo(deployer, 0);
        nft.mintTo(deployer, 1);
        nft.mintTo(deployer, 2);
        console.log("Minted 3 NFTs to deployer");

        vm.stopBroadcast();

        // 打印合约地址用于前端配置
        console.log("");
        console.log("=== Frontend Config ===");
        console.log("Update frontend/config/contracts.ts with:");
        console.log("TOKEN_ADDRESS:", address(token));
        console.log("NFT_ADDRESS:", address(nft));
        console.log("MARKET_ADDRESS:", address(market));
    }
}
