// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/**
 * @title InscriptionTokenV2
 * @dev 可初始化的 ERC20 铭文代币合约（用于最小代理 Clone）
 *
 * 特性：
 * - 使用 Initializable 模式，支持 Clone 部署
 * - 最大供应量限制 (maxSupply)
 * - 每次铸造数量限制 (perMint)
 * - 只有工厂合约可以调用 mint 函数
 */
contract InscriptionTokenV2 is Initializable, ERC20Upgradeable {
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

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev 初始化函数（替代构造函数，用于 Clone）
     * @param _name 代币名称
     * @param _symbol 代币符号
     * @param _maxSupply 最大供应量
     * @param _perMint 每次铸造数量
     * @param _factory 工厂合约地址
     */
    function initialize(
        string memory _name,
        string memory _symbol,
        uint256 _maxSupply,
        uint256 _perMint,
        address _factory
    ) external initializer {
        __ERC20_init(_name, _symbol);
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
