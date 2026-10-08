// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @title BoxV2
/// @notice Version 2 of Box — adds increment function, inherits v1 storage layout
/// @dev CRITICAL: storage layout must match Box.sol exactly!
contract BoxV2 {
    // MUST MATCH Box.sol layout exactly!
    uint256 private s_value;      // slot 0
    address private s_owner;      // slot 1

    // NEW in V2: only added at the end
    bool private s_initialized;   // slot 2

    error Box__NotOwner();
    error Box__ZeroValue();
    error Box__AlreadyInitialized();

    event ValueChanged(uint256 indexed oldValue, uint256 indexed newValue);
    event Incremented(uint256 indexed newValue);

    /// @notice Re-initialize after upgrade (NOT the original initialize)
    function reInitialize(uint256 initialValue) external {
        if (s_initialized) revert Box__AlreadyInitialized();
        s_initialized = true;
        uint256 oldValue = s_value;
        s_value = initialValue;
        emit ValueChanged(oldValue, initialValue);
    }

    /// @notice Set a new value (same as v1)
    function setValue(uint256 newValue) external {
        if (msg.sender != s_owner) revert Box__NotOwner();
        if (newValue == 0) revert Box__ZeroValue();

        uint256 oldValue = s_value;
        s_value = newValue;
        emit ValueChanged(oldValue, newValue);
    }

    /// @notice NEW in V2: increment value by 1
    function increment() external {
        if (msg.sender != s_owner) revert Box__NotOwner();
        s_value += 1;
        emit Incremented(s_value);
    }

    /// @notice Get the current value (same as v1)
    function getValue() external view returns (uint256) {
        return s_value;
    }

    /// @notice Get the owner (same as v1)
    function getOwner() external view returns (address) {
        return s_owner;
    }
}
