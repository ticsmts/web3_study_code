// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "../src/AirdropMerkleNFTMarket.sol";
import "../src/ZZNFT.sol";
import "../src/ZZToken.sol";

contract AirdropMerkleNFTMarketTest is Test {
    AirdropMerkleNFTMarket market;
    ZZNFT nft;
    ZZTOKEN token;

    // Test accounts
    address admin = address(this);

    uint256 sellerPrivateKey = 0xDEAD;
    address seller;

    uint256 whitelistUserPrivateKey = 0xB0B;
    address whitelistUser;

    address nonWhitelistUser = address(0x1234);

    // Merkle tree data
    bytes32 merkleRoot;
    bytes32[] whitelistUserProof;

    // Test constants
    uint256 constant NFT_PRICE = 1000 ether;
    uint256 constant DISCOUNTED_PRICE = 500 ether; // 50% off

    function setUp() public {
        // 计算地址
        seller = vm.addr(sellerPrivateKey);
        whitelistUser = vm.addr(whitelistUserPrivateKey);

        // 构建 Merkle 树
        // 白名单用户: whitelistUser
        // 叶子节点: keccak256(abi.encodePacked(whitelistUser))
        bytes32 leaf = keccak256(abi.encodePacked(whitelistUser));

        // 简单的单节点 Merkle 树，root 就是 leaf
        // 对于更复杂的树，需要构建完整的证明
        merkleRoot = leaf;
        whitelistUserProof = new bytes32[](0); // 单节点不需要证明

        // 部署合约
        market = new AirdropMerkleNFTMarket(merkleRoot);
        nft = new ZZNFT("TestNFT", "TNFT", "https://example.com/");
        token = new ZZTOKEN();

        // 给 seller 铸造 NFT
        nft.mintTo(seller, 1);
        nft.mintTo(seller, 2);

        // 给 whitelistUser 和 nonWhitelistUser 代币
        token.transfer(whitelistUser, 10000 ether);
        token.transfer(nonWhitelistUser, 10000 ether);
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

    function _signPermit(
        uint256 privateKey,
        address owner_,
        address spender_,
        uint256 value_,
        uint256 deadline_
    ) internal view returns (uint8 v, bytes32 r, bytes32 s) {
        bytes32 PERMIT_TYPEHASH = keccak256(
            "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
        );

        uint256 nonce = token.nonces(owner_);

        bytes32 structHash = keccak256(
            abi.encode(
                PERMIT_TYPEHASH,
                owner_,
                spender_,
                value_,
                nonce,
                deadline_
            )
        );

        bytes32 domainSeparator = token.DOMAIN_SEPARATOR();
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", domainSeparator, structHash)
        );

        (v, r, s) = vm.sign(privateKey, digest);
    }

    // ============ Test: List Success ============

    function test_List_Success() public {
        uint256 listingId = _list(1, NFT_PRICE);

        assertEq(listingId, 0);
        assertEq(nft.ownerOf(1), address(market));

        AirdropMerkleNFTMarket.Listing memory L = market.getListing(listingId);
        assertEq(L.seller, seller);
        assertEq(L.active, true);
        assertEq(L.nft, address(nft));
        assertEq(L.tokenId, 1);
        assertEq(L.payToken, address(token));
        assertEq(L.price, NFT_PRICE);
    }

    function test_List_Fail_ZeroPrice() public {
        vm.startPrank(seller);
        nft.approve(address(market), 1);

        vm.expectRevert(
            abi.encodeWithSelector(AirdropMerkleNFTMarket.InvalidPrice.selector)
        );
        market.list(address(nft), 1, address(token), 0);
        vm.stopPrank();
    }

    // ============ Test: ClaimNFT Success ============

    function test_ClaimNFT_Success_WithDiscount() public {
        uint256 listingId = _list(1, NFT_PRICE);

        // 白名单用户授权并购买
        vm.startPrank(whitelistUser);
        token.approve(address(market), DISCOUNTED_PRICE);

        uint256 sellerBalanceBefore = token.balanceOf(seller);
        uint256 buyerBalanceBefore = token.balanceOf(whitelistUser);

        market.claimNFT(listingId, whitelistUserProof);
        vm.stopPrank();

        // 验证 NFT 转移
        assertEq(nft.ownerOf(1), whitelistUser);

        // 验证 Token 转移（50% 折扣）
        assertEq(
            token.balanceOf(seller),
            sellerBalanceBefore + DISCOUNTED_PRICE
        );
        assertEq(
            token.balanceOf(whitelistUser),
            buyerBalanceBefore - DISCOUNTED_PRICE
        );
    }

    function test_ClaimNFT_Fail_InvalidProof() public {
        uint256 listingId = _list(1, NFT_PRICE);

        // 非白名单用户尝试购买
        vm.startPrank(nonWhitelistUser);
        token.approve(address(market), DISCOUNTED_PRICE);

        bytes32[] memory fakeProof = new bytes32[](0);
        vm.expectRevert(
            abi.encodeWithSelector(
                AirdropMerkleNFTMarket.InvalidMerkleProof.selector
            )
        );
        market.claimNFT(listingId, fakeProof);
        vm.stopPrank();
    }

    function test_ClaimNFT_Fail_ListingNotActive() public {
        uint256 listingId = _list(1, NFT_PRICE);

        // 第一次购买成功
        vm.startPrank(whitelistUser);
        token.approve(address(market), DISCOUNTED_PRICE);
        market.claimNFT(listingId, whitelistUserProof);

        // 第二次购买失败（已下架）
        vm.expectRevert(
            abi.encodeWithSelector(
                AirdropMerkleNFTMarket.ListingNotActive.selector
            )
        );
        market.claimNFT(listingId, whitelistUserProof);
        vm.stopPrank();
    }

    // ============ Test: PermitPrePay ============

    function test_PermitPrePay_Success() public {
        uint256 deadline = block.timestamp + 1 hours;
        uint256 amount = 1000 ether;

        (uint8 v, bytes32 r, bytes32 s) = _signPermit(
            whitelistUserPrivateKey,
            whitelistUser,
            address(market),
            amount,
            deadline
        );

        // 调用 permitPrePay
        market.permitPrePay(
            address(token),
            whitelistUser,
            address(market),
            amount,
            deadline,
            v,
            r,
            s
        );

        // 验证授权
        assertEq(token.allowance(whitelistUser, address(market)), amount);
    }

    // ============ Test: Multicall ============

    function test_Multicall_PermitAndClaim_Success() public {
        uint256 listingId = _list(1, NFT_PRICE);
        uint256 deadline = block.timestamp + 1 hours;

        // 签名 permit
        (uint8 v, bytes32 r, bytes32 s) = _signPermit(
            whitelistUserPrivateKey,
            whitelistUser,
            address(market),
            DISCOUNTED_PRICE,
            deadline
        );

        // 构造 multicall 数据
        bytes[] memory calls = new bytes[](2);

        // 1. permitPrePay 调用数据
        calls[0] = abi.encodeWithSelector(
            market.permitPrePay.selector,
            address(token),
            whitelistUser,
            address(market),
            DISCOUNTED_PRICE,
            deadline,
            v,
            r,
            s
        );

        // 2. claimNFT 调用数据
        calls[1] = abi.encodeWithSelector(
            market.claimNFT.selector,
            listingId,
            whitelistUserProof
        );

        // 执行 multicall
        vm.prank(whitelistUser);
        market.multicall(calls);

        // 验证
        assertEq(nft.ownerOf(1), whitelistUser);
    }

    function test_Multicall_Fail_InvalidProof() public {
        uint256 listingId = _list(1, NFT_PRICE);
        uint256 deadline = block.timestamp + 1 hours;

        // 非白名单用户签名
        uint256 fakePrivateKey = 0x9999;
        address fakeUser = vm.addr(fakePrivateKey);
        token.transfer(fakeUser, 10000 ether);

        (uint8 v, bytes32 r, bytes32 s) = _signPermit(
            fakePrivateKey,
            fakeUser,
            address(market),
            DISCOUNTED_PRICE,
            deadline
        );

        bytes[] memory calls = new bytes[](2);
        calls[0] = abi.encodeWithSelector(
            market.permitPrePay.selector,
            address(token),
            fakeUser,
            address(market),
            DISCOUNTED_PRICE,
            deadline,
            v,
            r,
            s
        );

        bytes32[] memory emptyProof = new bytes32[](0);
        calls[1] = abi.encodeWithSelector(
            market.claimNFT.selector,
            listingId,
            emptyProof
        );

        // 非白名单用户执行 multicall 应该失败
        vm.prank(fakeUser);
        vm.expectRevert(); // MulticallFailed due to InvalidMerkleProof
        market.multicall(calls);
    }

    // ============ Test: View Functions ============

    function test_IsWhitelisted() public view {
        bool isWhitelisted = market.isWhitelisted(
            whitelistUser,
            whitelistUserProof
        );
        assertTrue(isWhitelisted);

        bytes32[] memory emptyProof = new bytes32[](0);
        bool isNotWhitelisted = market.isWhitelisted(
            nonWhitelistUser,
            emptyProof
        );
        assertFalse(isNotWhitelisted);
    }

    function test_GetDiscountedPrice() public {
        uint256 listingId = _list(1, NFT_PRICE);
        uint256 discountedPrice = market.getDiscountedPrice(listingId);
        assertEq(discountedPrice, DISCOUNTED_PRICE);
    }

    // ============ Test: Admin Functions ============

    function test_SetMerkleRoot() public {
        bytes32 newRoot = keccak256(abi.encodePacked("new root"));
        market.setMerkleRoot(newRoot);
        assertEq(market.merkleRoot(), newRoot);
    }

    function test_SetMerkleRoot_Fail_NotAdmin() public {
        bytes32 newRoot = keccak256(abi.encodePacked("new root"));

        vm.prank(whitelistUser);
        vm.expectRevert("Not admin");
        market.setMerkleRoot(newRoot);
    }

    // ============ Test: Complex Merkle Tree ============

    function test_ClaimNFT_WithRealMerkleTree() public {
        // 构建更复杂的 Merkle 树
        // 白名单用户: user1, user2
        address user1 = address(0x1111);
        address user2 = address(0x2222);

        bytes32 leaf1 = keccak256(abi.encodePacked(user1));
        bytes32 leaf2 = keccak256(abi.encodePacked(user2));

        // 计算 Merkle root
        bytes32 root;
        if (leaf1 < leaf2) {
            root = keccak256(abi.encodePacked(leaf1, leaf2));
        } else {
            root = keccak256(abi.encodePacked(leaf2, leaf1));
        }

        // 部署新的 market
        AirdropMerkleNFTMarket newMarket = new AirdropMerkleNFTMarket(root);

        // 给 user1 代币
        token.transfer(user1, 10000 ether);

        // 给 seller 铸造新 NFT
        nft.mintTo(seller, 100);

        // 上架
        vm.startPrank(seller);
        nft.approve(address(newMarket), 100);
        uint256 listingId = newMarket.list(
            address(nft),
            100,
            address(token),
            NFT_PRICE
        );
        vm.stopPrank();

        // 构造 user1 的 Merkle proof
        bytes32[] memory proof = new bytes32[](1);
        proof[0] = leaf2; // user1 需要 leaf2 作为证明

        // user1 购买
        vm.startPrank(user1);
        token.approve(address(newMarket), DISCOUNTED_PRICE);
        newMarket.claimNFT(listingId, proof);
        vm.stopPrank();

        assertEq(nft.ownerOf(100), user1);
    }
}
