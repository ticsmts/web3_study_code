// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "./InscriptionToken.sol";
import "./InscriptionTokenV2.sol";

/**
 * @title InscriptionFactoryV2
 * @dev 可升级的铭文工厂合约 V2
 *
 * V2 新功能：
 * - 使用最小代理 (ERC1167) 部署代币，节省 gas
 * - 添加 price 参数，mint 时收取费用
 * - withdrawFees 提取收益
 *
 * 向后兼容：V1 部署的铭文仍可正常使用
 */
contract InscriptionFactoryV2 is
    Initializable,
    OwnableUpgradeable,
    UUPSUpgradeable
{
    using Clones for address;

    /// @notice 铭文代币信息 (V1 兼容)
    struct InscriptionInfo {
        address creator; // 创建者
        string symbol; // 符号
        uint256 totalSupply; // 最大供应量
        uint256 perMint; // 每次铸造数量
        bool exists; // 是否存在
    }

    /// @notice V2 铭文扩展信息
    struct InscriptionInfoV2 {
        uint256 price; // 每次 mint 价格
        bool isV2; // 是否为 V2 部署
    }

    /// @notice 铭文代币地址 => 铭文信息 (V1 兼容 - slot 0)
    mapping(address => InscriptionInfo) public inscriptions;

    /// @notice 所有已部署的铭文代币地址列表 (V1 兼容 - slot 1)
    address[] public allInscriptions;

    // ============ V2 新增存储 (slot 2+) ============

    /// @notice 铭文代币地址 => V2 扩展信息
    mapping(address => InscriptionInfoV2) public inscriptionsV2;

    /// @notice 代币实现合约地址 (用于 Clone)
    address public tokenImplementation;

    /// @notice 累计收取的费用
    uint256 public totalFees;

    /// @notice 铭文部署事件 (V1 兼容)
    event InscriptionDeployed(
        address indexed token,
        address indexed creator,
        string symbol,
        uint256 totalSupply,
        uint256 perMint
    );

    /// @notice V2 铭文部署事件 (带价格)
    event InscriptionDeployedV2(
        address indexed token,
        address indexed creator,
        string symbol,
        uint256 totalSupply,
        uint256 perMint,
        uint256 price
    );

    /// @notice 铭文铸造事件
    event InscriptionMinted(
        address indexed token,
        address indexed to,
        uint256 amount
    );

    /// @notice 费用提取事件
    event FeesWithdrawn(address indexed to, uint256 amount);

    error InscriptionNotFound();
    error InvalidParameters();
    error InsufficientPayment();
    error WithdrawFailed();

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev 初始化函数（替代构造函数）
     * @param initialOwner 初始 owner 地址
     */
    function initialize(address initialOwner) public initializer {
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();
    }

    /**
     * @dev V2 初始化 - 设置代币实现合约
     * @param _tokenImplementation InscriptionTokenV2 实现合约地址
     */
    function initializeV2(address _tokenImplementation) external onlyOwner {
        require(tokenImplementation == address(0), "Already initialized");
        tokenImplementation = _tokenImplementation;
    }

    /**
     * @dev V1 兼容: 部署新的铭文代币 (无价格)
     */
    function deployInscription(
        string memory symbol,
        uint256 totalSupply,
        uint256 perMint
    ) external returns (address tokenAddress) {
        // 调用 V2 方法，价格为 0
        return deployInscription(symbol, totalSupply, perMint, 0);
    }

    /**
     * @dev V2: 部署新的铭文代币 (带价格)
     * @param symbol 代币符号（同时作为名称）
     * @param totalSupply 最大供应量
     * @param perMint 每次铸造数量
     * @param price 每次铸造价格 (wei)
     * @return tokenAddress 新部署的代币地址
     */
    function deployInscription(
        string memory symbol,
        uint256 totalSupply,
        uint256 perMint,
        uint256 price
    ) public returns (address tokenAddress) {
        if (bytes(symbol).length == 0 || totalSupply == 0 || perMint == 0) {
            revert InvalidParameters();
        }
        if (perMint > totalSupply) {
            revert InvalidParameters();
        }

        // 如果有代币实现合约，使用最小代理
        if (tokenImplementation != address(0)) {
            // 使用 Clones 创建最小代理
            tokenAddress = tokenImplementation.clone();

            // 初始化代币
            InscriptionTokenV2(tokenAddress).initialize(
                symbol,
                symbol,
                totalSupply,
                perMint,
                address(this)
            );
        } else {
            // V1 兼容模式：使用 new 创建
            InscriptionToken token = new InscriptionToken(
                symbol,
                symbol,
                totalSupply,
                perMint,
                address(this)
            );
            tokenAddress = address(token);
        }

        // 记录铭文信息
        inscriptions[tokenAddress] = InscriptionInfo({
            creator: msg.sender,
            symbol: symbol,
            totalSupply: totalSupply,
            perMint: perMint,
            exists: true
        });

        // 记录 V2 扩展信息
        inscriptionsV2[tokenAddress] = InscriptionInfoV2({
            price: price,
            isV2: tokenImplementation != address(0)
        });

        allInscriptions.push(tokenAddress);

        if (price > 0) {
            emit InscriptionDeployedV2(
                tokenAddress,
                msg.sender,
                symbol,
                totalSupply,
                perMint,
                price
            );
        } else {
            emit InscriptionDeployed(
                tokenAddress,
                msg.sender,
                symbol,
                totalSupply,
                perMint
            );
        }
    }

    /**
     * @dev 铸造铭文代币 (V2 支持收费)
     * @param tokenAddr 铭文代币地址
     */
    function mintInscription(address tokenAddr) external payable {
        InscriptionInfo storage info = inscriptions[tokenAddr];
        if (!info.exists) revert InscriptionNotFound();

        // 检查价格
        InscriptionInfoV2 storage infoV2 = inscriptionsV2[tokenAddr];
        if (infoV2.price > 0) {
            if (msg.value < infoV2.price) revert InsufficientPayment();
            totalFees += infoV2.price;

            // 退还多余的 ETH
            if (msg.value > infoV2.price) {
                (bool success, ) = msg.sender.call{
                    value: msg.value - infoV2.price
                }("");
                require(success, "Refund failed");
            }
        }

        // 根据代币类型调用 mint
        if (infoV2.isV2) {
            InscriptionTokenV2(tokenAddr).mint(msg.sender);
        } else {
            InscriptionToken(tokenAddr).mint(msg.sender);
        }

        emit InscriptionMinted(tokenAddr, msg.sender, info.perMint);
    }

    /**
     * @dev 提取累计费用 (仅 owner)
     */
    function withdrawFees() external onlyOwner {
        uint256 amount = totalFees;
        if (amount == 0) revert InvalidParameters();

        totalFees = 0;

        (bool success, ) = owner().call{value: amount}("");
        if (!success) revert WithdrawFailed();

        emit FeesWithdrawn(owner(), amount);
    }

    /**
     * @dev 获取所有已部署的铭文数量
     */
    function getInscriptionsCount() external view returns (uint256) {
        return allInscriptions.length;
    }

    /**
     * @dev 获取铭文信息 (V1 兼容)
     */
    function getInscriptionInfo(
        address tokenAddr
    )
        external
        view
        returns (
            address creator,
            string memory symbol,
            uint256 totalSupply,
            uint256 perMint,
            uint256 totalMinted,
            uint256 remainingSupply
        )
    {
        InscriptionInfo storage info = inscriptions[tokenAddr];
        if (!info.exists) revert InscriptionNotFound();

        InscriptionInfoV2 storage infoV2 = inscriptionsV2[tokenAddr];

        if (infoV2.isV2) {
            InscriptionTokenV2 token = InscriptionTokenV2(tokenAddr);
            return (
                info.creator,
                info.symbol,
                info.totalSupply,
                info.perMint,
                token.totalMinted(),
                token.remainingSupply()
            );
        } else {
            InscriptionToken token = InscriptionToken(tokenAddr);
            return (
                info.creator,
                info.symbol,
                info.totalSupply,
                info.perMint,
                token.totalMinted(),
                token.remainingSupply()
            );
        }
    }

    /**
     * @dev 获取铭文价格 (V2)
     */
    function getInscriptionPrice(
        address tokenAddr
    ) external view returns (uint256) {
        InscriptionInfo storage info = inscriptions[tokenAddr];
        if (!info.exists) revert InscriptionNotFound();
        return inscriptionsV2[tokenAddr].price;
    }

    /**
     * @dev UUPS 升级授权检查
     */
    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    /**
     * @dev 获取合约版本
     */
    function version() external pure virtual returns (string memory) {
        return "2.0.0";
    }

    /**
     * @dev 接收 ETH
     */
    receive() external payable {}
}
