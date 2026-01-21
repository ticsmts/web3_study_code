// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title MyL1Token - L1 原生 ERC20 Token
/// @notice 部署在 Ethereum Sepolia，可通过 Standard Bridge 跨链到 L2
contract MyL1Token is ERC20, Ownable {
    uint256 public constant FAUCET_AMOUNT = 1000 * 10 ** 18;

    mapping(address => bool) public hasClaimed;

    constructor(
        string memory name_,
        string memory symbol_,
        uint256 initialMint_
    ) ERC20(name_, symbol_) Ownable(msg.sender) {
        // 给部署者铸造初始供应量
        _mint(msg.sender, initialMint_ * 10 ** 18);
    }

    /// @notice 水龙头：每个地址可领取一次
    function faucet() external {
        require(!hasClaimed[msg.sender], "Already claimed");
        hasClaimed[msg.sender] = true;
        _mint(msg.sender, FAUCET_AMOUNT);
    }

    /// @notice Owner 可给任意地址铸币
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
}
