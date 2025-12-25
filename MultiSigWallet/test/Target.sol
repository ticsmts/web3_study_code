// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract Target {
    uint256 public x;
    event Ping(address from, uint256 value, uint256 x);

    function setX(uint256 _x) external payable {
        x = _x;
        emit Ping(msg.sender, msg.value, _x);
    }

    receive() external payable {}
}
