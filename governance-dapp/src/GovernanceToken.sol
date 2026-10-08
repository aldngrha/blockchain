// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "openzeppelin-contracts/token/ERC20/extensions/ERC20Permit.sol";
import {ERC20Votes} from "openzeppelin-contracts/token/ERC20/extensions/ERC20Votes.sol";
import {Nonces} from "openzeppelin-contracts/utils/Nonces.sol";

/// @title GovernanceToken - ERC-20 with voting checkpoints for the Governor.
/// @notice Fixed supply, no owner, no minter. Voting power is NOT balance:
///         it only counts after the holder calls delegate() (to self or anyone else).
///         Checkpoints are block-number based (ERC-6372), which the Governor uses
///         to measure votes at the proposal snapshot.
contract GovernanceToken is ERC20, ERC20Permit, ERC20Votes {
    uint256 public constant INITIAL_SUPPLY = 1_000_000e18;

    constructor() ERC20("Governance Token", "GT") ERC20Permit("Governance Token") {
        _mint(msg.sender, INITIAL_SUPPLY);
    }

    // The following functions are overrides required by Solidity.

    /// @dev ERC20Votes hooks token movements into the checkpoint system, so the
    ///      internal _update of both bases must be merged here.
    function _update(address from, address to, uint256 value) internal override(ERC20, ERC20Votes) {
        super._update(from, to, value);
    }

    /// @dev ERC20Permit and Votes both inherit Nonces, so the lookup must be resolved.
    function nonces(address owner) public view override(ERC20Permit, Nonces) returns (uint256) {
        return super.nonces(owner);
    }
}
