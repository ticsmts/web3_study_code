// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title ZZNFTUpgradeable
 * @dev 可升级的 ERC721 NFT 合约
 *
 * 使用 UUPS 代理模式实现可升级性
 * - 通过 initialize() 替代 constructor 进行初始化
 * - 只有 owner 可以铸造 NFT
 * - 支持 setApprovalForAll 用于批量授权
 */
contract ZZNFTUpgradeable is
    Initializable,
    ERC721Upgradeable,
    OwnableUpgradeable,
    UUPSUpgradeable
{
    string private _baseTokenURI;
    uint256 private _nextTokenId;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev 初始化函数，替代 constructor
     * @param name_ NFT 名称
     * @param symbol_ NFT 符号
     * @param baseURI_ 基础 URI
     */
    function initialize(
        string memory name_,
        string memory symbol_,
        string memory baseURI_
    ) public initializer {
        __ERC721_init(name_, symbol_);
        __Ownable_init(msg.sender);
        _baseTokenURI = baseURI_;
        _nextTokenId = 1;
    }

    /**
     * @dev 铸造 NFT 给指定地址
     * @param to 接收地址
     */
    function mint(address to) public onlyOwner returns (uint256) {
        uint256 tokenId = _nextTokenId;
        _nextTokenId++;
        _safeMint(to, tokenId);
        return tokenId;
    }

    /**
     * @dev 铸造 NFT 给指定地址（指定 tokenId）
     * @param to 接收地址
     * @param tokenId 指定的 tokenId
     */
    function mintWithId(address to, uint256 tokenId) public onlyOwner {
        _safeMint(to, tokenId);
    }

    /**
     * @dev 返回 baseURI
     */
    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }

    /**
     * @dev 设置新的 baseURI
     * @param newBaseURI 新的基础 URI
     */
    function setBaseURI(string memory newBaseURI) public onlyOwner {
        _baseTokenURI = newBaseURI;
    }

    /**
     * @dev 获取当前 tokenId
     */
    function getCurrentTokenId() public view returns (uint256) {
        return _nextTokenId;
    }

    /**
     * @dev 授权升级，只有 owner 可以升级
     */
    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}
}
