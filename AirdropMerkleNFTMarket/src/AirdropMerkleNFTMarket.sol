// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

/**
 * @title AirdropMerkleNFTMarket
 * @dev NFT 市场合约，支持 Merkle 树白名单验证和 50% 折扣购买
 *
 * 功能说明：
 * 1. 基于 Merkle 树验证用户是否在白名单中
 * 2. 白名单用户可以使用 50% 折扣价格购买 NFT
 * 3. 支持 Token permit 授权（EIP-2612）
 * 4. 支持 multicall 批量调用（使用 delegatecall）
 */
contract AirdropMerkleNFTMarket is IERC721Receiver {
    // ============ Errors ============
    error InvalidPrice();
    error NotOwner();
    error ListingNotActive();
    error BuySelf();
    error TransferFailed();
    error InvalidMerkleProof();
    error MulticallFailed(uint256 index, bytes result);

    // ============ Events ============
    event Listed(
        uint256 indexed listingId,
        address indexed seller,
        address indexed nft,
        uint256 tokenId,
        address payToken,
        uint256 price
    );

    event NFTClaimed(
        uint256 indexed listingId,
        address indexed buyer,
        address indexed seller,
        address nft,
        uint256 tokenId,
        address payToken,
        uint256 originalPrice,
        uint256 discountedPrice
    );

    event MerkleRootUpdated(bytes32 indexed oldRoot, bytes32 indexed newRoot);

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

    // Merkle 树根，用于白名单验证
    bytes32 public merkleRoot;

    // 管理员地址
    address public admin;

    // 防重入锁
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _locked = _NOT_ENTERED;

    modifier nonReentrant() {
        require(_locked == _NOT_ENTERED, "REENTRANCY");
        _locked = _ENTERED;
        _;
        _locked = _NOT_ENTERED;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "Not admin");
        _;
    }

    // ============ Constructor ============
    constructor(bytes32 _merkleRoot) {
        merkleRoot = _merkleRoot;
        admin = msg.sender;
    }

    // ============ Admin Functions ============

    /// @notice 更新 Merkle 树根
    /// @param _newRoot 新的 Merkle 树根
    function setMerkleRoot(bytes32 _newRoot) external onlyAdmin {
        bytes32 oldRoot = merkleRoot;
        merkleRoot = _newRoot;
        emit MerkleRootUpdated(oldRoot, _newRoot);
    }

    // ============ Listing Functions ============

    /// @notice 上架 NFT
    /// @param nft NFT 合约地址
    /// @param tokenId NFT 的 tokenId
    /// @param payToken 支付代币地址
    /// @param price 原始价格（白名单用户享受 50% 折扣）
    function list(
        address nft,
        uint256 tokenId,
        address payToken,
        uint256 price
    ) external nonReentrant returns (uint256 listingId) {
        if (price == 0) revert InvalidPrice();

        address tokenOwner = IERC721(nft).ownerOf(tokenId);
        if (tokenOwner != msg.sender) revert NotOwner();

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

    // ============ Permit and Claim Functions ============

    /// @notice 调用 Token 的 permit 进行授权
    /// @dev 用于 multicall，通过 permit 方式授权 Token
    /// @param token Token 合约地址
    /// @param owner Token 持有者
    /// @param spender 授权给谁（应为本合约地址）
    /// @param value 授权金额
    /// @param deadline 签名过期时间
    /// @param v 签名参数 v
    /// @param r 签名参数 r
    /// @param s 签名参数 s
    function permitPrePay(
        address token,
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        IERC20Permit(token).permit(owner, spender, value, deadline, v, r, s);
    }

    /// @notice 白名单用户购买 NFT（50% 折扣）
    /// @dev 通过 Merkle 树验证白名单，需要先进行 Token 授权（可通过 permit）
    /// @param listingId 上架 ID
    /// @param merkleProof Merkle 证明
    function claimNFT(
        uint256 listingId,
        bytes32[] calldata merkleProof
    ) external nonReentrant {
        // 1. 验证 Merkle proof
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
        if (!MerkleProof.verify(merkleProof, merkleRoot, leaf)) {
            revert InvalidMerkleProof();
        }

        // 2. 获取 listing 信息
        Listing storage L = listings[listingId];
        if (!L.active) revert ListingNotActive();

        address seller_ = L.seller;
        address nft_ = L.nft;
        uint256 tokenId_ = L.tokenId;
        address payToken_ = L.payToken;
        uint256 originalPrice_ = L.price;

        if (msg.sender == seller_) revert BuySelf();

        // 3. 计算 50% 折扣价格
        uint256 discountedPrice = originalPrice_ / 2;

        // 4. 标记为已售出
        L.active = false;

        // 5. 转移 Token（从买家到卖家）
        bool ok = IERC20(payToken_).transferFrom(
            msg.sender,
            seller_,
            discountedPrice
        );
        if (!ok) revert TransferFailed();

        // 6. 转移 NFT（从合约到买家）
        IERC721(nft_).safeTransferFrom(address(this), msg.sender, tokenId_);

        emit NFTClaimed(
            listingId,
            msg.sender,
            seller_,
            nft_,
            tokenId_,
            payToken_,
            originalPrice_,
            discountedPrice
        );
    }

    // ============ Multicall Function ============

    /// @notice 批量调用多个方法（使用 delegatecall）
    /// @dev 用于一次性调用 permitPrePay + claimNFT
    /// @param data 调用数据数组
    /// @return results 返回结果数组
    function multicall(
        bytes[] calldata data
    ) external returns (bytes[] memory results) {
        results = new bytes[](data.length);
        for (uint256 i = 0; i < data.length; i++) {
            // 使用 delegatecall 保持 msg.sender
            (bool success, bytes memory result) = address(this).delegatecall(
                data[i]
            );
            if (!success) {
                revert MulticallFailed(i, result);
            }
            results[i] = result;
        }
    }

    // ============ View Functions ============

    /// @notice 获取 listing 详情
    /// @param listingId 上架 ID
    function getListing(
        uint256 listingId
    ) external view returns (Listing memory) {
        return listings[listingId];
    }

    /// @notice 验证用户是否在白名单中
    /// @param user 用户地址
    /// @param merkleProof Merkle 证明
    function isWhitelisted(
        address user,
        bytes32[] calldata merkleProof
    ) external view returns (bool) {
        bytes32 leaf = keccak256(abi.encodePacked(user));
        return MerkleProof.verify(merkleProof, merkleRoot, leaf);
    }

    /// @notice 计算折扣价格
    /// @param listingId 上架 ID
    function getDiscountedPrice(
        uint256 listingId
    ) external view returns (uint256) {
        return listings[listingId].price / 2;
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
}
