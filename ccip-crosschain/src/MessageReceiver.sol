// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IAny2EVMMessageReceiver} from "./interfaces/IAny2EVMMessageReceiver.sol";
import {IERC165} from "./interfaces/IERC165.sol";
import {Client} from "./libraries/Client.sol";

/// @title MessageReceiver
/// @notice Receives CCIP data messages and stores the last one.
/// @dev Two security properties, both required in practice:
///      1. Only the CCIP Router may call `ccipReceive`. Without this, anyone can forge a message.
///      2. The source chain and sender must be allowlisted. Without this, a message sent from a
///         contract the attacker controls on another chain is accepted as legitimate.
///
///      Note on the interface: CCIP checks `supportsInterface` before delivering. If it returns
///      true, tokens are transferred and `ccipReceive` is called atomically. If it returns false
///      or reverts, only tokens are transferred and the payload is silently ignored.
contract MessageReceiver is IAny2EVMMessageReceiver, Ownable {
  /// @notice CCIP Router on this chain, the only allowed caller of `ccipReceive`.
  address public immutable i_ccipRouter;

  /// @notice Allowlisted (source chain selector => sender => allowed).
  mapping(uint64 => mapping(address => bool)) public trustedSender;

  /// @notice Number of accepted messages.
  uint256 public messageCount;

  /// @notice Fields of the last accepted message.
  bytes32 public lastMessageId;
  uint64 public lastSourceChainSelector;
  address public lastSender;
  bytes public lastData;

  event MessageReceived(
    bytes32 indexed messageId,
    uint64 indexed sourceChainSelector,
    address indexed sender,
    bytes data
  );
  event TrustedSenderSet(uint64 indexed sourceChainSelector, address indexed sender, bool allowed);

  error InvalidRouter(address router);
  error UntrustedSender(uint64 sourceChainSelector, address sender);

  modifier onlyRouter() {
    if (msg.sender != i_ccipRouter) revert InvalidRouter(msg.sender);
    _;
  }

  constructor(address router_) Ownable(msg.sender) {
    if (router_ == address(0)) revert InvalidRouter(address(0));
    i_ccipRouter = router_;
  }

  /// @notice Called by the Router to deliver a message.
  /// @dev Reverts if the source is not allowlisted. Because a revert also reverts any token
  ///      transfer in the same message, keep this function cheap and predictable.
  function ccipReceive(Client.Any2EVMMessage calldata message) external override onlyRouter {
    address sender = abi.decode(message.sender, (address));

    if (!trustedSender[message.sourceChainSelector][sender]) {
      revert UntrustedSender(message.sourceChainSelector, sender);
    }

    messageCount += 1;
    lastMessageId = message.messageId;
    lastSourceChainSelector = message.sourceChainSelector;
    lastSender = sender;
    lastData = message.data;

    emit MessageReceived(message.messageId, message.sourceChainSelector, sender, message.data);
  }

  /// @notice Router address used for validation.
  function getRouter() public view returns (address) {
    return i_ccipRouter;
  }

  /// @notice ERC-165. Must return true for IAny2EVMMessageReceiver or CCIP will not call us.
  function supportsInterface(bytes4 interfaceId) public pure override returns (bool) {
    return
      interfaceId == type(IAny2EVMMessageReceiver).interfaceId || interfaceId == type(IERC165).interfaceId;
  }

  /// @notice Allow or block a sender on a given source chain.
  function setTrustedSender(uint64 sourceChainSelector, address sender, bool allowed) external onlyOwner {
    trustedSender[sourceChainSelector][sender] = allowed;
    emit TrustedSenderSet(sourceChainSelector, sender, allowed);
  }
}
