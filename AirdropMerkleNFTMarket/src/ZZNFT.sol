// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

/**
 * @title ZZNFT
 * @dev ERC721 NFT implementation for AirdropMerkleNFTMarket
 */
contract ZZNFT is ERC721 {
    address public owner;
    string private _baseTokenURI;
    uint256 private _nextTokenId;

    modifier onlyOwner() {
        require(msg.sender == owner, "ZZNFT: not owner");
        _;
    }

    constructor(
        string memory name_,
        string memory symbol_,
        string memory baseURI_
    ) ERC721(name_, symbol_) {
        owner = msg.sender;
        _baseTokenURI = baseURI_;
    }

    function mint(address to) external onlyOwner returns (uint256) {
        uint256 tokenId = _nextTokenId++;
        _safeMint(to, tokenId);
        return tokenId;
    }

    function mintTo(address to, uint256 tokenId) external onlyOwner {
        _safeMint(to, tokenId);
    }

    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }

    function setBaseURI(string memory baseURI_) external onlyOwner {
        _baseTokenURI = baseURI_;
    }
}
