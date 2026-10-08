// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";

/// @title ERC20Mock
/// @notice Minimal mintable ERC-20 for tests and local deploys.
/// @dev `mint` is permissionless ON PURPOSE: this is a mock, not a token design.
///      Never copy this into production.
contract ERC20Mock is ERC20 {
    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {}

    /// @notice Anyone can mint. Test-only convenience.
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
