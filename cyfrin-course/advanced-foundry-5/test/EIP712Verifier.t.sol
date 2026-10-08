// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {EIP712Verifier} from "../src/EIP712Verifier.sol";

contract EIP712VerifierTest is Test {
    EIP712Verifier public verifier;

    uint256 internal constant PRIVATE_KEY = 0xA11CE;
    address internal maker;

    address token = makeAddr("token");
    uint256 amount = 1000e18;
    uint256 deadline;

    event OrderExecuted(address indexed maker, address indexed token, uint256 amount);

    function setUp() public {
        verifier = new EIP712Verifier();
        maker = vm.addr(PRIVATE_KEY);
        deadline = block.timestamp + 1 hours;
    }

    // ========================
    // executeOrder Tests
    // ========================

    function test_executeOrder_success() public {
        bytes memory signature = _signOrder(maker, token, amount, deadline);

        vm.expectEmit(true, true, false, true);
        emit OrderExecuted(maker, token, amount);

        verifier.executeOrder(maker, token, amount, deadline, signature);

        bytes32 orderHash = verifier.hashOrder(maker, token, amount, deadline);
        assertTrue(verifier.s_executedOrders(orderHash));
    }

    function test_executeOrder_revertsOnExpired() public {
        uint256 expiredDeadline = block.timestamp - 1;
        bytes memory signature = _signOrder(maker, token, amount, expiredDeadline);

        vm.expectRevert(EIP712Verifier.EIP712Verifier__OrderExpired.selector);
        verifier.executeOrder(maker, token, amount, expiredDeadline, signature);
    }

    function test_executeOrder_revertsOnAlreadyExecuted() public {
        bytes memory signature = _signOrder(maker, token, amount, deadline);

        verifier.executeOrder(maker, token, amount, deadline, signature);

        vm.expectRevert(EIP712Verifier.EIP712Verifier__OrderAlreadyExecuted.selector);
        verifier.executeOrder(maker, token, amount, deadline, signature);
    }

    function test_executeOrder_revertsOnInvalidSignature() public {
        uint256 wrongKey = 0xDEAD;
        bytes memory badSignature = _signOrderWithKey(maker, token, amount, deadline, wrongKey);

        vm.expectRevert(EIP712Verifier.EIP712Verifier__InvalidSignature.selector);
        verifier.executeOrder(maker, token, amount, deadline, badSignature);
    }

    function test_executeOrder_tamperedAmount() public {
        bytes memory signature = _signOrder(maker, token, amount, deadline);

        vm.expectRevert(EIP712Verifier.EIP712Verifier__InvalidSignature.selector);
        verifier.executeOrder(maker, token, amount * 2, deadline, signature);
    }

    function test_executeOrder_tamperedToken() public {
        bytes memory signature = _signOrder(maker, token, amount, deadline);

        address otherToken = makeAddr("otherToken");
        vm.expectRevert(EIP712Verifier.EIP712Verifier__InvalidSignature.selector);
        verifier.executeOrder(maker, otherToken, amount, deadline, signature);
    }

    function test_executeOrder_tamperedMaker() public {
        bytes memory signature = _signOrder(maker, token, amount, deadline);

        address otherMaker = makeAddr("otherMaker");
        vm.expectRevert(EIP712Verifier.EIP712Verifier__InvalidSignature.selector);
        verifier.executeOrder(otherMaker, token, amount, deadline, signature);
    }

    function test_executeOrder_differentOrdersIndependent() public {
        uint256 amount2 = 2000e18;

        bytes memory sig1 = _signOrder(maker, token, amount, deadline);
        bytes memory sig2 = _signOrder(maker, token, amount2, deadline);

        verifier.executeOrder(maker, token, amount, deadline, sig1);
        verifier.executeOrder(maker, token, amount2, deadline, sig2);

        assertTrue(verifier.s_executedOrders(verifier.hashOrder(maker, token, amount, deadline)));
        assertTrue(verifier.s_executedOrders(verifier.hashOrder(maker, token, amount2, deadline)));
    }

    // ========================
    // hashOrder Tests
    // ========================

    function test_hashOrder_deterministic() public view {
        bytes32 hash1 = verifier.hashOrder(maker, token, amount, deadline);
        bytes32 hash2 = verifier.hashOrder(maker, token, amount, deadline);
        assertEq(hash1, hash2);
    }

    function test_hashOrder_differentForDifferentAmount() public view {
        bytes32 hash1 = verifier.hashOrder(maker, token, amount, deadline);
        bytes32 hash2 = verifier.hashOrder(maker, token, amount * 2, deadline);
        assertTrue(hash1 != hash2);
    }

    function test_hashOrder_differentForDifferentToken() public {
        address otherToken = makeAddr("otherToken");
        bytes32 hash1 = verifier.hashOrder(maker, token, amount, deadline);
        bytes32 hash2 = verifier.hashOrder(maker, otherToken, amount, deadline);
        assertTrue(hash1 != hash2);
    }

    function test_hashOrder_differentForDifferentMaker() public {
        address otherMaker = makeAddr("otherMaker");
        bytes32 hash1 = verifier.hashOrder(maker, token, amount, deadline);
        bytes32 hash2 = verifier.hashOrder(otherMaker, token, amount, deadline);
        assertTrue(hash1 != hash2);
    }

    // ========================
    // Fuzz Test
    // ========================

    function testFuzz_executeOrder_variousAmounts(uint256 _amount) public {
        vm.assume(_amount > 0 && _amount < type(uint128).max);

        bytes memory signature = _signOrder(maker, token, _amount, deadline);
        verifier.executeOrder(maker, token, _amount, deadline, signature);

        bytes32 orderHash = verifier.hashOrder(maker, token, _amount, deadline);
        assertTrue(verifier.s_executedOrders(orderHash));
    }

    // ========================
    // Internal Helpers
    // ========================

    function _signOrder(
        address _maker,
        address _token,
        uint256 _amount,
        uint256 _deadline
    ) internal view returns (bytes memory) {
        return _signOrderWithKey(_maker, _token, _amount, _deadline, PRIVATE_KEY);
    }

    function _signOrderWithKey(
        address _maker,
        address _token,
        uint256 _amount,
        uint256 _deadline,
        uint256 privateKey
    ) internal view returns (bytes memory) {
        bytes32 orderHash = verifier.hashOrder(_maker, _token, _amount, _deadline);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, orderHash);
        return abi.encodePacked(r, s, v);
    }
}
