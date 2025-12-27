// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "../src/ZZNFTMarketV3.sol";
import "../src/ZZNFT.sol";
import "../src/ZZToken.sol";

contract ZZNFTMarketV3Test is Test {
    ZZNFTMarketV3 market;
    ZZNFT nft;
    ZZTOKEN token;

    // Test accounts
    address admin = address(this);
    uint256 signerPrivateKey = 0xA11CE;
    address signer;

    address seller = address(0xDEAD);

    uint256 buyerPrivateKey = 0xB0B;
    address buyer;

    // EIP-712 domain constants
    bytes32 constant WHITELIST_PERMIT_TYPEHASH =
        keccak256(
            "WhitelistPermit(address buyer,uint256 listingId,uint256 nonce,uint256 deadline)"
        );

    function setUp() public {
        // 计算地址
        signer = vm.addr(signerPrivateKey);
        buyer = vm.addr(buyerPrivateKey);

        // 部署合约
        market = new ZZNFTMarketV3(signer);
        nft = new ZZNFT("TestNFT", "TNFT", "https://example.com/");
        token = new ZZTOKEN();

        // 给seller铸造NFT
        nft.mint(seller, 1);
        nft.mint(seller, 2);

        // 给buyer代币
        token.transfer(buyer, 1000000 ether);
    }

    // ============ Helper Functions ============

    function _list(
        uint256 tokenId,
        uint256 price
    ) internal returns (uint256 listingId) {
        vm.startPrank(seller);
        nft.approve(address(market), tokenId);
        listingId = market.list(address(nft), tokenId, address(token), price);
        vm.stopPrank();
    }

    function _signWhitelistPermit(
        uint256 _signerKey,
        address _buyer,
        uint256 _listingId,
        uint256 _nonce,
        uint256 _deadline
    ) internal view returns (uint8 v, bytes32 r, bytes32 s) {
        bytes32 structHash = keccak256(
            abi.encode(
                WHITELIST_PERMIT_TYPEHASH,
                _buyer,
                _listingId,
                _nonce,
                _deadline
            )
        );

        bytes32 domainSeparator = market.getDomainSeparator();
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", domainSeparator, structHash)
        );

        (v, r, s) = vm.sign(_signerKey, digest);
    }

    // ============ Test: List Success ============

    function test_List_Success_EmitsEvent() public {
        uint256 price = 100 ether;

        vm.startPrank(seller);
        nft.approve(address(market), 1);

        vm.expectEmit(true, true, true, true);
        emit ZZNFTMarketV3.Listed(
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
        assertEq(nft.ownerOf(1), address(market));
    }

    function test_List_Fail_ZeroPrice() public {
        vm.startPrank(seller);
        nft.approve(address(market), 1);

        vm.expectRevert(
            abi.encodeWithSelector(ZZNFTMarketV3.InvalidPrice.selector)
        );
        market.list(address(nft), 1, address(token), 0);
        vm.stopPrank();
    }

    function test_List_Fail_NotOwner() public {
        vm.startPrank(buyer);
        vm.expectRevert(
            abi.encodeWithSelector(ZZNFTMarketV3.NotOwner.selector)
        );
        market.list(address(nft), 1, address(token), 100 ether);
        vm.stopPrank();
    }

    // ============ Test: Normal Buy ============

    function test_BuyNFT_Success() public {
        uint256 price = 200 ether;
        uint256 listingId = _list(1, price);

        vm.startPrank(buyer);
        token.approve(address(market), price);

        vm.expectEmit(true, true, true, true);
        emit ZZNFTMarketV3.Bought(
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
    }

    function test_BuyNFT_Fail_BuySelf() public {
        uint256 price = 200 ether;
        uint256 listingId = _list(1, price);

        vm.startPrank(seller);
        token.approve(address(market), price);

        vm.expectRevert(abi.encodeWithSelector(ZZNFTMarketV3.BuySelf.selector));
        market.buyNFT(listingId, price);
        vm.stopPrank();
    }

    // ============ Test: PermitBuy Success ============

    function test_PermitBuy_Success() public {
        uint256 price = 300 ether;
        uint256 listingId = _list(1, price);
        uint256 deadline = block.timestamp + 1 hours;
        uint256 nonce = market.getNonce(buyer);

        // 项目方签名
        (uint8 v, bytes32 r, bytes32 s) = _signWhitelistPermit(
            signerPrivateKey,
            buyer,
            listingId,
            nonce,
            deadline
        );

        // 买家使用签名购买
        vm.startPrank(buyer);
        token.approve(address(market), price);

        vm.expectEmit(true, true, true, true);
        emit ZZNFTMarketV3.PermitBought(
            listingId,
            buyer,
            seller,
            address(nft),
            1,
            address(token),
            price
        );

        market.permitBuy(listingId, deadline, v, r, s);
        vm.stopPrank();

        assertEq(nft.ownerOf(1), buyer);
        assertEq(market.getNonce(buyer), 1); // nonce应该增加
    }

    // ============ Test: PermitBuy Failures ============

    function test_PermitBuy_Fail_InvalidSignature() public {
        uint256 price = 300 ether;
        uint256 listingId = _list(1, price);
        uint256 deadline = block.timestamp + 1 hours;
        uint256 nonce = market.getNonce(buyer);

        // 使用错误的私钥签名（不是项目方）
        uint256 wrongPrivateKey = 0xBAD;
        (uint8 v, bytes32 r, bytes32 s) = _signWhitelistPermit(
            wrongPrivateKey,
            buyer,
            listingId,
            nonce,
            deadline
        );

        vm.startPrank(buyer);
        token.approve(address(market), price);

        vm.expectRevert(
            abi.encodeWithSelector(ZZNFTMarketV3.NotWhitelisted.selector)
        );
        market.permitBuy(listingId, deadline, v, r, s);
        vm.stopPrank();
    }

    function test_PermitBuy_Fail_ExpiredDeadline() public {
        uint256 price = 300 ether;
        uint256 listingId = _list(1, price);
        uint256 deadline = block.timestamp - 1; // 已过期
        uint256 nonce = market.getNonce(buyer);

        (uint8 v, bytes32 r, bytes32 s) = _signWhitelistPermit(
            signerPrivateKey,
            buyer,
            listingId,
            nonce,
            deadline
        );

        vm.startPrank(buyer);
        token.approve(address(market), price);

        vm.expectRevert(
            abi.encodeWithSelector(ZZNFTMarketV3.ExpiredDeadline.selector)
        );
        market.permitBuy(listingId, deadline, v, r, s);
        vm.stopPrank();
    }

    function test_PermitBuy_Fail_WrongBuyer() public {
        uint256 price = 300 ether;
        uint256 listingId = _list(1, price);
        uint256 deadline = block.timestamp + 1 hours;

        // 签名给buyer，但另一个人尝试使用
        address anotherBuyer = address(0x1234);
        token.transfer(anotherBuyer, 1000 ether);

        uint256 nonce = market.getNonce(anotherBuyer);

        // 签名是给buyer的
        (uint8 v, bytes32 r, bytes32 s) = _signWhitelistPermit(
            signerPrivateKey,
            buyer, // 签名给buyer
            listingId,
            nonce,
            deadline
        );

        // anotherBuyer尝试使用
        vm.startPrank(anotherBuyer);
        token.approve(address(market), price);

        vm.expectRevert(
            abi.encodeWithSelector(ZZNFTMarketV3.NotWhitelisted.selector)
        );
        market.permitBuy(listingId, deadline, v, r, s);
        vm.stopPrank();
    }

    function test_PermitBuy_Fail_WrongListingId() public {
        uint256 price = 300 ether;
        uint256 listingId1 = _list(1, price);
        uint256 listingId2 = _list(2, price);
        uint256 deadline = block.timestamp + 1 hours;
        uint256 nonce = market.getNonce(buyer);

        // 签名是给listingId1的
        (uint8 v, bytes32 r, bytes32 s) = _signWhitelistPermit(
            signerPrivateKey,
            buyer,
            listingId1, // 签名给listing 1
            nonce,
            deadline
        );

        // 尝试用于listing 2
        vm.startPrank(buyer);
        token.approve(address(market), price);

        vm.expectRevert(
            abi.encodeWithSelector(ZZNFTMarketV3.NotWhitelisted.selector)
        );
        market.permitBuy(listingId2, deadline, v, r, s);
        vm.stopPrank();
    }

    function test_PermitBuy_Fail_ReplayAttack() public {
        uint256 price = 300 ether;
        uint256 listingId = _list(1, price);
        uint256 deadline = block.timestamp + 1 hours;
        uint256 nonce = market.getNonce(buyer);

        (uint8 v, bytes32 r, bytes32 s) = _signWhitelistPermit(
            signerPrivateKey,
            buyer,
            listingId,
            nonce,
            deadline
        );

        vm.startPrank(buyer);
        token.approve(address(market), price * 2);

        // 第一次成功
        market.permitBuy(listingId, deadline, v, r, s);

        // 尝试重放（listing已经不活跃了）
        vm.expectRevert(
            abi.encodeWithSelector(ZZNFTMarketV3.ListingNotActive.selector)
        );
        market.permitBuy(listingId, deadline, v, r, s);
        vm.stopPrank();
    }

    // ============ Test: Admin Functions ============

    function test_SetSigner_Success() public {
        address newSigner = address(0x9999);

        vm.expectEmit(true, true, false, false);
        emit ZZNFTMarketV3.SignerUpdated(signer, newSigner);

        market.setSigner(newSigner);

        assertEq(market.signer(), newSigner);
    }

    function test_SetSigner_Fail_NotAdmin() public {
        address newSigner = address(0x9999);

        vm.prank(buyer);
        vm.expectRevert("Not admin");
        market.setSigner(newSigner);
    }

    // ============ Fuzz Tests ============

    function testFuzz_PermitBuy_RandomPriceAndDeadline(
        uint256 price,
        uint256 deadlineOffset
    ) public {
        price = bound(price, 0.01 ether, 10000 ether);
        deadlineOffset = bound(deadlineOffset, 1, 365 days);

        uint256 listingId = _list(1, price);
        uint256 deadline = block.timestamp + deadlineOffset;
        uint256 nonce = market.getNonce(buyer);

        (uint8 v, bytes32 r, bytes32 s) = _signWhitelistPermit(
            signerPrivateKey,
            buyer,
            listingId,
            nonce,
            deadline
        );

        vm.startPrank(buyer);
        token.approve(address(market), price);
        market.permitBuy(listingId, deadline, v, r, s);
        vm.stopPrank();

        assertEq(nft.ownerOf(1), buyer);
    }
}
