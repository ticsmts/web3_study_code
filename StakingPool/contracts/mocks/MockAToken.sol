// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "../ZZToken.sol";

contract MockAToken is IERC20 {
    string public name = "Aave WETH";
    string public symbol = "aWETH";
    uint8 public immutable decimals = 18;

    uint256 public override totalSupply;
    mapping(address => uint256) public override balanceOf;
    mapping(address => mapping(address => uint256)) public override allowance;

    address public minter;

    constructor() {
        minter = msg.sender;
    }

    modifier onlyMinter() {
        require(msg.sender == minter, "MockAToken: not minter");
        _;
    }

    function setMinter(address newMinter) external onlyMinter {
        require(newMinter != address(0), "MockAToken: zero address");
        minter = newMinter;
    }

    function mint(address to, uint256 amount) external onlyMinter {
        require(to != address(0), "MockAToken: zero address");
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function burn(address from, uint256 amount) external onlyMinter {
        uint256 balance = balanceOf[from];
        require(balance >= amount, "MockAToken: balance");
        unchecked {
            balanceOf[from] = balance - amount;
        }
        totalSupply -= amount;
        emit Transfer(from, address(0), amount);
    }

    function transfer(address to, uint256 amount) external override returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external override returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external override returns (bool) {
        uint256 currentAllowance = allowance[from][msg.sender];
        require(currentAllowance >= amount, "MockAToken: allowance");
        unchecked {
            allowance[from][msg.sender] = currentAllowance - amount;
        }
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        require(to != address(0), "MockAToken: zero address");
        uint256 balance = balanceOf[from];
        require(balance >= amount, "MockAToken: balance");
        unchecked {
            balanceOf[from] = balance - amount;
        }
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
    }
}