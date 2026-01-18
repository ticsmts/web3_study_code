// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "./interfaces/ITokenReceiver.sol";

/**
 * @title ZZTOKEN
 * @dev ERC20 token with transferWithCallback for ZZNFTMarketV3
 */
contract ZZTOKEN {
    string public name;
    string public symbol;
    uint8 public decimals;

    uint256 public totalSupply;

    mapping(address => uint256) balances;
    mapping(address => mapping(address => uint256)) allowances;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );

    constructor() {
        name = "ZZTOKEN";
        symbol = "ZZ";
        decimals = 18;
        totalSupply = 100000000 * 10 ** uint256(decimals);
        balances[msg.sender] = totalSupply;
        emit Transfer(address(0), msg.sender, totalSupply);
    }

    function balanceOf(address _owner) public view returns (uint256 balance) {
        balance = balances[_owner];
    }

    function transfer(
        address _to,
        uint256 _value
    ) public returns (bool success) {
        require(
            balances[msg.sender] >= _value,
            "ERC20: transfer amount exceeds balance"
        );
        require(_to != address(0), "ERC20: transfer to the zero address");

        balances[msg.sender] -= _value;
        balances[_to] += _value;

        emit Transfer(msg.sender, _to, _value);
        return true;
    }

    function transferFrom(
        address _from,
        address _to,
        uint256 _value
    ) public returns (bool success) {
        require(
            allowances[_from][msg.sender] >= _value,
            "ERC20: transfer amount exceeds allowance"
        );
        require(
            balances[_from] >= _value,
            "ERC20: transfer amount exceeds balance"
        );
        require(_to != address(0), "ERC20: transfer to the zero address");

        balances[_from] -= _value;
        balances[_to] += _value;
        allowances[_from][msg.sender] -= _value;
        emit Transfer(_from, _to, _value);
        return true;
    }

    function approve(
        address _spender,
        uint256 _value
    ) public returns (bool success) {
        allowances[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    function allowance(
        address _owner,
        address _spender
    ) public view returns (uint256 remaining) {
        remaining = allowances[_owner][_spender];
    }

    function _isContract(address account) internal view returns (bool) {
        return account.code.length > 0;
    }

    // Token transfer with callback for single-transaction purchases
    function transferWithCallback(
        address _to,
        uint256 _value,
        bytes memory data
    ) public returns (bool) {
        bool ok = transfer(_to, _value);
        require(ok, "ERC20: transfer failed");

        if (_isContract(_to)) {
            bool handled = ITokenReceiver(_to).tokensReceived(
                msg.sender, // operator
                msg.sender, // from
                _value,
                data
            );
            require(handled, "ERC20: tokensReceived failed");
        }
        return true;
    }
}
