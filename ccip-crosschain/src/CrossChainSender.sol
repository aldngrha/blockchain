// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IRouterClient} from "./interfaces/IRouterClient.sol";
import {Client} from "./libraries/Client.sol";

/// @title CrossChainSender
/// @notice Sends arbitrary data messages to another chain through Chainlink CCIP.
/// @dev Anyone may call `sendMessage`; the caller pays the CCIP fee with msg.value.
///      The fee is computed with `getFee` first and the surplus is refunded, because the
///      CCIP Router accepts overpayment and does not refund it.
///
///      Design note: both public overloads funnel into `_send`. Do NOT implement the short
///      overload as `this.sendMessage{value: msg.value}(...)`: an external self-call resets
///      msg.sender to address(this), so the refund would be sent to the contract instead of
///      the caller.
contract CrossChainSender is Ownable {
  /// @notice CCIP Router on this chain.
  IRouterClient public immutable i_router;

  /// @notice Default destination gas limit when the caller does not supply one.
  uint256 public defaultGasLimit = 200_000;

  /// @notice Whether sending is paused.
  bool public paused;

  event MessageSent(
    bytes32 indexed messageId,
    uint64 indexed destinationChainSelector,
    address indexed receiver,
    bytes data,
    uint256 fee
  );
  event FeeRefunded(address indexed to, uint256 amount);
  event DefaultGasLimitUpdated(uint256 oldLimit, uint256 newLimit);
  event PausedSet(bool paused);

  error ZeroAddress();
  error IsPaused();
  error FeeNotCovered(uint256 required, uint256 provided);
  error RefundFailed();

  modifier whenNotPaused() {
    if (paused) revert IsPaused();
    _;
  }

  constructor(address router_) Ownable(msg.sender) {
    if (router_ == address(0)) revert ZeroAddress();
    i_router = IRouterClient(router_);
  }

  /// @notice Build the CCIP message for a data-only send to an EVM chain.
  /// @param receiver Destination contract address, ABI-encoded for the wire format.
  /// @param data Arbitrary payload handed to the receiver.
  /// @param gasLimit Execution gas on the destination chain.
  /// @param allowOutOfOrderExecution Whether the message may be executed out of order.
  function buildMessage(
    address receiver,
    bytes memory data,
    uint256 gasLimit,
    bool allowOutOfOrderExecution
  ) public pure returns (Client.EVM2AnyMessage memory) {
    return
      Client.EVM2AnyMessage({
        receiver: abi.encode(receiver),
        data: data,
        tokenAmounts: new Client.EVMTokenAmount[](0),
        feeToken: address(0), // pay in native gas
        extraArgs: Client._argsToBytes(
          Client.EVMExtraArgsV2({gasLimit: gasLimit, allowOutOfOrderExecution: allowOutOfOrderExecution})
        )
      });
  }

  /// @notice Fee for a data-only message, in native gas, with an explicit gas limit.
  function getFee(
    uint64 destinationChainSelector,
    address receiver,
    bytes memory data,
    uint256 gasLimit,
    bool allowOutOfOrderExecution
  ) external view returns (uint256) {
    return
      i_router.getFee(
        destinationChainSelector,
        buildMessage(receiver, data, gasLimit, allowOutOfOrderExecution)
      );
  }

  /// @notice Fee using the contract default gas limit and ordered execution.
  function getFee(
    uint64 destinationChainSelector,
    address receiver,
    bytes memory data
  ) external view returns (uint256) {
    return
      i_router.getFee(
        destinationChainSelector,
        buildMessage(receiver, data, defaultGasLimit, true)
      );
  }

  /// @notice Send a data-only message with an explicit gas limit and ordering preference.
  function sendMessage(
    uint64 destinationChainSelector,
    address receiver,
    bytes memory data,
    uint256 gasLimit,
    bool allowOutOfOrderExecution
  ) external payable whenNotPaused returns (bytes32 messageId) {
    return _send(destinationChainSelector, receiver, data, gasLimit, allowOutOfOrderExecution);
  }

  /// @notice Send using the contract default gas limit and ordered execution.
  function sendMessage(
    uint64 destinationChainSelector,
    address receiver,
    bytes memory data
  ) external payable whenNotPaused returns (bytes32 messageId) {
    return _send(destinationChainSelector, receiver, data, defaultGasLimit, true);
  }

  /// @notice Update the default destination gas limit.
  function setDefaultGasLimit(uint256 newLimit) external onlyOwner {
    emit DefaultGasLimitUpdated(defaultGasLimit, newLimit);
    defaultGasLimit = newLimit;
  }

  /// @notice Pause or unpause sending.
  function setPaused(bool paused_) external onlyOwner {
    paused = paused_;
    emit PausedSet(paused_);
  }

  /// @dev Shared implementation. Keeps msg.sender intact so the refund reaches the caller.
  function _send(
    uint64 destinationChainSelector,
    address receiver,
    bytes memory data,
    uint256 gasLimit,
    bool allowOutOfOrderExecution
  ) private returns (bytes32 messageId) {
    if (receiver == address(0)) revert ZeroAddress();

    Client.EVM2AnyMessage memory message = buildMessage(
      receiver,
      data,
      gasLimit,
      allowOutOfOrderExecution
    );

    uint256 fee = i_router.getFee(destinationChainSelector, message);
    if (msg.value < fee) revert FeeNotCovered(fee, msg.value);

    messageId = i_router.ccipSend{value: fee}(destinationChainSelector, message);
    emit MessageSent(messageId, destinationChainSelector, receiver, data, fee);

    uint256 refund = msg.value - fee;
    if (refund > 0) {
      (bool ok, ) = payable(msg.sender).call{value: refund}("");
      if (!ok) revert RefundFailed();
      emit FeeRefunded(msg.sender, refund);
    }
  }
}
