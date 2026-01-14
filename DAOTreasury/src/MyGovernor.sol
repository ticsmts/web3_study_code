// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/governance/Governor.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorSettings.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorVotesQuorumFraction.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorTimelockControl.sol";

/**
 * @title MyGovernor
 * @author DAO Treasury Project
 * @notice DAO governance contract for managing treasury proposals
 * @dev Combines multiple OpenZeppelin Governor modules:
 *
 * Modules included:
 * - Governor: Base governance with proposal lifecycle
 * - GovernorSettings: Configurable votingDelay, votingPeriod, proposalThreshold
 * - GovernorVotes: Voting power from ERC20Votes token
 * - GovernorCountingSimple: For/Against/Abstain vote counting
 * - GovernorVotesQuorumFraction: Quorum as percentage of total supply
 * - GovernorTimelockControl: Execution through timelock delay
 *
 * Proposal lifecycle:
 * 1. propose() - Create proposal
 * 2. Wait for votingDelay (blocks)
 * 3. castVote() - Vote during votingPeriod
 * 4. Wait for votingPeriod to end
 * 5. queue() - Queue in timelock if successful
 * 6. Wait for timelock delay
 * 7. execute() - Execute the proposal
 */
contract MyGovernor is
    Governor,
    GovernorSettings,
    GovernorCountingSimple,
    GovernorVotes,
    GovernorVotesQuorumFraction,
    GovernorTimelockControl
{
    /**
     * @notice Initialize the Governor
     * @param _token Governance token with ERC20Votes interface
     * @param _timelock Timelock controller for delayed execution
     * @param _votingDelay Delay (in blocks) before voting starts after proposal
     * @param _votingPeriod Duration (in blocks) of voting period
     * @param _proposalThreshold Minimum tokens required to create proposal
     * @param _quorumPercentage Quorum as percentage of total supply (e.g., 4 = 4%)
     */
    constructor(
        IVotes _token,
        TimelockController _timelock,
        uint48 _votingDelay,
        uint32 _votingPeriod,
        uint256 _proposalThreshold,
        uint256 _quorumPercentage
    )
        Governor("MyGovernor")
        GovernorSettings(_votingDelay, _votingPeriod, _proposalThreshold)
        GovernorVotes(_token)
        GovernorVotesQuorumFraction(_quorumPercentage)
        GovernorTimelockControl(_timelock)
    {}

    // ============ Required Overrides ============

    /// @dev Returns the delay before voting on a proposal starts
    function votingDelay()
        public
        view
        override(Governor, GovernorSettings)
        returns (uint256)
    {
        return super.votingDelay();
    }

    /// @dev Returns the duration of the voting period
    function votingPeriod()
        public
        view
        override(Governor, GovernorSettings)
        returns (uint256)
    {
        return super.votingPeriod();
    }

    /// @dev Returns the quorum for a timepoint
    function quorum(
        uint256 blockNumber
    )
        public
        view
        override(Governor, GovernorVotesQuorumFraction)
        returns (uint256)
    {
        return super.quorum(blockNumber);
    }

    /// @dev Returns the state of a proposal
    function state(
        uint256 proposalId
    )
        public
        view
        override(Governor, GovernorTimelockControl)
        returns (ProposalState)
    {
        return super.state(proposalId);
    }

    /// @dev Check if proposal needs to be queued in timelock
    function proposalNeedsQueuing(
        uint256 proposalId
    ) public view override(Governor, GovernorTimelockControl) returns (bool) {
        return super.proposalNeedsQueuing(proposalId);
    }

    /// @dev Returns the minimum number of tokens required to create a proposal
    function proposalThreshold()
        public
        view
        override(Governor, GovernorSettings)
        returns (uint256)
    {
        return super.proposalThreshold();
    }

    /// @dev Internal function to queue operations in timelock
    function _queueOperations(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) returns (uint48) {
        return
            super._queueOperations(
                proposalId,
                targets,
                values,
                calldatas,
                descriptionHash
            );
    }

    /// @dev Internal function to execute operations after timelock delay
    function _executeOperations(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) {
        super._executeOperations(
            proposalId,
            targets,
            values,
            calldatas,
            descriptionHash
        );
    }

    /// @dev Internal function to cancel operations
    function _cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) returns (uint256) {
        return super._cancel(targets, values, calldatas, descriptionHash);
    }

    /// @dev Returns the executor address (timelock)
    function _executor()
        internal
        view
        override(Governor, GovernorTimelockControl)
        returns (address)
    {
        return super._executor();
    }
}
