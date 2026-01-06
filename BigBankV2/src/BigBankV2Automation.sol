// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {
    AutomationCompatibleInterface
} from "./interfaces/AutomationCompatibleInterface.sol";

/**
 * @title BigBankV2Automation
 * @notice Chainlink Automation 兼容合约，当 BigBankV2 存款超过阈值时自动转移一半到指定地址
 * @dev 实现 AutomationCompatibleInterface 接口，使用自定义逻辑触发器
 */
contract BigBankV2Automation is AutomationCompatibleInterface {
    // ============ 状态变量 ============

    /// @notice BigBankV2 合约地址
    address public immutable bank;

    /// @notice 转账接收地址
    address public immutable recipient;

    /// @notice 触发阈值（可配置）
    uint256 public threshold;

    /// @notice 管理员地址
    address public owner;

    /// @notice 上次执行时间（防止频繁触发）
    uint256 public lastPerformTime;

    /// @notice 最小执行间隔（默认 1 小时）
    uint256 public constant MIN_INTERVAL = 1 hours;

    // ============ 事件 ============

    event AutomationExecuted(uint256 transferAmount, uint256 timestamp);
    event ThresholdUpdated(uint256 oldThreshold, uint256 newThreshold);
    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    // ============ 错误 ============

    error NotOwner();
    error ThresholdNotMet();
    error IntervalNotMet();
    error TransferFailed();

    // ============ 修饰器 ============

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    // ============ 构造函数 ============

    /**
     * @notice 构造函数
     * @param _bank BigBankV2 合约地址
     * @param _recipient 转账接收地址
     * @param _threshold 触发阈值
     */
    constructor(address _bank, address _recipient, uint256 _threshold) {
        require(_bank != address(0), "Invalid bank address");
        require(_recipient != address(0), "Invalid recipient address");
        require(_threshold > 0, "Threshold must be > 0");

        bank = _bank;
        recipient = _recipient;
        threshold = _threshold;
        owner = msg.sender;
    }

    // ============ Chainlink Automation 接口 ============

    /**
     * @notice Chainlink Automation 调用检查是否需要执行
     * @dev 检查条件: 1) 余额超过阈值 2) 距离上次执行超过最小间隔
     * @return upkeepNeeded 是否需要执行
     * @return performData 传递给 performUpkeep 的数据
     */
    function checkUpkeep(
        bytes calldata
    )
        external
        view
        override
        returns (bool upkeepNeeded, bytes memory performData)
    {
        uint256 balance = bank.balance;
        bool thresholdMet = balance > threshold;
        bool intervalMet = (block.timestamp - lastPerformTime) >= MIN_INTERVAL;

        upkeepNeeded = thresholdMet && intervalMet;
        performData = abi.encode(balance);
    }

    /**
     * @notice Chainlink Automation 执行转账
     * @dev 调用 BigBankV2 的 withdraw 函数转移一半余额
     * @param performData checkUpkeep 返回的数据
     */
    function performUpkeep(bytes calldata performData) external override {
        uint256 balance = bank.balance;

        // 重新验证条件（防止恶意调用）
        if (balance <= threshold) revert ThresholdNotMet();
        if ((block.timestamp - lastPerformTime) < MIN_INTERVAL)
            revert IntervalNotMet();

        // 更新上次执行时间
        lastPerformTime = block.timestamp;

        // 计算转账金额（一半）
        uint256 transferAmount = balance / 2;

        // 调用 BigBankV2 的 withdraw 函数
        (bool success, ) = bank.call(
            abi.encodeWithSignature(
                "withdraw(uint256,address)",
                transferAmount,
                recipient
            )
        );
        if (!success) revert TransferFailed();

        emit AutomationExecuted(transferAmount, block.timestamp);
    }

    // ============ 管理功能 ============

    /**
     * @notice 更新触发阈值
     * @param _threshold 新阈值
     */
    function setThreshold(uint256 _threshold) external onlyOwner {
        require(_threshold > 0, "Threshold must be > 0");
        uint256 oldThreshold = threshold;
        threshold = _threshold;
        emit ThresholdUpdated(oldThreshold, _threshold);
    }

    /**
     * @notice 转移所有权
     * @param newOwner 新所有者地址
     */
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid new owner");
        address oldOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }

    // ============ 查询功能 ============

    /**
     * @notice 获取当前 BigBankV2 合约余额
     */
    function getBankBalance() external view returns (uint256) {
        return bank.balance;
    }

    /**
     * @notice 检查是否满足执行条件
     */
    function canPerformUpkeep()
        external
        view
        returns (bool thresholdMet, bool intervalMet)
    {
        thresholdMet = bank.balance > threshold;
        intervalMet = (block.timestamp - lastPerformTime) >= MIN_INTERVAL;
    }
}
