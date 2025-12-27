// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

interface IERC20Like {
    function transfer(address to, uint256 value) external returns (bool);
    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external returns (bool);
}

interface IZZNFT {
    function ownerOf(uint256 tokenId) external view returns (address);
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;
}

/**
 * @title ZZNFTMarketV3
 * @dev NFT Marketplace with whitelist-based permit purchase using EIP-712 signatures
 *
 * 功能说明：
 * - 项目方（signer）可以离线为白名单用户签名授权
 * - 白名单用户调用 permitBuy() 并传入签名信息来购买NFT
 * - 使用 EIP-712 类型化数据签名，提供更好的安全性和用户体验
 */
contract ZZNFTMarketV3 is IERC721Receiver, EIP712 {
    using ECDSA for bytes32;

    // ============ Errors ============
    error InvalidPrice();
    error NotOwner();
    error ListingNotActive();
    error BuySelf();
    error WrongPayment();
    error TransferFailed();
    error InvalidSignature();
    error ExpiredDeadline();
    error NotWhitelisted();

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

    event PermitBought(
        uint256 indexed listingId,
        address indexed buyer,
        address indexed seller,
        address nft,
        uint256 tokenId,
        address payToken,
        uint256 price
    );

    event SignerUpdated(address indexed oldSigner, address indexed newSigner);

    // ============ Structs ============
    struct Listing {
        address seller;
        address nft;
        uint256 tokenId;
        address payToken;
        uint256 price;
        bool active;
    }

    // ============ State Variables ============
    mapping(uint256 => Listing) public listings;
    uint256 public nextListingId;

    // 项目方地址 - 负责签名白名单授权
    address public signer;

    // 管理员地址 - 可以更新signer
    address public admin;

    // 用于防止签名重放的nonce
    mapping(address => uint256) public nonces;

    // EIP-712 类型化数据哈希
    // WhitelistPermit(address buyer,uint256 listingId,uint256 nonce,uint256 deadline)
    bytes32 public constant WHITELIST_PERMIT_TYPEHASH =
        keccak256(
            "WhitelistPermit(address buyer,uint256 listingId,uint256 nonce,uint256 deadline)"
        );

    // 防重入锁
    uint256 private _locked = 1;
    modifier nonReentrant() {
        require(_locked == 1, "REENTRANCY");
        _locked = 2;
        _;
        _locked = 1;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "Not admin");
        _;
    }

    // ============ Constructor ============
    constructor(address _signer) EIP712("ZZNFTMarketV3", "1") {
        require(_signer != address(0), "Invalid signer address");
        signer = _signer;
        admin = msg.sender;
    }

    // ============ Admin Functions ============

    /// @notice 更新签名者地址（项目方）
    /// @param _newSigner 新的签名者地址
    function setSigner(address _newSigner) external onlyAdmin {
        require(_newSigner != address(0), "Invalid signer address");
        address oldSigner = signer;
        signer = _newSigner;
        emit SignerUpdated(oldSigner, _newSigner);
    }

    // ============ Listing Functions ============

    /// @notice 上架NFT
    /// @param nft NFT合约地址
    /// @param tokenId NFT的tokenId
    /// @param payToken 支付代币地址
    /// @param price 价格
    function list(
        address nft,
        uint256 tokenId,
        address payToken,
        uint256 price
    ) external nonReentrant returns (uint256 listingId) {
        if (price == 0) revert InvalidPrice();

        address owner = IZZNFT(nft).ownerOf(tokenId);
        if (owner != msg.sender) revert NotOwner();

        // 托管NFT到合约
        IZZNFT(nft).safeTransferFrom(msg.sender, address(this), tokenId);

        listingId = nextListingId++;
        listings[listingId] = Listing({
            seller: msg.sender,
            nft: nft,
            tokenId: tokenId,
            payToken: payToken,
            price: price,
            active: true
        });

        emit Listed(listingId, msg.sender, nft, tokenId, payToken, price);
    }

    // ============ Purchase Functions ============

    /// @notice 普通购买（无白名单限制）
    /// @param listingId 上架ID
    /// @param payAmount 支付金额
    function buyNFT(
        uint256 listingId,
        uint256 payAmount
    ) external nonReentrant {
        Listing storage L = listings[listingId];
        if (!L.active) revert ListingNotActive();
        if (msg.sender == L.seller) revert BuySelf();
        if (payAmount != L.price) revert WrongPayment();

        L.active = false;

        bool ok = IERC20Like(L.payToken).transferFrom(
            msg.sender,
            L.seller,
            payAmount
        );
        if (!ok) revert TransferFailed();

        IZZNFT(L.nft).safeTransferFrom(address(this), msg.sender, L.tokenId);

        emit Bought(
            listingId,
            msg.sender,
            L.seller,
            L.nft,
            L.tokenId,
            L.payToken,
            L.price
        );
    }

    /// @notice 白名单许可购买
    /// @dev 买家需要先获得项目方的签名授权
    /// @param listingId 上架ID
    /// @param deadline 签名过期时间
    /// @param v 签名参数v
    /// @param r 签名参数r
    /// @param s 签名参数s
    function permitBuy(
        uint256 listingId,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external nonReentrant {
        // 1. 检查deadline是否过期
        if (block.timestamp > deadline) revert ExpiredDeadline();

        // 2. 获取listing信息
        Listing storage L = listings[listingId];
        if (!L.active) revert ListingNotActive();
        if (msg.sender == L.seller) revert BuySelf();

        // 3. 获取买家当前nonce，并在验证前递增（防止重放）
        uint256 currentNonce = nonces[msg.sender]++;

        // 4. 构造EIP-712签名消息
        bytes32 structHash = keccak256(
            abi.encode(
                WHITELIST_PERMIT_TYPEHASH,
                msg.sender, // buyer
                listingId, // listingId
                currentNonce, // nonce
                deadline // deadline
            )
        );

        bytes32 hash = _hashTypedDataV4(structHash);

        // 5. 恢复签名者地址
        address recoveredSigner = ECDSA.recover(hash, v, r, s);

        // 6. 验证签名者是否为项目方
        if (recoveredSigner != signer) revert NotWhitelisted();

        // 7. 执行购买
        L.active = false;

        bool ok = IERC20Like(L.payToken).transferFrom(
            msg.sender,
            L.seller,
            L.price
        );
        if (!ok) revert TransferFailed();

        IZZNFT(L.nft).safeTransferFrom(address(this), msg.sender, L.tokenId);

        emit PermitBought(
            listingId,
            msg.sender,
            L.seller,
            L.nft,
            L.tokenId,
            L.payToken,
            L.price
        );
    }

    // ============ View Functions ============

    /// @notice 获取用户当前nonce（用于前端构造签名）
    /// @param user 用户地址
    function getNonce(address user) external view returns (uint256) {
        return nonces[user];
    }

    /// @notice 获取EIP-712 Domain Separator
    function getDomainSeparator() external view returns (bytes32) {
        return _domainSeparatorV4();
    }

    /// @notice 获取listing详情
    /// @param listingId 上架ID
    function getListing(
        uint256 listingId
    ) external view returns (Listing memory) {
        return listings[listingId];
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
