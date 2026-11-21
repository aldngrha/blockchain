// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {CrossChainSender} from "../src/CrossChainSender.sol";
import {MessageReceiver} from "../src/MessageReceiver.sol";
import {MockRouter} from "./mocks/MockRouter.sol";
import {Client} from "../src/libraries/Client.sol";
import {IRouterClient} from "../src/interfaces/IRouterClient.sol";
import {IAny2EVMMessageReceiver} from "../src/interfaces/IAny2EVMMessageReceiver.sol";
import {IERC165} from "../src/interfaces/IERC165.sol";

contract CrossChainTest is Test {
  /// @dev Arbitrary chain selector for tests. A real deployment must use the official
  ///      selector from the Chainlink CCIP directory, not this value.
  uint64 internal constant REMOTE_CHAIN = 1;

  uint256 internal constant FEE = 0.001 ether;
  uint256 internal constant START_BALANCE = 100 ether;

  MockRouter internal router;
  CrossChainSender internal sender;
  MessageReceiver internal receiver;

  address internal alice = makeAddr("alice");
  address internal bob = makeAddr("bob");

  function setUp() public {
    router = new MockRouter(REMOTE_CHAIN, FEE);
    sender = new CrossChainSender(address(router));
    receiver = new MessageReceiver(address(router));

    router.setReceiverOnRemoteChain(address(receiver));
    receiver.setTrustedSender(REMOTE_CHAIN, address(sender), true);

    vm.deal(alice, START_BALANCE);
    vm.deal(bob, START_BALANCE);
  }

  // ---------------------------------------------------------------- helpers

  function _inbound(
    address sourceSender,
    bytes memory data
  ) internal pure returns (Client.Any2EVMMessage memory) {
    return
      Client.Any2EVMMessage({
        messageId: keccak256("id"),
        sourceChainSelector: REMOTE_CHAIN,
        sender: abi.encode(sourceSender),
        data: data,
        destTokenAmounts: new Client.EVMTokenAmount[](0)
      });
  }

  // ---------------------------------------------------------------- happy path

  function test_SendMessage_DeliversToReceiver() public {
    vm.prank(alice);
    bytes32 messageId = sender.sendMessage{value: FEE}(REMOTE_CHAIN, address(receiver), "hello ccip");

    assertEq(receiver.messageCount(), 1, "one message accepted");
    assertEq(receiver.lastMessageId(), messageId, "message id stored");
    assertEq(receiver.lastSourceChainSelector(), REMOTE_CHAIN, "source chain stored");
    assertEq(receiver.lastSender(), address(sender), "sender recorded as the source contract");
    assertEq(receiver.lastData(), bytes("hello ccip"), "payload stored");
    assertEq(router.sentCount(), 1, "router saw one send");
  }

  function test_SendMessage_RefundsSurplus() public {
    uint256 overpay = 0.5 ether;

    vm.prank(alice);
    sender.sendMessage{value: FEE + overpay}(REMOTE_CHAIN, address(receiver), "x");

    // Only the fee is consumed; the surplus comes back.
    assertEq(alice.balance, START_BALANCE - FEE, "net cost equals the fee");
  }

  function test_SendMessage_ExactFeeLeavesNoRefund() public {
    vm.prank(alice);
    sender.sendMessage{value: FEE}(REMOTE_CHAIN, address(receiver), "x");

    assertEq(alice.balance, START_BALANCE - FEE, "exact fee consumed");
  }

  function test_GetFee_MatchesRouterFee() public view {
    assertEq(sender.getFee(REMOTE_CHAIN, address(receiver), "x"), FEE);
    assertEq(sender.getFee(REMOTE_CHAIN, address(receiver), "x", 300_000, false), FEE);
  }

  function test_ShortOverloadUsesDefaultGasLimit() public {
    assertEq(sender.defaultGasLimit(), 200_000);

    vm.prank(alice);
    sender.sendMessage{value: FEE}(REMOTE_CHAIN, address(receiver), "short");

    assertEq(receiver.messageCount(), 1);
  }

  // ---------------------------------------------------------------- sender guards

  function test_SendMessage_RevertsWhenFeeNotCovered() public {
    vm.prank(alice);
    vm.expectRevert(
      abi.encodeWithSelector(CrossChainSender.FeeNotCovered.selector, FEE, FEE - 1)
    );
    sender.sendMessage{value: FEE - 1}(REMOTE_CHAIN, address(receiver), "x");
  }

  function test_SendMessage_RevertsOnZeroReceiver() public {
    vm.prank(alice);
    vm.expectRevert(CrossChainSender.ZeroAddress.selector);
    sender.sendMessage{value: FEE}(REMOTE_CHAIN, address(0), "x");
  }

  function test_SendMessage_RevertsWhenPaused() public {
    sender.setPaused(true);
    assertTrue(sender.paused());

    vm.prank(alice);
    vm.expectRevert(CrossChainSender.IsPaused.selector);
    sender.sendMessage{value: FEE}(REMOTE_CHAIN, address(receiver), "x");
  }

  function test_SendMessage_WorksAgainAfterUnpause() public {
    sender.setPaused(true);
    sender.setPaused(false);

    vm.prank(alice);
    sender.sendMessage{value: FEE}(REMOTE_CHAIN, address(receiver), "x");
    assertEq(receiver.messageCount(), 1);
  }

  function test_SetDefaultGasLimit_OnlyOwner() public {
    vm.prank(alice);
    vm.expectRevert();
    sender.setDefaultGasLimit(1);

    sender.setDefaultGasLimit(500_000);
    assertEq(sender.defaultGasLimit(), 500_000);
  }

  function test_RouterRevertsOnUnsupportedChain() public {
    router.setSupported(false);

    vm.prank(alice);
    vm.expectRevert(
      abi.encodeWithSelector(IRouterClient.UnsupportedDestinationChain.selector, REMOTE_CHAIN)
    );
    sender.sendMessage{value: FEE}(REMOTE_CHAIN, address(receiver), "x");
  }

  // ---------------------------------------------------------------- receiver guards

  function test_Receiver_RevertsWhenCallerIsNotRouter() public {
    Client.Any2EVMMessage memory message = _inbound(address(sender), "x");

    vm.prank(alice);
    vm.expectRevert(abi.encodeWithSelector(MessageReceiver.InvalidRouter.selector, alice));
    receiver.ccipReceive(message);
  }

  function test_Receiver_RevertsWhenSenderIsNotTrusted() public {
    // A second sender that the receiver does not trust.
    CrossChainSender rogue = new CrossChainSender(address(router));

    vm.prank(alice);
    vm.expectRevert(
      abi.encodeWithSelector(MessageReceiver.UntrustedSender.selector, REMOTE_CHAIN, address(rogue))
    );
    rogue.sendMessage{value: FEE}(REMOTE_CHAIN, address(receiver), "spoofed");

    assertEq(receiver.messageCount(), 0, "nothing stored");
  }

  function test_Receiver_AcceptsAfterSenderIsTrusted() public {
    CrossChainSender rogue = new CrossChainSender(address(router));

    receiver.setTrustedSender(REMOTE_CHAIN, address(rogue), true);

    vm.prank(alice);
    rogue.sendMessage{value: FEE}(REMOTE_CHAIN, address(receiver), "now allowed");

    assertEq(receiver.messageCount(), 1);
    assertEq(receiver.lastSender(), address(rogue));
  }

  function test_Receiver_RejectsAfterSenderIsUntrusted() public {
    receiver.setTrustedSender(REMOTE_CHAIN, address(sender), false);

    vm.prank(alice);
    vm.expectRevert(
      abi.encodeWithSelector(MessageReceiver.UntrustedSender.selector, REMOTE_CHAIN, address(sender))
    );
    sender.sendMessage{value: FEE}(REMOTE_CHAIN, address(receiver), "x");
  }

  function test_Receiver_TrustIsPerChain() public {
    // Same sender address, but the message claims to originate from another chain.
    router.setSourceChainSelectorForDelivery(REMOTE_CHAIN + 1);

    vm.prank(alice);
    vm.expectRevert(
      abi.encodeWithSelector(
        MessageReceiver.UntrustedSender.selector,
        REMOTE_CHAIN + 1,
        address(sender)
      )
    );
    sender.sendMessage{value: FEE}(REMOTE_CHAIN, address(receiver), "x");

    // Trusting that chain explicitly makes it go through.
    receiver.setTrustedSender(REMOTE_CHAIN + 1, address(sender), true);

    vm.prank(alice);
    sender.sendMessage{value: FEE}(REMOTE_CHAIN, address(receiver), "x");

    assertEq(receiver.messageCount(), 1);
    assertEq(receiver.lastSourceChainSelector(), REMOTE_CHAIN + 1);
  }

  function test_Receiver_SupportsInterface() public view {
    assertTrue(receiver.supportsInterface(type(IAny2EVMMessageReceiver).interfaceId));
    assertTrue(receiver.supportsInterface(type(IERC165).interfaceId));
    assertFalse(receiver.supportsInterface(0xdeadbeef));
  }

  function test_Receiver_ExposesRouter() public view {
    assertEq(receiver.getRouter(), address(router));
  }

  function test_Receiver_RevertsOnZeroRouter() public {
    vm.expectRevert(abi.encodeWithSelector(MessageReceiver.InvalidRouter.selector, address(0)));
    new MessageReceiver(address(0));
  }

  function test_Receiver_SetTrustedSender_OnlyOwner() public {
    vm.prank(alice);
    vm.expectRevert();
    receiver.setTrustedSender(REMOTE_CHAIN, alice, true);
  }

  function test_Sender_RevertsOnZeroRouter() public {
    vm.expectRevert(CrossChainSender.ZeroAddress.selector);
    new CrossChainSender(address(0));
  }

  // ---------------------------------------------------------------- fuzz

  function testFuzz_ArbitraryPayloadRoundTrip(bytes memory data) public {
    vm.assume(data.length <= 512);

    vm.prank(alice);
    sender.sendMessage{value: FEE}(REMOTE_CHAIN, address(receiver), data);

    assertEq(receiver.lastData(), data);
    assertEq(receiver.messageCount(), 1);
  }

  function testFuzz_RefundIsExactlyTheSurplus(uint96 extra) public {
    extra = uint96(bound(extra, 1, 10 ether));

    vm.prank(alice);
    sender.sendMessage{value: FEE + extra}(REMOTE_CHAIN, address(receiver), "x");

    assertEq(alice.balance, START_BALANCE - FEE, "caller only loses the fee");
    assertEq(address(router).balance, FEE, "router keeps exactly the fee");
  }

  function testFuzz_TwoSendersBothDeliver(uint96 amountA, uint96 amountB) public {
    amountA = uint96(bound(amountA, 0, 256));
    amountB = uint96(bound(amountB, 0, 256));

    bytes memory payloadA = abi.encode("A", amountA);
    bytes memory payloadB = abi.encode("B", amountB);

    vm.prank(alice);
    sender.sendMessage{value: FEE}(REMOTE_CHAIN, address(receiver), payloadA);

    vm.prank(bob);
    sender.sendMessage{value: FEE}(REMOTE_CHAIN, address(receiver), payloadB);

    assertEq(receiver.messageCount(), 2);
    assertEq(receiver.lastData(), payloadB, "last write wins");
    assertEq(bob.balance, START_BALANCE - FEE);
  }
}
