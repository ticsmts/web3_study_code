// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "../src/NFTMarketV1.sol";
import "../src/ZZNFTUpgradeable.sol";
import "../src/ZZTokenUpgradeable.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract NFTMarketV1Test is Test {
    NFTMarketV1 market;
    ZZNFTUpgradeable nft;
    ZZTokenUpgradeable token;

    address deployer = address(this);
    address seller = address(0xDEAD);
    address buyer = address(0xBEEF);

    function setUp() public {
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

        // 部署 Market
        NFTMarketV1 marketImpl = new NFTMarketV1();
        bytes memory marketInitData = abi.encodeWithSelector(
            NFTMarketV1.initialize.selector
        );
        ERC1967Proxy marketProxy = new ERC1967Proxy(
            address(marketImpl),
            marketInitData
        );
        market = NFTMarketV1(address(marketProxy));

        // 给 seller 铸造 NFT
        nft.mint(seller);
        nft.mint(seller);

        // 给 buyer 代币
        token.transfer(buyer, 10_000 ether);
    }

    // ============ Helper ============
    function _list(uint256 tokenId, uint256 price) internal returns (uint256) {
        vm.startPrank(seller);
        nft.approve(address(market), tokenId);
        uint256 listingId = market.list(
            address(nft),
            tokenId,
            address(token),
            price
        );
        vm.stopPrank();
        return listingId;
    }

    // ============ List Tests ============
    function test_List_Success() public {
        uint256 price = 100 ether;

        vm.startPrank(seller);
        nft.approve(address(market), 1);

        vm.expectEmit(true, true, true, true);
        emit NFTMarketV1.Listed(
            0,
            seller,
            address(nft),
            1,
            address(token),
            price
        );

        uint256 listingId = market.list(address(nft), 1, address(token), price);
        vm.stopPrank();

        assertEq(listingId, 0);
        assertEq(nft.ownerOf(1), address(market)); // NFT 托管到合约

        NFTMarketV1.Listing memory L = market.getListing(listingId);
        assertEq(L.seller, seller);
        assertTrue(L.active);
        assertEq(L.price, price);
    }

    function test_List_Fail_ZeroPrice() public {
        vm.startPrank(seller);
        nft.approve(address(market), 1);

        vm.expectRevert(
            abi.encodeWithSelector(NFTMarketV1.InvalidPrice.selector)
        );
        market.list(address(nft), 1, address(token), 0);
        vm.stopPrank();
    }

    function test_List_Fail_NotOwner() public {
        vm.prank(buyer);
        vm.expectRevert(abi.encodeWithSelector(NFTMarketV1.NotOwner.selector));
        market.list(address(nft), 1, address(token), 100 ether);
    }

    // ============ Buy Tests ============
    function test_BuyNFT_Success() public {
        uint256 price = 200 ether;
        uint256 listingId = _list(1, price);

        vm.startPrank(buyer);
        token.approve(address(market), price);

        vm.expectEmit(true, true, true, true);
        emit NFTMarketV1.Bought(
            listingId,
            buyer,
            seller,
            address(nft),
            1,
            address(token),
            price
        );

        market.buyNFT(listingId, price);
        vm.stopPrank();

        assertEq(nft.ownerOf(1), buyer);
        assertEq(token.balanceOf(seller), price);
    }

    function test_BuyNFT_Fail_BuySelf() public {
        uint256 price = 200 ether;
        uint256 listingId = _list(1, price);

        vm.startPrank(seller);
        token.approve(address(market), price);

        vm.expectRevert(abi.encodeWithSelector(NFTMarketV1.BuySelf.selector));
        market.buyNFT(listingId, price);
        vm.stopPrank();
    }

    function test_BuyNFT_Fail_WrongPayment() public {
        uint256 price = 200 ether;
        uint256 listingId = _list(1, price);

        vm.startPrank(buyer);
        token.approve(address(market), price);

        vm.expectRevert(
            abi.encodeWithSelector(NFTMarketV1.WrongPayment.selector)
        );
        market.buyNFT(listingId, 100 ether);
        vm.stopPrank();
    }

    // ============ Cancel Tests ============
    function test_CancelListing_Success() public {
        uint256 price = 200 ether;
        uint256 listingId = _list(1, price);

        vm.prank(seller);
        vm.expectEmit(true, true, false, false);
        emit NFTMarketV1.Cancelled(listingId, seller);
        market.cancelListing(listingId);

        assertEq(nft.ownerOf(1), seller); // NFT 返还卖家
        assertFalse(market.getListing(listingId).active);
    }

    function test_CancelListing_Fail_NotOwner() public {
        uint256 listingId = _list(1, 200 ether);

        vm.prank(buyer);
        vm.expectRevert(abi.encodeWithSelector(NFTMarketV1.NotOwner.selector));
        market.cancelListing(listingId);
    }

    // ============ Version Test ============
    function test_Version() public view {
        assertEq(market.version(), "1.0.0");
    }
}
