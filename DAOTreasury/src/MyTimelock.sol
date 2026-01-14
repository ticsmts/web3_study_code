// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/governance/TimelockController.sol";

/**
 * @title MyTimelock
 * @author DAO Treasury Project
 * @notice Timelock controller for DAO governance execution delay
 * @dev Wraps OpenZeppelin TimelockController for deployment convenience
 *
 * The Timelock enforces a delay between when a proposal passes and when it can
 * be executed. This gives users time to:
 * - Exit the system if they disagree with a passed proposal
 * - Detect and respond to malicious proposals
 *
 * Role assignments:
 * - PROPOSER_ROLE: Only Governor contract can queue proposals
 * - EXECUTOR_ROLE: address(0) means anyone can execute (more decentralized)
 * - CANCELLER_ROLE: Governor can cancel pending proposals
 * - DEFAULT_ADMIN_ROLE: Should be renounced after setup for minimum privilege
 */
contract MyTimelock is TimelockController {
    /**
     * @notice Initialize the Timelock
     * @param minDelay Minimum delay (in seconds) before executed operations
     * @param proposers Addresses with PROPOSER_ROLE (typically Governor)
     * @param executors Addresses with EXECUTOR_ROLE (address(0) = anyone)
     * @param admin Address with DEFAULT_ADMIN_ROLE (should renounce after setup)
     */
    constructor(
        uint256 minDelay,
        address[] memory proposers,
        address[] memory executors,
        address admin
    ) TimelockController(minDelay, proposers, executors, admin) {}
}
