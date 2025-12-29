// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "./InscriptionToken.sol";

/**
 * @title InscriptionFactoryV1
 * @dev 可升级的铭文工厂合约 V1
 *
 * 功能：
 * - deployInscription: 部署新的铭文代币（使用 new 方式）
 * - mintInscription: 铸造铭文代币
 *
 * 使用 UUPS 代理模式实现可升级性
 */
contract InscriptionFactoryV1 is
    Initializable,
    OwnableUpgradeable,
    UUPSUpgradeable
{
    /// @notice 铭文代币信息
    struct InscriptionInfo {
        address creator; // 创建者
        string symbol; // 符号
        uint256 totalSupply; // 最大供应量
        uint256 perMint; // 每次铸造数量
        bool exists; // 是否存在
    }

    /// @notice 铭文代币地址 => 铭文信息
    mapping(address => InscriptionInfo) public inscriptions;

    /// @notice 所有已部署的铭文代币地址列表
    address[] public allInscriptions;

    /// @notice 铭文部署事件
    event InscriptionDeployed(
        address indexed token,
        address indexed creator,
        string symbol,
        uint256 totalSupply,
        uint256 perMint
    );

    /// @notice 铭文铸造事件
    event InscriptionMinted(
        address indexed token,
        address indexed to,
        uint256 amount
    );

    error InscriptionNotFound();
    error InvalidParameters();

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
     * @dev 部署新的铭文代币
     * @param symbol 代币符号（同时作为名称）
     * @param totalSupply 最大供应量
     * @param perMint 每次铸造数量
     * @return tokenAddress 新部署的代币地址
     */
    function deployInscription(
        string memory symbol,
        uint256 totalSupply,
        uint256 perMint
    ) external returns (address tokenAddress) {
        if (bytes(symbol).length == 0 || totalSupply == 0 || perMint == 0) {
            revert InvalidParameters();
        }
        if (perMint > totalSupply) {
            revert InvalidParameters();
        }

        // 使用 new 方式部署新代币
        InscriptionToken token = new InscriptionToken(
            symbol, // name 使用 symbol
            symbol,
            totalSupply,
            perMint,
            address(this) // 工厂作为 factory
        );

        tokenAddress = address(token);

        // 记录铭文信息
        inscriptions[tokenAddress] = InscriptionInfo({
            creator: msg.sender,
            symbol: symbol,
            totalSupply: totalSupply,
            perMint: perMint,
            exists: true
        });

        allInscriptions.push(tokenAddress);

        emit InscriptionDeployed(
            tokenAddress,
            msg.sender,
            symbol,
            totalSupply,
            perMint
        );
    }

    /**
     * @dev 铸造铭文代币
     * @param tokenAddr 铭文代币地址
     */
    function mintInscription(address tokenAddr) external {
        InscriptionInfo storage info = inscriptions[tokenAddr];
        if (!info.exists) revert InscriptionNotFound();

        InscriptionToken token = InscriptionToken(tokenAddr);
        token.mint(msg.sender);

        emit InscriptionMinted(tokenAddr, msg.sender, info.perMint);
    }

    /**
     * @dev 获取所有已部署的铭文数量
     */
    function getInscriptionsCount() external view returns (uint256) {
        return allInscriptions.length;
    }

    /**
     * @dev 获取铭文信息
     * @param tokenAddr 铭文代币地址
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

    /**
     * @dev UUPS 升级授权检查
     * @param newImplementation 新实现合约地址
     */
    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    /**
     * @dev 获取合约版本
     */
    function version() external pure virtual returns (string memory) {
        return "1.0.0";
    }
}
