// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract MockERC721 {
    mapping(uint256 => address) public ownerOf;
    mapping(uint256 => address) public getApproved;

    function mint(address to, uint256 tokenId) external {
        ownerOf[tokenId] = to;
    }

    function approve(address to, uint256 tokenId) external {
        require(msg.sender == ownerOf[tokenId], "NOT_OWNER");
        getApproved[tokenId] = to;
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) external {
        require(ownerOf[tokenId] == from, "BAD_FROM");
        require(msg.sender == from || msg.sender == getApproved[tokenId], "NOT_AUTH");

        ownerOf[tokenId] = to;
        getApproved[tokenId] = address(0);

        if (to.code.length > 0) {
            bytes4 ret = IERC721Receiver(to).onERC721Received(msg.sender, from, tokenId, "");
            require(ret == IERC721Receiver.onERC721Received.selector, "NO_ERC721_RECEIVER");
        }
    }
}
