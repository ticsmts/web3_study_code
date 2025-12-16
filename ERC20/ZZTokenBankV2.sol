// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/*
扩展 ERC20 合约 ，添加一个有hook 功能的转账函数，如函数名为：transferWithCallback ，在转账时，如果目标地址是合约地址的话，调用目标地址的 tokensReceived() 方法。
    继承 TokenBank 编写 TokenBankV2，支持存入扩展的 ERC20 Token，用户可以直接调用 transferWithCallback 将扩展的 ERC20 Token 存入到 TokenBankV2 中。
    TokenBankV2 需要实现 tokensReceived 来实现存款记录工作。

 理解：
 两个版本之间的区别是:
    1. 原来的版本是在用户Token合约中授权，然后在TokenBank中调用deposit()存款方法，执行Token的transfer()更新Token账本，然后更新TokenBank账本。

    用户层面: 1. Token.approve() 2. TokenBank.deposit(); 两步操作
    代码层面: Token.approve() -> TokenBank.deposit(); -> Token.transferFrom(user, bank, amount);

    2. 现在的版本是不需要授权，因为用户是直接在Token合约中调用transfer()方法，不需要approve TokenBank合约来transfer自己的token。
    直接在Token合约中实现了转账给TokenBank（通过回调TokenBank的tokensReceived方法通知TokenBank更新账本），并且两个账本都会被更新。

    对用户层面来说，Token.transferWithCallback() 一步操作
    代码层面: Token.transferWithCallback() -> Token.transfer(bank, amount) -> TokenBankV2.tokensReceived()
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

    //判断地址是否为合约地址
    function _isContract(address account) internal view returns (bool) {
        return account.code.length > 0;
    }

    //带hook的转账方法
    function transferWithCallback(address _to, uint256 _value) external returns (bool) {
        // 1) 先做正常 ERC20 转账
        bool ok = transfer(_to, _value);
        require(ok, "ERC20: transfer failed");

        // 2) 如果目标是合约地址，回调 tokensReceived
        if (_isContract(_to)) {
            ITokenReceiver(_to).tokensReceived(msg.sender, _value);
        }

        return true;
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

    mapping(address => uint256) internal _deposits;
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

interface ITokenReceiver {
    function tokensReceived(address from, uint256 amount) external;
}


contract TokenBankV2 is TokenBank, ITokenReceiver {
    constructor(address tokenAddress) TokenBank(tokenAddress) {}

    // 用户直接调用 token.transferWithCallback(bank, amount)
    // token 转账完成后会回调到这里
    function tokensReceived(address from, uint256 amount) external override nonReentrant {
        // 1) 只接受“本银行绑定的 token”回调，防止别人伪造调用
        require(msg.sender == address(token), "TokenBankV2: only token can callback");
        require(amount > 0, "TokenBankV2: amount is zero");

        // 2) 记账
        _deposits[from] += amount;
        totalDeposits += amount;

        emit Deposit(from, amount);
    }
}
