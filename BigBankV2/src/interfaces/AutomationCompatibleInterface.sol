// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title AutomationCompatibleInterface
 * @notice Minimal interface for Chainlink Automation compatibility
 * @dev This is a local copy to avoid installing the full Chainlink library
 * @dev Original: @chainlink/contracts/src/v0.8/automation/AutomationCompatible.sol
 */
interface AutomationCompatibleInterface {
    /**
     * @notice Called by Chainlink Automation nodes to check if upkeep is needed
     * @param checkData Optional data passed to the contract
     * @return upkeepNeeded Whether the upkeep should be performed
     * @return performData Data to pass to performUpkeep if upkeepNeeded is true
     */
    function checkUpkeep(
        bytes calldata checkData
    ) external returns (bool upkeepNeeded, bytes memory performData);

    /**
     * @notice Called by Chainlink Automation nodes when upkeep is needed
     * @param performData Data returned by checkUpkeep
     */
    function performUpkeep(bytes calldata performData) external;
}
