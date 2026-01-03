// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title NFTMarketV1
 * @dev 可升级的 NFT 市场合约 - 第一版
 *
 * 功能：
 * - 托管式上架：卖家将 NFT 转移到合约进行上架
 * - 普通购买：买家支付 ERC20 代币购买 NFT
 * - 取消上架：卖家可以取消上架并取回 NFT
 *
 * 升级说明：
 * - 使用 UUPS 代理模式，只有 owner 可以升级
 * - 保留 storage gap 用于未来版本添加状态变量
 */
contract NFTMarketV1 is
    Initializable,
    OwnableUpgradeable,
    UUPSUpgradeable,
    ReentrancyGuard,
    IERC721Receiver
{
    // ============ Errors ============
    error InvalidPrice();
    error NotOwner();
    error ListingNotActive();
    error BuySelf();
    error WrongPayment();
    error TransferFailed();

    // ============ Events ============
    event Listed(
        uint256 indexed listingId,
        address indexed seller,
        address indexed nft,
        uint256 tokenId,
        address payToken,
        uint256 price
    );

    event Bought(
        uint256 indexed listingId,
        address indexed buyer,
        address indexed seller,
        address nft,
        uint256 tokenId,
        address payToken,
        uint256 price
    );

    event Cancelled(uint256 indexed listingId, address indexed seller);

    // ============ Structs ============
    struct Listing {
        address seller;
        bool active;
        address nft;
        uint256 tokenId;
        address payToken;
        uint256 price;
    }

    // ============ State Variables ============
    mapping(uint256 => Listing) public listings;
    uint256 public nextListingId;

    // Storage gap for future upgrades
    uint256[48] private __gap;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev 初始化函数
     */
    function initialize() public initializer {
        __Ownable_init(msg.sender);
    }

    // ============ Core Functions ============

    /**
     * @dev 上架 NFT（托管模式）
     * @param nft NFT 合约地址
     * @param tokenId NFT 的 tokenId
     * @param payToken 支付代币地址
     * @param price 价格
     * @return listingId 上架 ID
     *
     * 实现逻辑：
     * 1. 验证价格不为 0
     * 2. 验证调用者是 NFT 的所有者
     * 3. 将 NFT 转移到市场合约（托管）
     * 4. 创建上架记录
     */
    function list(
        address nft,
        uint256 tokenId,
        address payToken,
        uint256 price
    ) external nonReentrant returns (uint256 listingId) {
        if (price == 0) revert InvalidPrice();

        address owner = IERC721(nft).ownerOf(tokenId);
        if (owner != msg.sender) revert NotOwner();

        // 托管 NFT 到合约
        IERC721(nft).safeTransferFrom(msg.sender, address(this), tokenId);

        listingId = nextListingId;
        unchecked {
            nextListingId = listingId + 1;
        }

        listings[listingId] = Listing({
            seller: msg.sender,
            active: true,
            nft: nft,
            tokenId: tokenId,
            payToken: payToken,
            price: price
        });

        emit Listed(listingId, msg.sender, nft, tokenId, payToken, price);
    }

    /**
     * @dev 购买 NFT
     * @param listingId 上架 ID
     * @param payAmount 支付金额
     *
     * 实现逻辑：
     * 1. 验证上架处于激活状态
     * 2. 验证买家不是卖家本人
     * 3. 验证支付金额正确
     * 4. 将上架设为非激活
     * 5. 转移代币从买家到卖家
     * 6. 转移 NFT 从合约到买家
     */
    function buyNFT(
        uint256 listingId,
        uint256 payAmount
    ) external virtual nonReentrant {
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

        bool ok = IERC20(payToken_).transferFrom(
            msg.sender,
            seller_,
            payAmount
        );
        if (!ok) revert TransferFailed();

        IERC721(nft_).safeTransferFrom(address(this), msg.sender, tokenId_);

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
     * @dev 取消上架
     * @param listingId 上架 ID
     *
     * 实现逻辑：
     * 1. 验证上架处于激活状态
     * 2. 验证调用者是卖家
     * 3. 将上架设为非激活
     * 4. 将 NFT 退还给卖家
     */
    function cancelListing(uint256 listingId) external nonReentrant {
        Listing storage L = listings[listingId];
        if (!L.active) revert ListingNotActive();
        if (L.seller != msg.sender) revert NotOwner();

        L.active = false;

        IERC721(L.nft).safeTransferFrom(address(this), msg.sender, L.tokenId);

        emit Cancelled(listingId, msg.sender);
    }

    // ============ View Functions ============

    /**
     * @dev 获取上架详情
     * @param listingId 上架 ID
     */
    function getListing(
        uint256 listingId
    ) external view returns (Listing memory) {
        return listings[listingId];
    }

    /**
     * @dev 获取合约版本
     */
    function version() public pure virtual returns (string memory) {
        return "1.0.0";
    }

    // ============ ERC721 Receiver ============

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    // ============ Upgrade ============

    /**
     * @dev 授权升级，只有 owner 可以升级
     *
     * UUPS 升级模式的关键函数：
     * - 新实现合约必须通过此检查
     * - 确保只有授权用户可以执行升级
     */
    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}
}
