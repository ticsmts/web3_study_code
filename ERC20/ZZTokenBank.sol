// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/*
 编写一个 TokenBank 合约，可以将自己的 Token（BaseERC20 Token 版本，重命名为ZZ TOKEN） 存入到 TokenBank， 和从 TokenBank 取出。
    TokenBank 有两个方法：
    deposit() : 需要记录每个地址的存入数量；
    withdraw（）: 用户可以提取自己的之前存入的 token。
*/
contract ZZTOKEN {
    string public name;
    string public symbol;
    uint8 public decimals;

    uint256 public totalSupply;

    mapping (address => uint256) balances;

    mapping (address => mapping (address => uint256)) allowances;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor() {
        // write your code here
        // set name,symbol,decimals,totalSupply
        name = "ZZTOKEN";
        symbol = "ZZ";
        decimals = 18;
        totalSupply = 100000000 * 10 ** uint256(decimals);
        balances[msg.sender] = totalSupply;
        emit Transfer(address(0), msg.sender, totalSupply);
    }

    function balanceOf(address _owner) public view returns (uint256 balance) {
        // write your code here
        balance =  balances[_owner];
    }

    function transfer(address _to, uint256 _value) public returns (bool success) {
        // write your code here
        require(balances[msg.sender] >= _value, "ERC20: transfer amount exceeds balance");
        require(_to != address(0), "ERC20: transfer to the zero address");

        balances[msg.sender] -= _value;
        balances[_to] += _value;

        emit Transfer(msg.sender, _to, _value);
        return true;
    }

    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {
        // write your code here
        require(allowances[_from][msg.sender] >= _value, "ERC20: transfer amount exceeds allowance");
        require(balances[_from] >= _value, "ERC20: transfer amount exceeds balance");

        //_to地址不能为0地址
        require(_to != address(0), "ERC20: transfer to the zero address");

        balances[_from] -= _value;
        balances[_to] += _value;
        allowances[_from][msg.sender] -= _value;
        emit Transfer(_from, _to, _value);
        return true;
    }

    function approve(address _spender, uint256 _value) public returns (bool success) {
        // write your code here
        allowances[msg.sender][_spender] = _value;

        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    function allowance(address _owner, address _spender) public view returns (uint256 remaining) {
        // write your code here
        remaining = allowances[_owner][_spender];
    }
}


interface IERC20Minimal {
    function transfer(address to, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function balanceOf(address owner) external view returns (uint256);
}

contract TokenBank {
    IERC20Minimal public immutable token;

    mapping(address => uint256) private _deposits;
    uint256 public totalDeposits;

    // 简单防重入锁
    bool private _locked;
    modifier nonReentrant() {
        require(!_locked, "ReentrancyGuard: reentrant call");
        _locked = true;
        _;
        _locked = false;
    }

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);

    constructor(address tokenAddress) {
        require(tokenAddress != address(0), "TokenBank: token is zero address");
        token = IERC20Minimal(tokenAddress);
    }

    // 查看某个地址在银行的存款记录
    function depositedOf(address user) external view returns (uint256) {
        return _deposits[user];
    }

    // 存入：把用户“已授权给银行的额度”一次性全部存入
    function deposit() external nonReentrant returns (bool) {
        uint256 amount = token.allowance(msg.sender, address(this));
        require(amount > 0, "TokenBank: allowance is zero");

        bool ok = token.transferFrom(msg.sender, address(this), amount);
        require(ok, "TokenBank: transferFrom failed");

        _deposits[msg.sender] += amount;
        totalDeposits += amount;

        emit Deposit(msg.sender, amount);
        return true;
    }

    // 取出：把用户之前存入的全部取出
    function withdraw() external nonReentrant returns (bool) {
        uint256 amount = _deposits[msg.sender];
        require(amount > 0, "TokenBank: no deposits");

        // 先清零再转账，避免重入风险
        _deposits[msg.sender] = 0;
        totalDeposits -= amount;

        bool ok = token.transfer(msg.sender, amount);
        require(ok, "TokenBank: transfer failed");

        emit Withdraw(msg.sender, amount);
        return true;
    }
}
