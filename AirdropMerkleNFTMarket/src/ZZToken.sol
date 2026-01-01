// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

/**
 * @title ZZTOKEN
 * @dev ERC20 Token with EIP-2612 Permit support
 * 支持离线签名授权，用于 AirdropMerkleNFTMarket
 */
contract ZZTOKEN is ERC20, ERC20Permit {
    constructor() ERC20("ZZTOKEN", "ZZ") ERC20Permit("ZZTOKEN") {
        // 初始供应量 1亿
        _mint(msg.sender, 100_000_000 * 10 ** decimals());
    }
}
