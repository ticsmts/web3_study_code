// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title InscriptionToken
 * @dev ERC20 铭文代币合约
 *
 * 特性：
 * - 最大供应量限制 (maxSupply)
 * - 每次铸造数量限制 (perMint)
 * - 只有工厂合约可以调用 mint 函数
 */
contract InscriptionToken is ERC20 {
    /// @notice 最大供应量
    uint256 public maxSupply;

    /// @notice 每次铸造数量
    uint256 public perMint;

    /// @notice 工厂合约地址
    address public factory;

    /// @notice 已铸造总量
    uint256 public totalMinted;

    error OnlyFactory();
    error ExceedsMaxSupply();

    modifier onlyFactory() {
        if (msg.sender != factory) revert OnlyFactory();
        _;
    }

    /**
     * @dev 构造函数
     * @param _name 代币名称
     * @param _symbol 代币符号
     * @param _maxSupply 最大供应量
     * @param _perMint 每次铸造数量
     * @param _factory 工厂合约地址
     */
    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _maxSupply,
        uint256 _perMint,
        address _factory
    ) ERC20(_name, _symbol) {
        maxSupply = _maxSupply;
        perMint = _perMint;
        factory = _factory;
    }

    /**
     * @dev 铸造代币，只能由工厂合约调用
     * @param to 接收地址
     */
    function mint(address to) external onlyFactory {
        if (totalMinted + perMint > maxSupply) revert ExceedsMaxSupply();

        totalMinted += perMint;
        _mint(to, perMint);
    }

    /**
     * @dev 返回剩余可铸造数量
     */
    function remainingSupply() external view returns (uint256) {
        return maxSupply - totalMinted;
    }
}
