// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "./interfaces/ITokenReceiver.sol";


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

    /*
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
    */

    // 带hook的转账方法，添加data参数，需要传递NFT的tokenId参数。
    function transferWithCallback(address _to, uint256 _value, bytes memory data) public returns (bool) {
        bool ok = transfer(_to, _value);
        require(ok, "ERC20: transfer failed");

        if (_isContract(_to)) {
            bool handled = ITokenReceiver(_to).tokensReceived(
                msg.sender,      // operator
                msg.sender,      // from（这版就是调用者自己付款）
                _value,
                data
            );
            require(handled, "ERC20: tokensReceived failed");
        }
    }
}

