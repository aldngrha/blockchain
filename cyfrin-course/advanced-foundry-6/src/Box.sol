// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @title Box
/// @notice Version 1 of a simple storage contract — upgradeable via proxy
/// @dev This contract is MEANT to be deployed behind a proxy, not directly
contract Box {
    // IMPORTANT: Storage layout must be preserved across upgrades!
    // New variables ONLY at the end, NEVER remove or reorder existing ones
    uint256 private s_value;
    address private s_owner;

    error Box__NotOwner();
    error Box__ZeroValue();

    event ValueChanged(uint256 indexed oldValue, uint256 indexed newValue);

    /// @notice Initialize (called by proxy, not constructor)
    function initialize(uint256 initialValue) external {
        // Guard: prevent re-initialization
        if (s_owner != address(0)) revert Box__ZeroValue();
        s_owner = msg.sender;
        s_value = initialValue;
    }

    /// @notice Set a new value
    function setValue(uint256 newValue) external {
        if (msg.sender != s_owner) revert Box__NotOwner();
        if (newValue == 0) revert Box__ZeroValue();

        uint256 oldValue = s_value;
        s_value = newValue;
        emit ValueChanged(oldValue, newValue);
    }

    /// @notice Get the current value
    function getValue() external view returns (uint256) {
        return s_value;
    }

    /// @notice Get the owner
    function getOwner() external view returns (address) {
        return s_owner;
    }
}
