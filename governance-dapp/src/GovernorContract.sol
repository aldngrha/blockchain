// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Governor} from "openzeppelin-contracts/governance/Governor.sol";
import {GovernorSettings} from "openzeppelin-contracts/governance/extensions/GovernorSettings.sol";
import {GovernorCountingSimple} from "openzeppelin-contracts/governance/extensions/GovernorCountingSimple.sol";
import {GovernorVotes} from "openzeppelin-contracts/governance/extensions/GovernorVotes.sol";
import {
    GovernorVotesQuorumFraction
} from "openzeppelin-contracts/governance/extensions/GovernorVotesQuorumFraction.sol";
import {GovernorTimelockControl} from "openzeppelin-contracts/governance/extensions/GovernorTimelockControl.sol";
import {TimelockController} from "openzeppelin-contracts/governance/TimelockController.sol";
import {IVotes} from "openzeppelin-contracts/governance/utils/IVotes.sol";

/// @title GovernorContract - OZ Governor wired to a TimelockController.
/// @notice Counting: simple for/against/abstain (Bravo ordering: Against=0, For=1, Abstain=2).
///         Quorum: percentage of the PAST total supply at the proposal snapshot, not current.
///         Execution: every successful proposal must be queued into the timelock first,
///         then executed after the timelock delay. Proposal threshold is 0: any holder
///         may propose (voting weight at snapshot still decides).
contract GovernorContract is
    Governor,
    GovernorSettings,
    GovernorCountingSimple,
    GovernorVotesQuorumFraction,
    GovernorTimelockControl
{
    constructor(
        IVotes _votes,
        TimelockController _timelock,
        uint256 _quorumPercentage,
        uint256 _votingDelay,
        uint256 _votingPeriod
    )
        Governor("Governance DApp Governor")
        GovernorSettings(uint48(_votingDelay), uint32(_votingPeriod), 0) // proposalThreshold = 0
        GovernorCountingSimple()
        GovernorVotes(_votes)
        GovernorVotesQuorumFraction(_quorumPercentage)
        GovernorTimelockControl(_timelock)
    {}

    // The following functions are overrides required by Solidity.

    function state(uint256 proposalId) public view override(Governor, GovernorTimelockControl) returns (ProposalState) {
        return super.state(proposalId);
    }

    function proposalNeedsQueuing(uint256 proposalId)
        public
        view
        override(Governor, GovernorTimelockControl)
        returns (bool)
    {
        return super.proposalNeedsQueuing(proposalId);
    }

    function proposalThreshold() public view override(Governor, GovernorSettings) returns (uint256) {
        return super.proposalThreshold();
    }

    function _queueOperations(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) returns (uint48) {
        return super._queueOperations(proposalId, targets, values, calldatas, descriptionHash);
    }

    function _executeOperations(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) {
        super._executeOperations(proposalId, targets, values, calldatas, descriptionHash);
    }

    function _cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) returns (uint256) {
        return super._cancel(targets, values, calldatas, descriptionHash);
    }

    function _executor() internal view override(Governor, GovernorTimelockControl) returns (address) {
        return super._executor();
    }
}
