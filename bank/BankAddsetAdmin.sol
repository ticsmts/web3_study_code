// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

//sepolia部署后合约地址: 0xa9cce591bada33479453f34ec06c44df2255d0b6
contract Bank {
    // 管理员
    address public admin;

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
    event AdminChanged(address indexed oldAdmin, address indexed newAdmin);

    // 只允许管理员执行
    modifier onlyAdmin() {
        require(msg.sender == admin, "Not admin");
        _;
    }

    constructor() {
        admin = msg.sender;
    }

    /* ========== 管理员管理 ========== */

    /// @notice 管理员转移
    function setAdmin(address newAdmin) external onlyAdmin {
        require(newAdmin != address(0), "zero address");
        address oldAdmin = admin;
        admin = newAdmin;
        emit AdminChanged(oldAdmin, newAdmin);
    }

    /* ========== 存款逻辑 ========== */

    receive() external payable {
        _deposit(msg.sender, msg.value);
    }

    function deposit() external payable {
        require(msg.value > 0, "No ETH sent");
        _deposit(msg.sender, msg.value);
    }

    function _deposit(address user, uint256 amount) internal {
        balances[user] += amount;
        emit Deposit(user, amount, balances[user]);
        _updateTopDepositors(user);
    }

    function getMyBalance() external view returns (uint256) {
        return balances[msg.sender];
    }

    function getBalance(address user) external view returns (uint256) {
        return balances[user];
    }

    /* ========== 管理员提现 ========== */

    function withdraw(uint256 amount, address payable to) external onlyAdmin {
        require(amount > 0, "Amount must be > 0");
        require(address(this).balance >= amount, "Insufficient balance");

        (bool ok, ) = to.call{value: amount}("");
        require(ok, "ETH transfer failed");

        emit Withdraw(to, amount);
    }

    /* ========== Top 3 存款用户 ========== */

    function getTopDepositors() external view returns (TopDepositor[3] memory) {
        return topDepositors;
    }

    function _updateTopDepositors(address user) internal {
        uint256 userBalance = balances[user];

        // 已在榜单：更新后重新排序
        for (uint256 i = 0; i < topDepositors.length; i++) {
            if (topDepositors[i].user == user) {
                topDepositors[i].amount = userBalance;
                _reorderTopDepositors();
                return;
            }
        }

        // 尝试进入榜单
        for (uint256 i = 0; i < topDepositors.length; i++) {
            if (userBalance > topDepositors[i].amount) {
                for (uint256 j = topDepositors.length - 1; j > i; j--) {
                    topDepositors[j] = topDepositors[j - 1];
                }
                topDepositors[i] = TopDepositor(user, userBalance);
                break;
            }
        }
    }

    function _reorderTopDepositors() internal {
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
