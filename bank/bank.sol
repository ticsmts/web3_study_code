// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract Bank {
    // 管理员（合约拥有者）
    address public owner;

    // 每个地址的存款金额
    mapping(address => uint256) public balances;

    // 前三名存款用户
    struct TopDepositor {
        address user;
        uint256 amount;
    }

    TopDepositor[3] public topDepositors;

    // 事件
    event Deposit(address indexed user, uint256 amount, uint256 newBalance);
    event Withdraw(address indexed to, uint256 amount);

    // 只允许管理员执行的修饰器
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    // 1. 允许用普通转账方式给合约存钱（MetaMask 直接 transfer 即会触发）
    receive() external payable {
        _deposit(msg.sender, msg.value);
    }

    // 可选：也提供一个显式的 deposit 函数，方便前端调用
    function deposit() external payable {
        require(msg.value > 0, "No ETH sent");
        _deposit(msg.sender, msg.value);
    }

    // 2. 内部存款逻辑
    function _deposit(address user, uint256 amount) internal {
        balances[user] += amount;
        emit Deposit(user, amount, balances[user]);

        _updateTopDepositors(user);
    }

    // 3. 查询自己余额
    function getMyBalance() external view returns (uint256) {
        return balances[msg.sender];
    }

    // 3. 查询任意地址余额（其实有 public balances 也可以）
    function getBalance(address user) external view returns (uint256) {
        return balances[user];
    }

    // 4. 管理员提现资金
    function withdraw(uint256 amount, address payable to) external onlyOwner {
        require(amount > 0, "Amount must be > 0");
        require(address(this).balance >= amount, "Insufficient contract balance");

        // 发送 ETH
        (bool ok, ) = to.call{value: amount}("");
        require(ok, "Transfer failed");

        emit Withdraw(to, amount);
    }

    // 5. 获取前 3 名存款用户
    function getTopDepositors() external view returns (TopDepositor[3] memory) {
        return topDepositors;
    }

    // 内部函数：更新前 3 名榜单
    function _updateTopDepositors(address user) internal {
        uint256 userBalance = balances[user];

        // 1. 如果已经在榜单上，更新金额后重新排序
        for (uint256 i = 0; i < topDepositors.length; i++) {
            if (topDepositors[i].user == user) {
                topDepositors[i].amount = userBalance;
                _reorderTopDepositors();
                return;
            }
        }

        // 2. 如果不在榜单上，看看能不能挤进前 3
        for (uint256 i = 0; i < topDepositors.length; i++) {
            if (userBalance > topDepositors[i].amount) {
                // 从后往前挪，空出位置 i
                for (uint256 j = topDepositors.length - 1; j > i; j--) {
                    topDepositors[j] = topDepositors[j - 1];
                }
                topDepositors[i] = TopDepositor({user: user, amount: userBalance});
                break;
            }
        }
    }

    // 简单排序：保证数组从大到小
    function _reorderTopDepositors() internal {
        // 因为只有 3 个元素，直接用简单的冒泡就够了
        for (uint256 i = 0; i < topDepositors.length; i++) {
            for (uint256 j = i + 1; j < topDepositors.length; j++) {
                if (topDepositors[j].amount > topDepositors[i].amount) {
                    TopDepositor memory tmp = topDepositors[i];
                    topDepositors[i] = topDepositors[j];
                    topDepositors[j] = tmp;
                }
            }
        }
    }
}
