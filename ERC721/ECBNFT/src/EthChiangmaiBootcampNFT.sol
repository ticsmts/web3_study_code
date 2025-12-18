// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

/// @title EthChiangmaiBootcampNFT
/// @notice Official NFT collection for ETHChiangmai Bootcamp
/// @dev ERC721 + EIP-2981


contract EthChiangmaiBootcampNFT is ERC721, Ownable, ERC2981 {
    using Strings for uint256;

    string private _baseTokenURI;
    uint256 private _nextTokenId;

    event BaseURIUpdated(string oldBaseURI, string newBaseURI);
    event DefaultRoyaltyUpdated(address receiver, uint96 feeBps);


    constructor(
        string memory name_,
        string memory symbol_,
        string memory baseURI_,
        address royaltyReceiver_,
        uint96 royaltyFeeBps_ // 500 = 5%
    ) ERC721(name_, symbol_) Ownable(msg.sender) {
        require(royaltyReceiver_ != address(0), "Royalty receiver is zero");
        require(royaltyFeeBps_ <= 10_000, "Royalty fee too high");

        _baseTokenURI = baseURI_;
        _nextTokenId = 1;

        // EIP-2981 默认版税（对所有 token 生效）
        _setDefaultRoyalty(royaltyReceiver_, royaltyFeeBps_);
        emit DefaultRoyaltyUpdated(royaltyReceiver_, royaltyFeeBps_);
    }

    // -------- Mint --------
    function mint(address to) external onlyOwner returns (uint256 tokenId) {
        tokenId = _nextTokenId++;
        _safeMint(to, tokenId);
    }

    // -------- Metadata --------
    function setBaseURI(string calldata newBaseURI) external onlyOwner {
        emit BaseURIUpdated(_baseTokenURI, newBaseURI);
        _baseTokenURI = newBaseURI;
    }

    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }

    // -------- Royalty (EIP-2981) --------
    function setDefaultRoyalty(address receiver, uint96 feeBps) external onlyOwner {
        require(receiver != address(0), "Royalty receiver is zero");
        require(feeBps <= 10_000, "Royalty fee too high");
        _setDefaultRoyalty(receiver, feeBps);
        emit DefaultRoyaltyUpdated(receiver, feeBps);
    }

    function deleteDefaultRoyalty() external onlyOwner {
        _deleteDefaultRoyalty();
    }

    // 可选：对某个 token 单独设置版税
    function setTokenRoyalty(uint256 tokenId, address receiver, uint96 feeBps) external onlyOwner {
        _setTokenRoyalty(tokenId, receiver, feeBps);
    }

    function resetTokenRoyalty(uint256 tokenId) external onlyOwner {
        _resetTokenRoyalty(tokenId);
    }

    // -------- Interface support --------
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC2981)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    

    

}
