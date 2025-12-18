// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";

import "../src/ZZNFTMarket.sol";
import "../src/ZZTOKEN.sol";
import "../src/ZZNFT.sol";

contract ZZNFTMarketTest is Test {
    ZZTOKEN token;
    ZZNFT nft;
    ZZNFTMarket market;

    address seller = address(0xA11CE);
    address buyer  = address(0xB0B);

    uint256 tokenId1 = 1;
    uint256 tokenId2 = 2;

    function setUp() public {
        token = new ZZTOKEN();
        nft = new ZZNFT("ZZNFT", "ZZN", "ipfs://base/");
        market = new ZZNFTMarket(address(token));

        // mint NFTs to seller (mint can only be called by nft owner: deployer = this test contract)
        nft.mint(seller, tokenId1);
        nft.mint(seller, tokenId2);

        // fund buyer with some ZZTOKEN from deployer (this test contract holds totalSupply at start)
        token.transfer(buyer, 1_000e18);
    }

    function test_ListAndBuy_ApproveFlow() public {
        uint256 price = 100e18;

        // seller approves market to move NFT, then lists it (escrow)
        vm.startPrank(seller);
        nft.approve(address(market), tokenId1);
        uint256 listingId = market.list(address(nft), tokenId1, price);
        vm.stopPrank();

        // buyer approves token to market, then buys
        uint256 sellerBalBefore = token.balanceOf(seller);
        vm.startPrank(buyer);
        token.approve(address(market), price);
        market.buyNFT(listingId);
        vm.stopPrank();

        // assertions
        assertEq(nft.ownerOf(tokenId1), buyer, "buyer should own nft");
        assertEq(token.balanceOf(seller), sellerBalBefore + price, "seller should receive payment");

        // listing should be inactive
        (address Lseller, address Lnft, uint256 LtokenId, uint256 Lprice, bool Lactive) = market.listings(listingId);
        assertEq(Lseller, seller);
        assertEq(Lnft, address(nft));
        assertEq(LtokenId, tokenId1);
        assertEq(Lprice, price);
        assertTrue(!Lactive);
    }

    function test_ListAndBuy_CallbackFlow() public {
        uint256 price = 200e18;

        // seller lists tokenId2
        vm.startPrank(seller);
        nft.approve(address(market), tokenId2);
        uint256 listingId = market.list(address(nft), tokenId2, price);
        vm.stopPrank();

        uint256 sellerBalBefore = token.balanceOf(seller);

        // buyer buys with single tx: transferWithCallback(market, price, abi.encode(listingId))
        vm.startPrank(buyer);
        bytes memory data = abi.encode(listingId);
        token.transferWithCallback(address(market), price, data);
        vm.stopPrank();

        // assertions
        assertEq(nft.ownerOf(tokenId2), buyer, "buyer should own nft");
        assertEq(token.balanceOf(seller), sellerBalBefore + price, "seller should receive payment");

        // listing inactive
        (, , , , bool Lactive) = market.listings(listingId);
        assertTrue(!Lactive);
    }

    function test_CallbackWrongPriceReverts() public {
        uint256 price = 300e18;

        vm.startPrank(seller);
        nft.approve(address(market), tokenId1);
        uint256 listingId = market.list(address(nft), tokenId1, price);
        vm.stopPrank();

        vm.startPrank(buyer);
        bytes memory data = abi.encode(listingId);

        // pay wrong amount => should revert
        vm.expectRevert(); // can be more specific if you want
        token.transferWithCallback(address(market), price - 1, data);
        vm.stopPrank();
    }

    function test_CancelListing() public {
        uint256 price = 123e18;

        vm.startPrank(seller);
        nft.approve(address(market), tokenId1);
        uint256 listingId = market.list(address(nft), tokenId1, price);

        // cancel -> should return NFT to seller
        market.cancel(listingId);
        vm.stopPrank();

        assertEq(nft.ownerOf(tokenId1), seller, "nft should return to seller");
        (, , , , bool Lactive) = market.listings(listingId);
        assertTrue(!Lactive);
    }
}
