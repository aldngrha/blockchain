// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IRouterClient} from "../../src/interfaces/IRouterClient.sol";
import {Client} from "../../src/libraries/Client.sol";
import {IAny2EVMMessageReceiver} from "../../src/interfaces/IAny2EVMMessageReceiver.sol";

/// @title MockRouter
/// @notice A local stand-in for the CCIP Router that can deliver messages in the same
///         transaction, so the full sender -> router -> receiver path is testable on one chain.
/// @dev What it does NOT model, and why that matters:
///      - No fee market. `getFee` returns a fixed value set at construction.
///      - No cross-chain delay, no off-chain DON, no RMN.
///      - No token transfers. `tokenAmounts` must be empty.
///      A test against this mock proves the application logic, not CCIP itself.
contract MockRouter is IRouterClient {
  /// @notice Chain selector that represents "the other chain" in local tests.
  uint64 public immutable remoteChainSelector;

  /// @notice Fixed fee returned by getFee.
  uint256 public fee;

  /// @notice Whether the remote chain is reported as supported.
  bool public supported = true;

  /// @notice Chain selector reported as the source on delivered messages.
  /// @dev Lets a test simulate a message that claims to originate from a different chain,
  ///      which is what the receiver's per-chain allowlist must defend against.
  uint64 public sourceChainSelectorForDelivery;

  /// @notice Receiver registered for the remote chain, delivered to on ccipSend.
  address public receiverOnRemoteChain;

  /// @notice Messages sent, in order.
  bytes32[] public sentMessageIds;

  /// @notice Nonce used to build deterministic message ids.
  uint256 public nonce;

  event CCIPMessageSent(
    uint64 indexed destinationChainSelector,
    bytes32 indexed messageId,
    address indexed receiver,
    bytes data,
    uint256 fee
  );

  error ReceiverNotRegistered(uint64 destChainSelector);
  error TokensNotSupported();
  error FeeNotPaid(uint256 required, uint256 provided);

  constructor(uint64 remoteChainSelector_, uint256 fee_) {
    remoteChainSelector = remoteChainSelector_;
    sourceChainSelectorForDelivery = remoteChainSelector_;
    fee = fee_;
  }

  /// @notice Change the chain selector reported as the source on delivered messages.
  function setSourceChainSelectorForDelivery(uint64 selector) external {
    sourceChainSelectorForDelivery = selector;
  }

  /// @notice Point the mock at the receiver that plays the role of "destination chain contract".
  function setReceiverOnRemoteChain(address receiver) external {
    receiverOnRemoteChain = receiver;
  }

  /// @notice Change the fee returned by getFee.
  function setFee(uint256 fee_) external {
    fee = fee_;
  }

  /// @notice Toggle whether the remote chain is reported as supported.
  function setSupported(bool supported_) external {
    supported = supported_;
  }

  /// @inheritdoc IRouterClient
  function isChainSupported(uint64 destChainSelector) external view returns (bool) {
    return supported && destChainSelector == remoteChainSelector;
  }

  /// @inheritdoc IRouterClient
  function getFee(
    uint64 destChainSelector,
    Client.EVM2AnyMessage memory message
  ) external view returns (uint256) {
    _checkDestination(destChainSelector);
    if (message.tokenAmounts.length != 0) revert TokensNotSupported();
    return fee;
  }

  /// @inheritdoc IRouterClient
  /// @dev Delivers synchronously to `receiverOnRemoteChain` to simulate the destination call.
  function ccipSend(
    uint64 destChainSelector,
    Client.EVM2AnyMessage calldata message
  ) external payable returns (bytes32) {
    _checkDestination(destChainSelector);
    if (message.tokenAmounts.length != 0) revert TokensNotSupported();
    if (msg.value < fee) revert FeeNotPaid(fee, msg.value);

    address receiver = abi.decode(message.receiver, (address));
    if (receiver != receiverOnRemoteChain) revert ReceiverNotRegistered(destChainSelector);

    bytes32 messageId = keccak256(abi.encode(destChainSelector, receiver, message.data, nonce++));
    sentMessageIds.push(messageId);

    emit CCIPMessageSent(destChainSelector, messageId, receiver, message.data, fee);

    // Deliver on the "destination chain". sender is abi.encode of this mock's caller,
    // which is what a real CCIP Router reports as the source contract.
    Client.Any2EVMMessage memory inbound = Client.Any2EVMMessage({
      messageId: messageId,
      sourceChainSelector: sourceChainSelectorForDelivery,
      sender: abi.encode(msg.sender),
      data: message.data,
      destTokenAmounts: new Client.EVMTokenAmount[](0)
    });

    IAny2EVMMessageReceiver(receiver).ccipReceive(inbound);

    return messageId;
  }

  /// @notice Number of messages sent.
  function sentCount() external view returns (uint256) {
    return sentMessageIds.length;
  }

  function _checkDestination(uint64 destChainSelector) internal view {
    if (!supported || destChainSelector != remoteChainSelector) {
      revert UnsupportedDestinationChain(destChainSelector);
    }
  }
}
