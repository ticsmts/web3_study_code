// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title BigBankV2
 * @notice 存款合约，支持直接转账存款，使用可迭代链表维护前10名存款用户
 *
 * 功能：
 * 1. 通过 Metamask 等钱包直接给合约地址存款
 * 2. 记录每个地址的存款金额
 * 3. 用可迭代链表保存存款金额前10名用户
 */
contract BigBankV2 {
    // ============ 状态变量 ============

    /// @notice 管理员地址
    address public owner;

    /// @notice 每个地址的存款金额
    mapping(address => uint256) public balances;

    /// @notice 链表：每个地址指向下一个排名更低的地址
    mapping(address => address) public nextDepositor;

    /// @notice 链表头哨兵节点
    address public constant HEAD = address(1);

    /// @notice 当前链表大小
    uint256 public listSize;

    /// @notice 链表最大容量
    uint256 public constant MAX_SIZE = 10;

    /// @notice 最小存款金额
    uint256 public constant MIN_DEPOSIT = 0.001 ether;

    // ============ 事件 ============

    event Deposit(address indexed user, uint256 amount, uint256 newBalance);
    event Withdraw(address indexed to, uint256 amount);
    event AdminChanged(address indexed oldAdmin, address indexed newAdmin);

    // ============ 修饰器 ============

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier depositAmountValid() {
        require(msg.value >= MIN_DEPOSIT, "Deposit must be >= 0.001 ETH");
        _;
    }

    // ============ 构造函数 ============

    constructor() {
        owner = msg.sender;
        // 初始化链表头节点指向自身表示空链表
        nextDepositor[HEAD] = HEAD;
    }

    // ============ 存款功能 ============

    /// @notice 接收 ETH 存款（支持 Metamask 直接转账）
    receive() external payable {
        _deposit(msg.sender, msg.value);
    }

    /// @notice 显式存款函数
    function deposit() external payable depositAmountValid {
        _deposit(msg.sender, msg.value);
    }

    /// @notice 内部存款逻辑
    function _deposit(address user, uint256 amount) internal {
        require(amount >= MIN_DEPOSIT, "Deposit must be >= 0.001 ETH");

        uint256 oldBalance = balances[user];
        balances[user] += amount;
        uint256 newBalance = balances[user];

        emit Deposit(user, amount, newBalance);

        // 更新链表
        _updateLinkedList(user, oldBalance, newBalance);
    }

    // ============ 链表操作 ============

    /// @notice 更新链表中用户的位置
    /// @param user 用户地址
    /// @param oldBalance 用户旧余额
    /// @param newBalance 用户新余额
    function _updateLinkedList(
        address user,
        uint256 oldBalance,
        uint256 newBalance
    ) internal {
        // 如果用户已在链表中，先移除
        if (oldBalance > 0 && _isInList(user)) {
            _removeFromList(user);
        }

        // 插入到正确位置
        _insertSorted(user, newBalance);
    }

    /// @notice 检查用户是否在链表中
    function _isInList(address user) internal view returns (bool) {
        if (user == HEAD || user == address(0)) return false;

        address current = nextDepositor[HEAD];
        while (current != HEAD) {
            if (current == user) {
                return true;
            }
            current = nextDepositor[current];
        }
        return false;
    }

    /// @notice 从链表中移除用户
    function _removeFromList(address user) internal {
        address current = HEAD;
        while (nextDepositor[current] != HEAD) {
            if (nextDepositor[current] == user) {
                nextDepositor[current] = nextDepositor[user];
                nextDepositor[user] = address(0);
                listSize--;
                return;
            }
            current = nextDepositor[current];
        }
    }

    /// @notice 按余额降序插入用户到链表
    /// @dev 链表顺序: HEAD -> 最大 -> 第二大 -> ... -> 最小 -> HEAD
    function _insertSorted(address user, uint256 balance) internal {
        // 如果链表已满，检查是否有资格进入前10
        if (listSize >= MAX_SIZE) {
            // 获取最后一个元素的余额
            uint256 lastBalance = _getLastBalance();
            if (balance <= lastBalance) {
                return; // 不够资格进入前10
            }
            // 移除最后一个，为新用户腾位置
            _removeLast();
        }

        // 找到插入位置：找到第一个余额小于当前用户的节点，在它之前插入
        address prev = HEAD;
        address current = nextDepositor[HEAD];

        while (current != HEAD && balances[current] >= balance) {
            prev = current;
            current = nextDepositor[current];
        }

        // 在 prev 和 current 之间插入 user
        nextDepositor[user] = current;
        nextDepositor[prev] = user;
        listSize++;
    }

    /// @notice 获取链表最后一个元素的余额
    function _getLastBalance() internal view returns (uint256) {
        address current = nextDepositor[HEAD];
        address last = HEAD;

        while (current != HEAD) {
            last = current;
            current = nextDepositor[current];
        }

        return last == HEAD ? 0 : balances[last];
    }

    /// @notice 移除链表最后一个元素
    function _removeLast() internal {
        address current = HEAD;
        address prev = HEAD;

        while (nextDepositor[current] != HEAD) {
            prev = current;
            current = nextDepositor[current];
        }

        if (current != HEAD) {
            nextDepositor[prev] = HEAD;
            nextDepositor[current] = address(0);
            listSize--;
        }
    }

    // ============ 查询功能 ============

    /// @notice 获取用户余额
    function getBalance(address user) external view returns (uint256) {
        return balances[user];
    }

    /// @notice 获取自己的余额
    function getMyBalance() external view returns (uint256) {
        return balances[msg.sender];
    }

    /// @notice 获取前10名存款用户
    /// @return users 用户地址数组
    /// @return amounts 对应的存款金额数组
    function getTopDepositors()
        external
        view
        returns (address[] memory users, uint256[] memory amounts)
    {
        users = new address[](listSize);
        amounts = new uint256[](listSize);

        address current = nextDepositor[HEAD];
        uint256 index = 0;

        while (current != HEAD && index < listSize) {
            users[index] = current;
            amounts[index] = balances[current];
            current = nextDepositor[current];
            index++;
        }

        return (users, amounts);
    }

    /// @notice 获取合约总余额
    function getTotalBalance() external view returns (uint256) {
        return address(this).balance;
    }

    // ============ 管理功能 ============

    /// @notice 管理员提现
    function withdraw(uint256 amount, address payable to) external onlyOwner {
        require(amount > 0, "Amount must be > 0");
        require(
            address(this).balance >= amount,
            "Insufficient contract balance"
        );

        (bool ok, ) = to.call{value: amount}("");
        require(ok, "Transfer failed");

        emit Withdraw(to, amount);
    }

    /// @notice 转移管理员
    function setAdmin(address newAdmin) external onlyOwner {
        require(newAdmin != address(0), "Invalid admin address");
        address oldAdmin = owner;
        owner = newAdmin;
        emit AdminChanged(oldAdmin, newAdmin);
    }
}
