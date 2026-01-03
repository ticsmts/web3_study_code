// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title ZZTokenUpgradeable
 * @dev 可升级的 ERC20 代币合约
 *
 * 使用 UUPS 代理模式实现可升级性
 * - 通过 initialize() 替代 constructor 进行初始化
 * - 初始供应量铸造给 owner
 */
contract ZZTokenUpgradeable is
    Initializable,
    ERC20Upgradeable,
    OwnableUpgradeable,
    UUPSUpgradeable
{
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev 初始化函数，替代 constructor
     * @param name_ 代币名称
     * @param symbol_ 代币符号
     * @param initialSupply 初始供应量
     */
    function initialize(
        string memory name_,
        string memory symbol_,
        uint256 initialSupply
    ) public initializer {
        __ERC20_init(name_, symbol_);
        __Ownable_init(msg.sender);
        _mint(msg.sender, initialSupply);
    }

    /**
     * @dev 铸造代币（仅 owner）
     * @param to 接收地址
     * @param amount 铸造数量
     */
    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    /**
     * @dev 授权升级，只有 owner 可以升级
     */
    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}
}
