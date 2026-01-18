// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Script.sol";
import "../src/ZZNFTMarketV3.sol";
import "../src/ZZNFT.sol";
import "../src/ZZToken.sol";

/**
 * @title DeploySepoliaScript
 * @dev Deploy ZZNFTMarketV3 project to Sepolia testnet
 *
 * Usage:
 * forge script script/DeploySepolia.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast --verify -vvvv
 */
contract DeploySepoliaScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("========== Deployment Info ==========");
        console.log("Deployer:", deployer);
        console.log("Network: Sepolia");
        console.log("Block Number:", block.number);

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy ZZToken
        ZZTOKEN token = new ZZTOKEN();
        console.log("ZZTOKEN deployed at:", address(token));

        // 2. Deploy ZZNFT
        ZZNFT nft = new ZZNFT(
            "ZZ NFT Collection",
            "ZZNFT",
            "https://api.example.com/nft/"
        );
        console.log("ZZNFT deployed at:", address(nft));

        // 3. Deploy ZZNFTMarketV3 (deployer as signer)
        ZZNFTMarketV3 market = new ZZNFTMarketV3(deployer);
        console.log("ZZNFTMarketV3 deployed at:", address(market));

        // 4. Mint test NFTs
        nft.mint(deployer, 1);
        nft.mint(deployer, 2);
        nft.mint(deployer, 3);
        console.log("Minted NFT tokenIds: 1, 2, 3");

        vm.stopBroadcast();

        console.log("\n========== Deployment Summary ==========");
        console.log("TOKEN_ADDRESS:", address(token));
        console.log("NFT_ADDRESS:", address(nft));
        console.log("MARKET_ADDRESS:", address(market));
        console.log("SIGNER:", deployer);
        console.log("========================================");
        console.log(
            "\nIMPORTANT: Record the block number from the deployment transaction for Subgraph startBlock!"
        );
    }
}
