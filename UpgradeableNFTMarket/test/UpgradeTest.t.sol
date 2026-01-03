// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "../src/NFTMarketV1.sol";
import "../src/NFTMarketV2.sol";
import "../src/ZZNFTUpgradeable.sol";
import "../src/ZZTokenUpgradeable.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title UpgradeTest
 * @dev 测试从 V1 升级到 V2 的完整流程
 */
contract UpgradeTest is Test {
    ERC1967Proxy marketProxy;
    ZZNFTUpgradeable nft;
    ZZTokenUpgradeable token;

    address deployer = address(this);

    uint256 sellerPrivateKey = 0xA11CE;
    address seller;

    address buyer = address(0xBEEF);

    bytes32 constant LISTING_PERMIT_TYPEHASH =
        keccak256(
            "ListingPermit(address nftContract,uint256 tokenId,address payToken,uint256 price,uint256 deadline,uint256 nonce)"
        );

    function setUp() public {
        seller = vm.addr(sellerPrivateKey);

        // 部署 Token
        ZZTokenUpgradeable tokenImpl = new ZZTokenUpgradeable();
        bytes memory tokenInitData = abi.encodeWithSelector(
            ZZTokenUpgradeable.initialize.selector,
            "ZZ Token",
            "ZZT",
            100_000_000 ether
        );
        ERC1967Proxy tokenProxyContract = new ERC1967Proxy(
            address(tokenImpl),
            tokenInitData
        );
        token = ZZTokenUpgradeable(address(tokenProxyContract));

        // 部署 NFT
        ZZNFTUpgradeable nftImpl = new ZZNFTUpgradeable();
        bytes memory nftInitData = abi.encodeWithSelector(
            ZZNFTUpgradeable.initialize.selector,
            "Test NFT",
            "TNFT",
            "https://example.com/"
        );
        ERC1967Proxy nftProxyContract = new ERC1967Proxy(
            address(nftImpl),
            nftInitData
        );
        nft = ZZNFTUpgradeable(address(nftProxyContract));

        // 部署 Market V1 代理
        NFTMarketV1 marketImpl = new NFTMarketV1();
        bytes memory marketInitData = abi.encodeWithSelector(
            NFTMarketV1.initialize.selector
        );
        marketProxy = new ERC1967Proxy(address(marketImpl), marketInitData);

        // 给 seller 铸造 NFT
        nft.mint(seller);
        nft.mint(seller);

        // 给 buyer 代币
        token.transfer(buyer, 10_000 ether);
    }

    // ============ Upgrade Tests ============

    /**
     * @dev 测试升级保持状态
     */
    function test_Upgrade_PreservesState() public {
        NFTMarketV1 marketV1 = NFTMarketV1(address(marketProxy));

        // 在 V1 中创建上架
        vm.startPrank(seller);
        nft.approve(address(marketV1), 1);
        uint256 listingId = marketV1.list(
            address(nft),
            1,
            address(token),
            100 ether
        );
        vm.stopPrank();

        // 验证 V1 状态
        assertEq(marketV1.version(), "1.0.0");
        assertEq(marketV1.nextListingId(), 1);

        NFTMarketV1.Listing memory listingBefore = marketV1.getListing(
            listingId
        );
        assertEq(listingBefore.seller, seller);
        assertTrue(listingBefore.active);
        assertEq(listingBefore.price, 100 ether);

        // 升级到 V2
        NFTMarketV2 marketV2Impl = new NFTMarketV2();
        NFTMarketV1(address(marketProxy)).upgradeToAndCall(
            address(marketV2Impl),
            ""
        );

        NFTMarketV2 marketV2 = NFTMarketV2(address(marketProxy));

        // 验证升级后状态保持
        assertEq(marketV2.version(), "2.0.0");
        assertEq(marketV2.nextListingId(), 1);

        NFTMarketV1.Listing memory listingAfter = marketV2.getListing(
            listingId
        );
        assertEq(listingAfter.seller, listingBefore.seller);
        assertEq(listingAfter.active, listingBefore.active);
        assertEq(listingAfter.price, listingBefore.price);
    }

    /**
     * @dev 测试升级后 V1 上架仍可购买
     */
    function test_Upgrade_V1ListingStillWorks() public {
        NFTMarketV1 marketV1 = NFTMarketV1(address(marketProxy));

        // 在 V1 中创建上架
        vm.startPrank(seller);
        nft.approve(address(marketV1), 1);
        uint256 listingId = marketV1.list(
            address(nft),
            1,
            address(token),
            100 ether
        );
        vm.stopPrank();

        // 升级到 V2
        NFTMarketV2 marketV2Impl = new NFTMarketV2();
        NFTMarketV1(address(marketProxy)).upgradeToAndCall(
            address(marketV2Impl),
            ""
        );

        NFTMarketV2 marketV2 = NFTMarketV2(address(marketProxy));

        // V1 的上架在 V2 中仍可购买
        vm.startPrank(buyer);
        token.approve(address(marketV2), 100 ether);
        marketV2.buyNFT(listingId, 100 ether);
        vm.stopPrank();

        assertEq(nft.ownerOf(1), buyer);
        assertEq(token.balanceOf(seller), 100 ether);
    }

    /**
     * @dev 测试升级后 V2 新功能可用
     */
    function test_Upgrade_NewFeatureWorks() public {
        // 升级到 V2
        NFTMarketV2 marketV2Impl = new NFTMarketV2();
        NFTMarketV1(address(marketProxy)).upgradeToAndCall(
            address(marketV2Impl),
            ""
        );

        NFTMarketV2 marketV2 = NFTMarketV2(address(marketProxy));

        // 使用 V2 签名上架功能
        uint256 tokenId = 1;
        uint256 price = 200 ether;
        uint256 deadline = block.timestamp + 1 hours;
        uint256 nonce = marketV2.getSellerNonce(seller);

        vm.prank(seller);
        nft.setApprovalForAll(address(marketV2), true);

        bytes32 structHash = keccak256(
            abi.encode(
                LISTING_PERMIT_TYPEHASH,
                address(nft),
                tokenId,
                address(token),
                price,
                deadline,
                nonce
            )
        );
        bytes32 domainSeparator = marketV2.getDomainSeparator();
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", domainSeparator, structHash)
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(sellerPrivateKey, digest);

        uint256 listingId = marketV2.listWithSignature(
            address(nft),
            tokenId,
            address(token),
            price,
            deadline,
            v,
            r,
            s
        );

        assertTrue(marketV2.isSignatureListing(listingId));
        assertEq(nft.ownerOf(tokenId), seller); // 签名上架不转移 NFT
    }

    /**
     * @dev 测试非 owner 无法升级
     */
    function test_Upgrade_OnlyOwner() public {
        NFTMarketV2 marketV2Impl = new NFTMarketV2();

        vm.prank(buyer);
        vm.expectRevert();
        NFTMarketV1(address(marketProxy)).upgradeToAndCall(
            address(marketV2Impl),
            ""
        );
    }
}
