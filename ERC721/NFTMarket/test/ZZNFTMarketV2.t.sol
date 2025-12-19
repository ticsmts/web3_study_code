//// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "../src/ZZNFTMarketV2.sol";
import "./mocks/MockERC20.sol";
import "./mocks/MockERC721.sol";

contract ZZNFTMarketV2Test is Test{
    ZZNFTMarketV2 market;
    MockERC721 nft;
    MockERC20 tokenA;
    MockERC20 tokenB;

    address seller = address(0xA11CE);
    address buyer = address(0xB0B);

    function setUp() public{
        market = new ZZNFTMarketV2();
        nft = new MockERC721();
        tokenA = new MockERC20("TokenA", "A");
        tokenB = new MockERC20("TokenB", "B");

        nft.mint(seller, 1);

        tokenA.mint(buyer, 1000000 ether);
        tokenB.mint(buyer, 1000000 ether);
    }

    //测试上架成功失败+事件断言
    function _list(uint256 price, address payToken) internal returns (uint256 id){
        vm.startPrank(seller);
        nft.approve(address(market), 1);
        id = market.list(address(nft), 1, payToken, price);
        vm.stopPrank();
    }

    //测试上架成功事件
    function test_List_Success_EmitsEvent() public {
        uint256 price = 100 ether;
        vm.startPrank(seller);
        nft.approve(address(market), 1);
        
        vm.expectEmit(true, true, true, true);
        emit ZZNFTMarketV2.Listed(0, seller, address(nft), 1, address(tokenA), price);

        uint256 listingId = market.list(address(nft), 1, address(tokenA), price);
        vm.stopPrank();

        assertEq(listingId, 0);
        assertEq(nft.ownerOf(1), address(market));
    }

    //测试0价格上架，断言失败信息error InvalidPrice();
    function test_List_Fail_ZeroPrice() public {
        vm.startPrank(seller);
        nft.approve(address(market), 1);

        vm.expectRevert(abi.encodeWithSelector(ZZNFTMarketV2.InvalidPrice.selector));
        market.list(address(nft), 1, address(tokenA), 0);

        vm.stopPrank();
    }

    //测试非owner上架，断言失败信息error NotOwner();
    function test_List_Fail_NotOwner() public {
        vm.startPrank(buyer);
        vm.expectRevert(abi.encodeWithSelector(ZZNFTMarketV2.NotOwner.selector));
        market.list(address(nft), 1, address(tokenA), 1 ether);
        vm.stopPrank();
    }

    //测试购买成功事件
    function test_Buy_Success_EmitsEvent() public {
        uint256 price = 200 ether;
        uint256 id = _list(price, address(tokenA));
        
        vm.startPrank(buyer);
        tokenA.approve(address(market), price);

        vm.expectEmit(true, true, true, true);
        emit ZZNFTMarketV2.Bought(id, buyer, seller, address(nft), 1, address(tokenA), price);
        
        market.buyNFT(id, price);
        vm.stopPrank();
    }

    //测试自己购买失败事件
    function test_Buy_Fail_BuySelf() public {
        uint256 price = 200 ether;
        uint id = _list(price, address(tokenA));

        vm.startPrank(seller);
        tokenA.approve(address(market), price);
        vm.expectRevert(abi.encodeWithSelector(ZZNFTMarketV2.BuySelf.selector));
        market.buyNFT(id, price);

        vm.stopPrank();
    }

    //测试重复购买事件
    function test_Buy_Fail_BuyRepeat() public {
        uint256 price = 200 ether;
        uint id = _list(price, address(tokenA));

        vm.startPrank(buyer);
        tokenA.approve(address(market), price);
        market.buyNFT(id, price);

        tokenA.approve(address(market), price);
        vm.expectRevert(abi.encodeWithSelector(ZZNFTMarketV2.ListingNotActive.selector));
        market.buyNFT(id, price);
        vm.stopPrank();
    }

    //测试支付Token不足
    function test_Buy_Fail_WrongPayment_TooLow() public {
        uint256 price = 200 ether;
        uint256 id = _list(price, address(tokenA));

        vm.startPrank(buyer);
        tokenA.approve(address(market), price);
        vm.expectRevert(abi.encodeWithSelector(ZZNFTMarketV2.WrongPayment.selector));
        market.buyNFT(id, 100 ether);

        vm.stopPrank();
    }

    //测试支付Token过多
    function test_Buy_Fail_WrongPayment_TooHigh() public {
        uint256 price = 200 ether;
        uint256 id = _list(price, address(tokenA));

        vm.startPrank(buyer);
        tokenA.approve(address(market), price);
        vm.expectRevert(abi.encodeWithSelector(ZZNFTMarketV2.WrongPayment.selector));
        market.buyNFT(id, 300 ether);

        vm.stopPrank();
    }

    //模糊测试
    function testFuzz_ListAndBuy_RandomPriceAndBuyer(uint price, address randBuyer) public {
        //随机价格：0.01-10000
        uint256 randPrice = bound(price, 0.01 ether, 10000 ether);

        //随机买家
        vm.assume(randBuyer != address(0));
        vm.assume(randBuyer != seller);
        vm.assume(randBuyer.code.length == 0); 

        tokenA.mint(randBuyer, randPrice);
        
        //上架
        vm.startPrank(seller);
        nft.approve(address(market), 1);
        uint256 id = market.list(address(nft), 1, address(tokenA), randPrice);
        vm.stopPrank();

        //购买
        vm.startPrank(randBuyer);
        tokenA.approve(address(market), randPrice);
        market.buyNFT(id, randPrice);
        vm.stopPrank();    

        assertEq(nft.ownerOf(1), randBuyer);
    
    }

}