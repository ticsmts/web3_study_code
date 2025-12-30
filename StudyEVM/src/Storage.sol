// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

contract Storage {
    uint256 value;

    function store(uint256 _value) external {
        value = _value;
    }

    function retrieve() external view returns (uint256) {
        return value;
    }
}
