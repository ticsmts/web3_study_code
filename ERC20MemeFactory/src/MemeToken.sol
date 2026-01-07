// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/**
 * @title MemeToken
 * @dev 可初始化的 ERC20 Meme 代币合约（用于最小代理 Clone 部署）
 * @notice Initializable ERC20 Meme token for minimal proxy (Clone) deployment
 *
 * Features:
 * - 使用 Initializable 模式，支持 Clone 部署
 * - 最大供应量限制 (maxSupply)
 * - 每次铸造数量限制 (perMint)
 * - 每个代币铸造价格 (price)
 * - 只有工厂合约可以调用 mint 函数
 */
contract MemeToken is Initializable, ERC20Upgradeable {
    /// @notice 最大供应量 / Maximum supply
    uint256 public maxSupply;

    /// @notice 每次铸造数量 / Amount per mint
    uint256 public perMint;

    /// @notice 每个代币铸造价格 (wei) / Price per token in wei
    uint256 public price;

    /// @notice 工厂合约地址 / Factory contract address
    address public factory;

    /// @notice Meme 发行者地址 / Meme creator address
    address public creator;

    /// @notice 已铸造总量 / Total minted amount
    uint256 public totalMinted;

    /// @notice 代币名称常量 / Token name constant
    string private constant TOKEN_NAME = "ZZMeme";

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
     * @notice Initialize function (replaces constructor for Clone)
     * @param _symbol 代币符号 / Token symbol
     * @param _totalSupply 总发行量 / Total supply
     * @param _perMint 每次铸造数量 / Amount per mint
     * @param _price 每个代币价格 (wei) / Price per token in wei
     * @param _creator Meme 发行者地址 / Meme creator address
     * @param _factory 工厂合约地址 / Factory contract address
     */
    function initialize(
        string memory _symbol,
        uint256 _totalSupply,
        uint256 _perMint,
        uint256 _price,
        address _creator,
        address _factory
    ) external initializer {
        __ERC20_init(TOKEN_NAME, _symbol);
        maxSupply = _totalSupply;
        perMint = _perMint;
        price = _price;
        creator = _creator;
        factory = _factory;
    }

    /**
     * @dev 铸造代币，只能由工厂合约调用
     * @notice Mint tokens, can only be called by factory
     * @param to 接收地址 / Recipient address
     * @return mintedAmount 铸造的数量 / Amount minted
     */
    function mint(
        address to
    ) external onlyFactory returns (uint256 mintedAmount) {
        if (totalMinted + perMint > maxSupply) revert ExceedsMaxSupply();

        mintedAmount = perMint;
        totalMinted += perMint;
        _mint(to, perMint);
    }

    /**
     * @dev 返回剩余可铸造数量
     * @notice Returns remaining mintable amount
     */
    function remainingSupply() external view returns (uint256) {
        return maxSupply - totalMinted;
    }

    /**
     * @dev 计算铸造一次需要支付的费用
     * @notice Calculate the cost to mint once
     * @return cost 铸造费用 (wei) / Minting cost in wei
     */
    function getMintCost() external view returns (uint256 cost) {
        // perMint is in 18 decimals, price is per token in wei
        // cost = perMint * price / 1e18
        return (perMint * price) / 1e18;
    }
}
