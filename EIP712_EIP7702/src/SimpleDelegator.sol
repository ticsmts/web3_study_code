// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title SimpleDelegator
/// @notice Minimal EIP-7702 compatible batch executor
/// @dev When an EOA delegates to this contract via EIP-7702, it can execute
/// batch transactions as if the EOA were a smart contract.
contract SimpleDelegator {
    /// @notice Single call struct
    struct Call {
        address target; // Target contract to call
        uint256 value; // ETH value to send
        bytes data; // Calldata
    }

    /// @notice Execute a batch of calls atomically
    /// @dev All calls must succeed or the entire transaction reverts
    /// @param calls Array of calls to execute
    function execute(Call[] calldata calls) external payable {
        for (uint256 i = 0; i < calls.length; i++) {
            (bool success, bytes memory result) = calls[i].target.call{
                value: calls[i].value
            }(calls[i].data);
            if (!success) {
                // Bubble up the revert reason
                if (result.length > 0) {
                    assembly {
                        revert(add(result, 32), mload(result))
                    }
                }
                revert("SimpleDelegator: call failed");
            }
        }
    }

    /// @notice Execute a single call
    /// @param target Target contract address
    /// @param value ETH value to send
    /// @param data Calldata
    function executeSingle(
        address target,
        uint256 value,
        bytes calldata data
    ) external payable returns (bytes memory) {
        (bool success, bytes memory result) = target.call{value: value}(data);
        if (!success) {
            if (result.length > 0) {
                assembly {
                    revert(add(result, 32), mload(result))
                }
            }
            revert("SimpleDelegator: call failed");
        }
        return result;
    }

    /// @notice Receive ETH
    receive() external payable {}
}
