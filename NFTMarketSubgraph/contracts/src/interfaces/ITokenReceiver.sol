// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

interface ITokenReceiver {
    function tokensReceived(
        address operator,
        address from,
        uint256 value,
        bytes calldata data
    ) external returns (bool);
}
