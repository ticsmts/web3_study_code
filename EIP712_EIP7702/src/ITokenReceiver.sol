// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title ITokenReceiver
 * @notice Interface for contracts that want to receive token callbacks
 * @dev Implement this interface to handle token transfers with callbacks
 */
interface ITokenReceiver {
    /**
     * @notice Called by token contract after a transferWithCallback
     * @param operator The address that initiated the transfer
     * @param from The address tokens are transferred from
     * @param value Amount of tokens transferred
     * @param data Additional data passed with the transfer
     * @return bool True if the callback was handled successfully
     */
    function tokensReceived(
        address operator,
        address from,
        uint256 value,
        bytes calldata data
    ) external returns (bool);
}
