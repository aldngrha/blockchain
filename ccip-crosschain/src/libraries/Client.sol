// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title Client
/// @notice Data structures for CCIP messages.
/// @dev Struct layouts and tag constants follow the Chainlink CCIP v1.5.1 API reference
///      (docs.chain.link/ccip/v1/evm/api-reference/v1.5.1/client). These are wire-format
///      definitions, so field order and types must not be changed.
///      In production you would import this from the official Chainlink contracts-ccip
///      package instead of vendoring it; it is vendored here so the project builds and
///      tests with zero external dependencies beyond OpenZeppelin and forge-std.
library Client {
  /// @notice A message as sent from an EVM chain to any CCIP-supported chain.
  struct EVM2AnyMessage {
    bytes receiver; // abi.encode(address) on the destination chain
    bytes data; // arbitrary payload
    EVMTokenAmount[] tokenAmounts; // tokens to transfer, empty for data-only messages
    address feeToken; // address(0) means pay fees in native gas
    bytes extraArgs; // encoded EVMExtraArgsV1 or EVMExtraArgsV2
  }

  /// @notice A message as received on an EVM chain.
  struct Any2EVMMessage {
    bytes32 messageId;
    uint64 sourceChainSelector;
    bytes sender; // abi.decode to address when the source chain is EVM
    bytes data;
    EVMTokenAmount[] destTokenAmounts;
  }

  /// @notice Token and amount pair used in both directions.
  struct EVMTokenAmount {
    address token;
    uint256 amount;
  }

  /// @notice Extra arguments version 1: gas limit only.
  struct EVMExtraArgsV1 {
    uint256 gasLimit;
  }

  /// @notice Extra arguments version 2: gas limit plus execution ordering control.
  struct EVMExtraArgsV2 {
    uint256 gasLimit;
    bool allowOutOfOrderExecution;
  }

  /// @dev bytes4(keccak256("CCIP EVMExtraArgsV1"))
  bytes4 internal constant EVM_EXTRA_ARGS_V1_TAG = 0x97a657c9;

  /// @dev bytes4(keccak256("CCIP EVMExtraArgsV2"))
  bytes4 internal constant EVM_EXTRA_ARGS_V2_TAG = 0x181dcf10;

  /// @notice Encode EVMExtraArgsV1 with its tag prefix.
  function _argsToBytes(EVMExtraArgsV1 memory extraArgs) internal pure returns (bytes memory) {
    return abi.encodeWithSelector(EVM_EXTRA_ARGS_V1_TAG, extraArgs);
  }

  /// @notice Encode EVMExtraArgsV2 with its tag prefix.
  function _argsToBytes(EVMExtraArgsV2 memory extraArgs) internal pure returns (bytes memory) {
    return abi.encodeWithSelector(EVM_EXTRA_ARGS_V2_TAG, extraArgs);
  }
}
