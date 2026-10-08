// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @title BadBox
/// @notice WRONG way to upgrade — demonstrates storage collision
/// @dev If deployed behind a proxy that was using Box, this BREAKS everything
///      because the storage layout is different
contract BadBox {
    // Box had:   s_value (slot 0), s_owner (slot 1)
    // BadBox:    s_owner (slot 0), s_value (slot 1)  — REORDERED!

    address private s_owner;  // slot 0 — COLLIDES with Box's s_value!
    uint256 private s_value;  // slot 1 — COLLIDES with Box's s_owner!

    error BadBox__NotOwner();

    function initialize(address _owner, uint256 _value) external {
        s_owner = _owner;
        s_value = _value;
    }

    function setValue(uint256 newValue) external {
        if (msg.sender != s_owner) revert BadBox__NotOwner();
        s_value = newValue;
    }

    function getValue() external view returns (uint256) {
        return s_value;
    }

    function getOwner() external view returns (address) {
        return s_owner;
    }
}
