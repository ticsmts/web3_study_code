// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title MockWETH
 * @notice 用于测试的WETH合约，支持deposit/withdraw / Mock WETH contract with deposit/withdraw support
 */
contract MockWETH {
    string public constant name = "Wrapped Ether";
    string public constant symbol = "WETH";
    uint8 public constant decimals = 18;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Deposit(address indexed dst, uint256 wad);
    event Withdrawal(address indexed src, uint256 wad);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /// @notice 存入ETH获得WETH / Deposit ETH to get WETH
    function deposit() public payable {
        balanceOf[msg.sender] += msg.value;
        emit Deposit(msg.sender, msg.value);
    }

    /// @notice 取出WETH获得ETH / Withdraw WETH to get ETH
    function withdraw(uint256 wad) public {
        require(balanceOf[msg.sender] >= wad, "WETH: insufficient balance");
        balanceOf[msg.sender] -= wad;
        payable(msg.sender).transfer(wad);
        emit Withdrawal(msg.sender, wad);
    }

    function totalSupply() public view returns (uint256) {
        return address(this).balance;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        return transferFrom(msg.sender, to, amount);
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public returns (bool) {
        if (from != msg.sender && allowance[from][msg.sender] != type(uint256).max) {
            require(allowance[from][msg.sender] >= amount, "WETH: insufficient allowance");
            allowance[from][msg.sender] -= amount;
        }
        require(balanceOf[from] >= amount, "WETH: insufficient balance");
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
        return true;
    }

    /// @notice 接收ETH自动转为WETH / Receive ETH and auto-convert to WETH
    receive() external payable {
        deposit();
    }
}
