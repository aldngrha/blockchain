// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Client} from "../libraries/Client.sol";

/// @title IRouterClient
/// @notice The subset of the CCIP Router that a sender contract needs.
/// @dev Mirrors the Chainlink CCIP v1.5.1 API reference
///      (docs.chain.link/ccip/v1/evm/api-reference/v1.5.1/i-router-client).
interface IRouterClient {
  error InsufficientFeeTokenAmount();
  error InvalidMsgValue();
  error UnsupportedDestinationChain(uint64 destChainSelector);

  /// @notice Send a CCIP message to another chain.
  /// @dev If msg.value exceeds the required fee, the overpayment is accepted and NOT refunded.
  ///      Use getFee() first and send exactly that amount.
  /// @param destinationChainSelector CCIP chain selector, not the EVM chain id.
  /// @param message The message to send.
  /// @return messageId Identifier of the sent message.
  function ccipSend(
    uint64 destinationChainSelector,
    Client.EVM2AnyMessage calldata message
  ) external payable returns (bytes32);

  /// @notice Fee required to deliver a message, denominated in message.feeToken.
  function getFee(
    uint64 destinationChainSelector,
    Client.EVM2AnyMessage memory message
  ) external view returns (uint256 fee);

  /// @notice Whether the given chain selector can be used as a destination.
  function isChainSupported(uint64 destChainSelector) external view returns (bool supported);
}
