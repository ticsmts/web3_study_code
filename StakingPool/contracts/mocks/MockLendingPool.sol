// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "../ZZToken.sol";

interface IMintableToken is IERC20 {
    function mint(address to, uint256 amount) external;
    function burn(address from, uint256 amount) external;
}

contract MockLendingPool {
    mapping(address => mapping(address => uint256)) public deposits;
    mapping(address => address) public aTokens;
    address public owner;

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "MockLendingPool: not owner");
        _;
    }

    function setAToken(address asset, address aToken) external onlyOwner {
        require(asset != address(0), "MockLendingPool: zero asset");
        require(aToken != address(0), "MockLendingPool: zero aToken");
        aTokens[asset] = aToken;
    }

    function supply(address asset, uint256 amount, address onBehalfOf, uint16) external {
        require(amount > 0, "MockLendingPool: zero amount");
        address aToken = aTokens[asset];
        require(aToken != address(0), "MockLendingPool: aToken not set");
        bool ok = IERC20(asset).transferFrom(msg.sender, address(this), amount);
        require(ok, "MockLendingPool: transfer failed");
        deposits[asset][onBehalfOf] += amount;
        IMintableToken(aToken).mint(onBehalfOf, amount);
    }

    function withdraw(address asset, uint256 amount, address to) external returns (uint256) {
        uint256 available = deposits[asset][msg.sender];
        require(available >= amount, "MockLendingPool: insufficient");
        address aToken = aTokens[asset];
        require(aToken != address(0), "MockLendingPool: aToken not set");
        unchecked {
            deposits[asset][msg.sender] = available - amount;
        }
        IMintableToken(aToken).burn(msg.sender, amount);
        bool ok = IERC20(asset).transfer(to, amount);
        require(ok, "MockLendingPool: transfer failed");
        return amount;
    }

    function accrue(address asset, address onBehalfOf, uint256 amount) external onlyOwner {
        require(amount > 0, "MockLendingPool: zero amount");
        address aToken = aTokens[asset];
        require(aToken != address(0), "MockLendingPool: aToken not set");
        IMintableToken(aToken).mint(onBehalfOf, amount);
    }
}
