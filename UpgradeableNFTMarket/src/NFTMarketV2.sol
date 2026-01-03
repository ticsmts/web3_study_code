// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "./NFTMarketV1.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title NFTMarketV2
 * @dev 可升级的 NFT 市场合约 - 第二版
 *
 * 新增功能 - 离线签名上架：
 * - 用户只需调用一次 setApprovalForAll 授权给市场合约
 * - 每次上架时，用户离线签名（tokenId, 价格, deadline, nonce）
 * - 签名可被提交到链上完成上架
 * - NFT 保留在卖家钱包中，购买时直接从卖家转移给买家
 *
 * EIP-712 签名内容：
 * - nftContract: NFT 合约地址
 * - tokenId: NFT 的 tokenId
 * - payToken: 支付代币地址
 * - price: 价格
 * - deadline: 签名过期时间
 * - nonce: 防止重放攻击
 */
contract NFTMarketV2 is NFTMarketV1, EIP712Upgradeable {
    using ECDSA for bytes32;

    // ============ Errors (V2) ============
    error ExpiredDeadline();
    error InvalidSignature();
    error NotApprovedForAll();
    error NFTNotOwned();

    // ============ Events (V2) ============
    event ListedWithSignature(
        uint256 indexed listingId,
        address indexed seller,
        address indexed nft,
        uint256 tokenId,
        address payToken,
        uint256 price
    );

    // ============ Constants ============
    /**
     * @dev EIP-712 签名类型哈希
     *
     * 签名内容包含：
     * - nftContract: 确保签名只对特定 NFT 合约有效
     * - tokenId: 指定要上架的 NFT
     * - payToken: 指定接受的支付代币
     * - price: 上架价格
     * - deadline: 签名过期时间，防止签名被无限期使用
     * - nonce: 每个卖家的递增值，防止签名重放
     */
    bytes32 public constant LISTING_PERMIT_TYPEHASH =
        keccak256(
            "ListingPermit(address nftContract,uint256 tokenId,address payToken,uint256 price,uint256 deadline,uint256 nonce)"
        );

    // ============ State Variables (V2) ============

    /// @dev 防止签名重放的 nonce，每个卖家独立计数
    mapping(address => uint256) public sellerNonces;

    /// @dev 签名上架的记录，区分于托管式上架
    /// listingId => isSignatureListing
    mapping(uint256 => bool) public isSignatureListing;

    // ============ Constructor ============

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev V2 初始化函数，设置 EIP-712 域
     * 使用 reinitializer(2) 确保只在升级时调用一次
     */
    function initializeV2() external reinitializer(2) {
        __EIP712_init("NFTMarketV2", "1");
    }

    // ============ V2 Core Functions ============

    /**
     * @dev 使用签名上架 NFT（非托管模式）
     * @param nftContract NFT 合约地址
     * @param tokenId NFT 的 tokenId
     * @param payToken 支付代币地址
     * @param price 价格
     * @param deadline 签名过期时间
     * @param v 签名参数 v
     * @param r 签名参数 r
     * @param s 签名参数 s
     * @return listingId 上架 ID
     *
     * 实现逻辑：
     * 1. 验证签名未过期
     * 2. 构造 EIP-712 签名消息
     * 3. 恢复签名者地址
     * 4. 验证签名者是 NFT 的所有者
     * 5. 验证市场合约已获得 setApprovalForAll 授权
     * 6. 递增 nonce 防止重放
     * 7. 创建上架记录（NFT 不转移）
     *
     * 优势：
     * - 用户无需每次上架都发送交易
     * - 签名可以离线生成，节省 gas
     * - 支持批量签名预生成
     */
    function listWithSignature(
        address nftContract,
        uint256 tokenId,
        address payToken,
        uint256 price,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external nonReentrant returns (uint256 listingId) {
        // 1. 验证 deadline
        if (block.timestamp > deadline) revert ExpiredDeadline();
        if (price == 0) revert InvalidPrice();

        // 2. 获取当前 nonce
        address seller = IERC721(nftContract).ownerOf(tokenId);
        uint256 currentNonce = sellerNonces[seller];

        // 3. 构造 EIP-712 签名消息
        bytes32 structHash = keccak256(
            abi.encode(
                LISTING_PERMIT_TYPEHASH,
                nftContract,
                tokenId,
                payToken,
                price,
                deadline,
                currentNonce
            )
        );

        bytes32 hash = _hashTypedDataV4(structHash);

        // 4. 恢复签名者
        address recoveredSigner = ECDSA.recover(hash, v, r, s);

        // 5. 验证签名者是 NFT 所有者
        if (recoveredSigner != seller) revert InvalidSignature();

        // 6. 验证市场合约已获得授权
        if (!IERC721(nftContract).isApprovedForAll(seller, address(this))) {
            revert NotApprovedForAll();
        }

        // 7. 递增 nonce
        unchecked {
            sellerNonces[seller] = currentNonce + 1;
        }

        // 8. 创建上架记录
        listingId = nextListingId;
        unchecked {
            nextListingId = listingId + 1;
        }

        listings[listingId] = Listing({
            seller: seller,
            active: true,
            nft: nftContract,
            tokenId: tokenId,
            payToken: payToken,
            price: price
        });

        isSignatureListing[listingId] = true;

        emit ListedWithSignature(
            listingId,
            seller,
            nftContract,
            tokenId,
            payToken,
            price
        );
    }

    /**
     * @dev 购买 NFT（重写以支持签名上架）
     * @param listingId 上架 ID
     * @param payAmount 支付金额
     *
     * 实现逻辑：
     * - 对于托管式上架：从合约转移 NFT
     * - 对于签名式上架：从卖家直接转移 NFT
     *
     * 签名式上架的额外验证：
     * - 验证卖家仍然拥有该 NFT
     * - 验证市场合约仍有授权
     */
    function buyNFT(
        uint256 listingId,
        uint256 payAmount
    ) external override nonReentrant {
        Listing storage L = listings[listingId];
        if (!L.active) revert ListingNotActive();

        address seller_ = L.seller;
        address nft_ = L.nft;
        uint256 tokenId_ = L.tokenId;
        address payToken_ = L.payToken;
        uint256 price_ = L.price;

        if (msg.sender == seller_) revert BuySelf();
        if (payAmount != price_) revert WrongPayment();

        L.active = false;

        // 转移代币
        bool ok = IERC20(payToken_).transferFrom(
            msg.sender,
            seller_,
            payAmount
        );
        if (!ok) revert TransferFailed();

        // 根据上架类型转移 NFT
        if (isSignatureListing[listingId]) {
            // 签名式上架：从卖家直接转移
            // 验证卖家仍然拥有 NFT
            if (IERC721(nft_).ownerOf(tokenId_) != seller_)
                revert NFTNotOwned();
            IERC721(nft_).safeTransferFrom(seller_, msg.sender, tokenId_);
        } else {
            // 托管式上架：从合约转移
            IERC721(nft_).safeTransferFrom(address(this), msg.sender, tokenId_);
        }

        emit Bought(
            listingId,
            msg.sender,
            seller_,
            nft_,
            tokenId_,
            payToken_,
            price_
        );
    }

    /**
     * @dev 取消签名式上架
     * @param listingId 上架 ID
     *
     * 签名式上架无需退还 NFT，只需将上架设为非激活状态
     */
    function cancelSignatureListing(uint256 listingId) external nonReentrant {
        Listing storage L = listings[listingId];
        if (!L.active) revert ListingNotActive();
        if (L.seller != msg.sender) revert NotOwner();
        if (!isSignatureListing[listingId]) revert InvalidSignature();

        L.active = false;
        emit Cancelled(listingId, msg.sender);
    }

    // ============ View Functions (V2) ============

    /**
     * @dev 获取卖家当前 nonce
     * @param seller 卖家地址
     */
    function getSellerNonce(address seller) external view returns (uint256) {
        return sellerNonces[seller];
    }

    /**
     * @dev 获取 EIP-712 Domain Separator
     */
    function getDomainSeparator() external view returns (bytes32) {
        return _domainSeparatorV4();
    }

    /**
     * @dev 获取合约版本
     */
    function version() public pure override returns (string memory) {
        return "2.0.0";
    }

    /**
     * @dev 验证签名是否有效（辅助函数）
     * @param nftContract NFT 合约地址
     * @param tokenId NFT 的 tokenId
     * @param payToken 支付代币地址
     * @param price 价格
     * @param deadline 签名过期时间
     * @param nonce 期望的 nonce
     * @param v 签名参数 v
     * @param r 签名参数 r
     * @param s 签名参数 s
     * @return 签名者地址
     */
    function verifyListingSignature(
        address nftContract,
        uint256 tokenId,
        address payToken,
        uint256 price,
        uint256 deadline,
        uint256 nonce,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external view returns (address) {
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

        bytes32 hash = _hashTypedDataV4(structHash);
        return ECDSA.recover(hash, v, r, s);
    }
}
