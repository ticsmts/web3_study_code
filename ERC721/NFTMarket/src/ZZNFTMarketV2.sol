// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

interface IERC20Like {
    function transfer(address to, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

interface IZZNFT {
    function ownerOf(uint256 tokenId) external view returns (address);
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
}

contract ZZNFTMarketV2 is IERC721Receiver {
    // Errors
    error InvalidPrice();
    error NotOwner();
    error ListingNotActive();
    error BuySelf();
    error WrongPayment();
    error TransferFailed();

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

    struct Listing {
        address seller;
        address nft;
        uint256 tokenId;
        address payToken;
        uint256 price;
        bool active;
    }

    mapping(uint256 => Listing) public listings;
    uint256 public nextListingId;

    uint256 private _locked = 1;
    modifier nonReentrant() {
        require(_locked == 1, "REENTRANCY");
        _locked = 2;
        _;
        _locked = 1;
    }

    function list(
        address nft,
        uint256 tokenId,
        address payToken,
        uint256 price
    ) external nonReentrant returns (uint256 listingId) {
        if (price == 0) revert InvalidPrice();

        address owner = IZZNFT(nft).ownerOf(tokenId);
        if (owner != msg.sender) revert NotOwner();

        // escrow
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

    function buyNFT(uint256 listingId, uint256 payAmount) external nonReentrant {
        Listing storage L = listings[listingId];
        if (!L.active) revert ListingNotActive();
        if (msg.sender == L.seller) revert BuySelf();
        if (payAmount != L.price) revert WrongPayment();

        L.active = false;

        bool ok = IERC20Like(L.payToken).transferFrom(msg.sender, L.seller, payAmount);
        if (!ok) revert TransferFailed();

        IZZNFT(L.nft).safeTransferFrom(address(this), msg.sender, L.tokenId);

        emit Bought(listingId, msg.sender, L.seller, L.nft, L.tokenId, L.payToken, L.price);
    }

    function onERC721Received(address, address, uint256, bytes calldata)
        external
        pure
        returns (bytes4)
    {
        return IERC721Receiver.onERC721Received.selector;
    }
}
