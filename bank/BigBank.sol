// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*
题目：
    编写IBank接口及BigBank合约，使其满足Bank实现IBank接口，BigBank继承自Bank，同时BigBank有附加要求：
    1. 要求存款金额大于0.001 ether（用modifier权限控制）
    2. BigBank合约支持转移管理员。编写一个Admin合约， Admin合约有自己的Owner, 同时有一个取款函数adminWithdraw(IBank bank), adminWithdraw 中会调用 IBank 接口的withdraw方法从而把bank合约内的资金转移到Admin合约地址。
    3. BigBank和Admin合约部署后，把BigBank的管理员转移给Admin合约地址，模拟几个用户的存款，然后Admin合约的Owner地址调用adminWithdraw(IBank bank) 把BigBank的资金转移到Admin地址。

理解：
    接口设计: 接口定义了合约应该实现的方法与行为，但没有具体的实现。
    继承: 继承可以使一个合约在现有合约的基础上扩展新的功能。
    函数修改器: 是solidty的一种函数修饰符，在函数执行前后执行一些操作（权限验证，条件检查等）。
    合约权限管理: 在合约中，通过限制谁可以进行存款，提取来进行权限控制。
    合约间调用：跨合约调用，Admin合约需要通过调用IBank接口的withdraw方法来提取BigBank合约的资金。
    合约升级：合约的管理员功能实现, 将合约的管理员转移权限从BigBank转移到Admin合约。

实现：
    1. 编写IBank接口及Bank合约实现IBank接口
    2. 实现BigBank合约，继承Bank合约
    3. 实现Admin合约
*/

interface IBank {
    function deposit() external payable;             // 存款方法
    function getBalance(address user) external view returns (uint256); // 查询余额
    function withdraw(uint256 amount, address payable to) external;    // 提现方法
}



contract Bank is IBank{
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
    function deposit() public payable override virtual{  //bug修复: 不能为external可见性，必须为public
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
    function getBalance(address user) external override view returns (uint256) {
        return balances[user];
    }

    // 4. 管理员提现资金
    function withdraw(uint256 amount, address payable to) external override onlyOwner {
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



contract BigBank is Bank {

    modifier depositAmountValid() {
        require(msg.value > 0.001 ether, "Deposit must be greater than 0.001 ETH");
        _;
    }

    // 重写存款函数，添加存款金额限制
    function deposit() public payable override depositAmountValid {
        super.deposit();  // 调用父类 Bank 合约中的 deposit 方法
    }

    // 管理员转移功能
    function setAdmin(address newAdmin) public onlyOwner {
        owner = newAdmin;
    }
}

contract Admin {
    address public owner;

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can perform this action");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    receive() external payable { }

    // adminWithdraw 函数：通过调用 IBank 的 withdraw 方法，提取 BigBank 合约中的资金
    function adminWithdraw(IBank bank) public onlyOwner {
        uint256 balance = address(bank).balance;
        bank.withdraw(balance, payable(address(this)));  // 从 BigBank 提取所有资金
    }
}
