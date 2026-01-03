// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Script.sol";
import "../src/NFTMarketV1.sol";
import "../src/ZZNFTUpgradeable.sol";
import "../src/ZZTokenUpgradeable.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title DeployV1
 * @dev 部署 NFT 市场 V1 及相关合约
 *
 * 使用方式:
 * forge script script/DeployV1.s.sol --rpc-url http://127.0.0.1:8545 --broadcast
 */
contract DeployV1 is Script {
    function run() external {
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

        // 1. 部署 ZZToken 实现合约
        ZZTokenUpgradeable tokenImpl = new ZZTokenUpgradeable();
        console.log("ZZToken Implementation:", address(tokenImpl));

        // 2. 部署 ZZToken 代理合约
        bytes memory tokenInitData = abi.encodeWithSelector(
            ZZTokenUpgradeable.initialize.selector,
            "ZZ Token",
            "ZZT",
            100_000_000 ether
        );
        ERC1967Proxy tokenProxy = new ERC1967Proxy(
            address(tokenImpl),
            tokenInitData
        );
        console.log("ZZToken Proxy:", address(tokenProxy));

        // 3. 部署 ZZNFT 实现合约
        ZZNFTUpgradeable nftImpl = new ZZNFTUpgradeable();
        console.log("ZZNFT Implementation:", address(nftImpl));

        // 4. 部署 ZZNFT 代理合约
        bytes memory nftInitData = abi.encodeWithSelector(
            ZZNFTUpgradeable.initialize.selector,
            "ZZ NFT Collection",
            "ZZNFT",
            "https://api.example.com/nft/"
        );
        ERC1967Proxy nftProxy = new ERC1967Proxy(address(nftImpl), nftInitData);
        console.log("ZZNFT Proxy:", address(nftProxy));

        // 5. 部署 NFTMarketV1 实现合约
        NFTMarketV1 marketImpl = new NFTMarketV1();
        console.log("NFTMarketV1 Implementation:", address(marketImpl));

        // 6. 部署 NFTMarketV1 代理合约
        bytes memory marketInitData = abi.encodeWithSelector(
            NFTMarketV1.initialize.selector
        );
        ERC1967Proxy marketProxy = new ERC1967Proxy(
            address(marketImpl),
            marketInitData
        );
        console.log("NFTMarket Proxy:", address(marketProxy));

        // 7. 铸造测试 NFT
        ZZNFTUpgradeable nft = ZZNFTUpgradeable(address(nftProxy));
        nft.mint(deployer);
        nft.mint(deployer);
        nft.mint(deployer);
        console.log("Minted 3 NFTs to deployer");

        // 8. 给测试账户分配代币
        address buyer = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
        ZZTokenUpgradeable token = ZZTokenUpgradeable(address(tokenProxy));
        token.transfer(buyer, 10_000 ether);
        console.log("Transferred 10000 ZZT to buyer:", buyer);

        vm.stopBroadcast();

        // 输出合约地址
        console.log("\n========== Deployment Summary ==========");
        console.log("TOKEN_IMPL:", address(tokenImpl));
        console.log("TOKEN_PROXY:", address(tokenProxy));
        console.log("NFT_IMPL:", address(nftImpl));
        console.log("NFT_PROXY:", address(nftProxy));
        console.log("MARKET_IMPL:", address(marketImpl));
        console.log("MARKET_PROXY:", address(marketProxy));
        console.log("=========================================\n");
    }
}
