// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "../src/NFTMarketV2.sol";
import "../src/ZZNFTUpgradeable.sol";
import "../src/ZZTokenUpgradeable.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract NFTMarketV2Test is Test {
    NFTMarketV2 market;
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
        ERC1967Proxy tokenProxy = new ERC1967Proxy(
            address(tokenImpl),
            tokenInitData
        );
        token = ZZTokenUpgradeable(address(tokenProxy));

        // 部署 NFT
        ZZNFTUpgradeable nftImpl = new ZZNFTUpgradeable();
        bytes memory nftInitData = abi.encodeWithSelector(
            ZZNFTUpgradeable.initialize.selector,
            "Test NFT",
            "TNFT",
            "https://example.com/"
        );
        ERC1967Proxy nftProxy = new ERC1967Proxy(address(nftImpl), nftInitData);
        nft = ZZNFTUpgradeable(address(nftProxy));

        // 部署 Market V2
        NFTMarketV2 marketImpl = new NFTMarketV2();
        bytes memory marketInitData = abi.encodeWithSelector(
            NFTMarketV1.initialize.selector
        );
        ERC1967Proxy marketProxy = new ERC1967Proxy(
            address(marketImpl),
            marketInitData
        );
        market = NFTMarketV2(address(marketProxy));

        // 给 seller 铸造 NFT
        nft.mint(seller);
        nft.mint(seller);
        nft.mint(seller);

        // 给 buyer 代币
        token.transfer(buyer, 10_000 ether);
    }

    // ============ Helper ============
    function _signListingPermit(
        uint256 privateKey,
        address nftContract,
        uint256 tokenId,
        address payToken,
        uint256 price,
        uint256 deadline,
        uint256 nonce
    ) internal view returns (uint8 v, bytes32 r, bytes32 s) {
        bytes32 structHash = keccak256(
            abi.encode(
                LISTING_PERMIT_TYPEHASH,
                nftContract,
                tokenId,
                payToken,
                price,
                deadline,
                nonce
            )
        );

        bytes32 domainSeparator = market.getDomainSeparator();
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", domainSeparator, structHash)
        );

        (v, r, s) = vm.sign(privateKey, digest);
    }

    // ============ Signature Listing Tests ============
    function test_ListWithSignature_Success() public {
        uint256 tokenId = 1;
        uint256 price = 100 ether;
        uint256 deadline = block.timestamp + 1 hours;
        uint256 nonce = market.getSellerNonce(seller);

        // Seller 授权给市场
        vm.prank(seller);
        nft.setApprovalForAll(address(market), true);

        // 生成签名
        (uint8 v, bytes32 r, bytes32 s) = _signListingPermit(
            sellerPrivateKey,
            address(nft),
            tokenId,
            address(token),
            price,
            deadline,
            nonce
        );

        // 提交签名上架
        vm.expectEmit(true, true, true, true);
        emit NFTMarketV2.ListedWithSignature(
            0,
            seller,
            address(nft),
            tokenId,
            address(token),
            price
        );

        uint256 listingId = market.listWithSignature(
            address(nft),
            tokenId,
            address(token),
            price,
            deadline,
            v,
            r,
            s
        );

        // 验证
        assertEq(listingId, 0);
        assertEq(nft.ownerOf(tokenId), seller); // NFT 仍在卖家手中
        assertTrue(market.isSignatureListing(listingId));
        assertEq(market.getSellerNonce(seller), 1);
    }

    function test_ListWithSignature_Fail_ExpiredDeadline() public {
        uint256 tokenId = 1;
        uint256 price = 100 ether;
        uint256 deadline = block.timestamp - 1; // 已过期
        uint256 nonce = market.getSellerNonce(seller);

        vm.prank(seller);
        nft.setApprovalForAll(address(market), true);

        (uint8 v, bytes32 r, bytes32 s) = _signListingPermit(
            sellerPrivateKey,
            address(nft),
            tokenId,
            address(token),
            price,
            deadline,
            nonce
        );

        vm.expectRevert(
            abi.encodeWithSelector(NFTMarketV2.ExpiredDeadline.selector)
        );
        market.listWithSignature(
            address(nft),
            tokenId,
            address(token),
            price,
            deadline,
            v,
            r,
            s
        );
    }

    function test_ListWithSignature_Fail_InvalidSignature() public {
        uint256 tokenId = 1;
        uint256 price = 100 ether;
        uint256 deadline = block.timestamp + 1 hours;
        uint256 nonce = market.getSellerNonce(seller);

        vm.prank(seller);
        nft.setApprovalForAll(address(market), true);

        // 使用错误的私钥签名
        uint256 wrongKey = 0xBAD;
        (uint8 v, bytes32 r, bytes32 s) = _signListingPermit(
            wrongKey,
            address(nft),
            tokenId,
            address(token),
            price,
            deadline,
            nonce
        );

        vm.expectRevert(
            abi.encodeWithSelector(NFTMarketV2.InvalidSignature.selector)
        );
        market.listWithSignature(
            address(nft),
            tokenId,
            address(token),
            price,
            deadline,
            v,
            r,
            s
        );
    }

    function test_ListWithSignature_Fail_NotApproved() public {
        uint256 tokenId = 1;
        uint256 price = 100 ether;
        uint256 deadline = block.timestamp + 1 hours;
        uint256 nonce = market.getSellerNonce(seller);

        // 不授权给市场
        (uint8 v, bytes32 r, bytes32 s) = _signListingPermit(
            sellerPrivateKey,
            address(nft),
            tokenId,
            address(token),
            price,
            deadline,
            nonce
        );

        vm.expectRevert(
            abi.encodeWithSelector(NFTMarketV2.NotApprovedForAll.selector)
        );
        market.listWithSignature(
            address(nft),
            tokenId,
            address(token),
            price,
            deadline,
            v,
            r,
            s
        );
    }

    // ============ Buy Signature Listing Tests ============
    function test_BuySignatureListing_Success() public {
        uint256 tokenId = 1;
        uint256 price = 100 ether;
        uint256 deadline = block.timestamp + 1 hours;
        uint256 nonce = market.getSellerNonce(seller);

        vm.prank(seller);
        nft.setApprovalForAll(address(market), true);

        (uint8 v, bytes32 r, bytes32 s) = _signListingPermit(
            sellerPrivateKey,
            address(nft),
            tokenId,
            address(token),
            price,
            deadline,
            nonce
        );

        uint256 listingId = market.listWithSignature(
            address(nft),
            tokenId,
            address(token),
            price,
            deadline,
            v,
            r,
            s
        );

        // 买家购买
        vm.startPrank(buyer);
        token.approve(address(market), price);
        market.buyNFT(listingId, price);
        vm.stopPrank();

        // 验证
        assertEq(nft.ownerOf(tokenId), buyer);
        assertEq(token.balanceOf(seller), price);
    }

    // ============ Multiple Listings with Single Approval ============
    function test_MultipleListingsWithSingleApproval() public {
        // 授权一次
        vm.prank(seller);
        nft.setApprovalForAll(address(market), true);

        // 上架多个 NFT
        for (uint256 i = 1; i <= 3; i++) {
            uint256 price = i * 100 ether;
            uint256 deadline = block.timestamp + 1 hours;
            uint256 nonce = market.getSellerNonce(seller);

            (uint8 v, bytes32 r, bytes32 s) = _signListingPermit(
                sellerPrivateKey,
                address(nft),
                i,
                address(token),
                price,
                deadline,
                nonce
            );

            uint256 listingId = market.listWithSignature(
                address(nft),
                i,
                address(token),
                price,
                deadline,
                v,
                r,
                s
            );

            assertEq(listingId, i - 1);
            assertEq(market.getSellerNonce(seller), i);
        }
    }

    // ============ Replay Attack Prevention ============
    function test_ListWithSignature_Fail_ReplayAttack() public {
        uint256 tokenId = 1;
        uint256 price = 100 ether;
        uint256 deadline = block.timestamp + 1 hours;
        uint256 nonce = market.getSellerNonce(seller);

        vm.prank(seller);
        nft.setApprovalForAll(address(market), true);

        (uint8 v, bytes32 r, bytes32 s) = _signListingPermit(
            sellerPrivateKey,
            address(nft),
            tokenId,
            address(token),
            price,
            deadline,
            nonce
        );

        // 第一次成功
        market.listWithSignature(
            address(nft),
            tokenId,
            address(token),
            price,
            deadline,
            v,
            r,
            s
        );

        // 重放失败（nonce 已增加）
        vm.expectRevert(
            abi.encodeWithSelector(NFTMarketV2.InvalidSignature.selector)
        );
        market.listWithSignature(
            address(nft),
            tokenId,
            address(token),
            price,
            deadline,
            v,
            r,
            s
        );
    }

    // ============ Version Test ============
    function test_Version() public view {
        assertEq(market.version(), "2.0.0");
    }
}
