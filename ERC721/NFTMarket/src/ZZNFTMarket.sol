// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "./interfaces/ITokenReceiver.sol";
interface IZZTOKEN {
    function transfer(address to, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

interface IZZNFT {
    function ownerOf(uint256 tokenId) external view returns (address);

    function safeTransferFrom(address from, address to, uint256 tokenId) external;
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) external;

    function approve(address to, uint256 tokenId) external;
}

contract ZZNFTMarket is ITokenReceiver, IERC721Receiver {
    // ============ Errors (optional but nice) ============
    error NotSeller();
    error InvalidPrice();
    error ListingNotActive();
    error WrongPayment();
    error OnlyPaymentToken();
    error TransferFailed();

    // ============ Events ============
    event Listed(
        uint256 indexed listingId,
        address indexed seller,
        address indexed nft,
        uint256 tokenId,
        uint256 price
    );

    event Bought(
        uint256 indexed listingId,
        address indexed buyer,
        address indexed seller,
        address nft,
        uint256 tokenId,
        uint256 price
    );

    event Cancelled(uint256 indexed listingId);

    // ============ Storage ============
    struct Listing {
        address seller;
        address nft;
        uint256 tokenId;
        uint256 price; // amount of ERC20 tokens
        bool active;
    }

    IZZTOKEN public immutable paymentToken;

    mapping(uint256 => Listing) public listings;
    uint256 public nextListingId;

    // very small reentrancy guard (enough for this project)
    uint256 private _locked = 1;
    modifier nonReentrant() {
        require(_locked == 1, "REENTRANCY");
        _locked = 2;
        _;
        _locked = 1;
    }

    constructor(address token) {
        require(token != address(0), "token=0");
        paymentToken = IZZTOKEN(token);
    }

    // ============ Listing ============
    function list(address nft, uint256 tokenId, uint256 price)
        external
        nonReentrant
        returns (uint256 listingId)
    {
        if (price == 0) revert InvalidPrice();

        // require seller owns it
        address owner = IZZNFT(nft).ownerOf(tokenId);
        require(owner == msg.sender, "NOT_OWNER");

        // escrow NFT into market (requires approve/approvalForAll set by seller)
        IZZNFT(nft).safeTransferFrom(msg.sender, address(this), tokenId);

        listingId = nextListingId++;
        listings[listingId] = Listing({
            seller: msg.sender,
            nft: nft,
            tokenId: tokenId,
            price: price,
            active: true
        });

        emit Listed(listingId, msg.sender, nft, tokenId, price);
    }

    function cancel(uint256 listingId) external nonReentrant {
        Listing storage L = listings[listingId];
        if (!L.active) revert ListingNotActive();
        if (L.seller != msg.sender) revert NotSeller();

        L.active = false;

        // return NFT back to seller
        IZZNFT(L.nft).safeTransferFrom(address(this), msg.sender, L.tokenId);

        emit Cancelled(listingId);
    }

    // ============ Buy path 1: approve + buyNFT ============
    function buyNFT(uint256 listingId) external nonReentrant {
        Listing storage L = listings[listingId];
        if (!L.active) revert ListingNotActive();

        // mark inactive first (prevents double-buy)
        L.active = false;

        // pull token from buyer -> seller
        bool okPay = paymentToken.transferFrom(msg.sender, L.seller, L.price);
        if (!okPay) revert TransferFailed();

        // send NFT to buyer
        IZZNFT(L.nft).safeTransferFrom(address(this), msg.sender, L.tokenId);

        emit Bought(listingId, msg.sender, L.seller, L.nft, L.tokenId, L.price);
    }

    // ============ Buy path 2: callback purchase ============
    // buyer calls token.transferWithCallback(market, price, abi.encode(listingId))
    function tokensReceived(
        address /*operator*/,
        address from,
        uint256 value,
        bytes calldata data
    ) external nonReentrant returns (bool) {
        if (msg.sender != address(paymentToken)) revert OnlyPaymentToken();

        uint256 listingId = abi.decode(data, (uint256));
        Listing storage L = listings[listingId];
        if (!L.active) revert ListingNotActive();

        // must pay exact price
        if (value != L.price) revert WrongPayment();

        // mark inactive first
        L.active = false;

        // at this point, token has already transferred `value` into this market contract
        // so we forward token from market -> seller
        bool okPay = paymentToken.transfer(L.seller, value);
        if (!okPay) revert TransferFailed();

        // send NFT to buyer (from)
        IZZNFT(L.nft).safeTransferFrom(address(this), from, L.tokenId);

        emit Bought(listingId, from, L.seller, L.nft, L.tokenId, L.price);
        return true;
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
