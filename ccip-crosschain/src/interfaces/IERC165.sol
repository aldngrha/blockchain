// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IERC165
/// @notice Minimal ERC-165 interface, defined locally so the project needs no external
///         dependency. Matches EIP-165 exactly.
interface IERC165 {
  function supportsInterface(bytes4 interfaceId) external view returns (bool);
}
