// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC165} from "./IERC165.sol";
import {Client} from "../libraries/Client.sol";

/// @title IAny2EVMMessageReceiver
/// @notice The interface CCIP uses to check whether a contract wants to receive messages.
/// @dev Mirrors the Chainlink CCIP v1.5.1 API reference. The Router calls
///      `supportsInterface(type(IAny2EVMMessageReceiver).interfaceId)` before delivering:
///      - returns true  -> tokens are transferred AND ccipReceive is called atomically
///      - returns false or reverts -> only tokens are transferred
///      - address has no code -> only tokens are transferred
interface IAny2EVMMessageReceiver is IERC165 {
  /// @notice Called by the CCIP Router on the destination chain.
  /// @dev If this reverts, the token transfers in the same message also revert.
  function ccipReceive(Client.Any2EVMMessage calldata message) external;
}
