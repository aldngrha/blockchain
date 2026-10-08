// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {SignatureVerifier} from "../src/SignatureVerifier.sol";

contract SignatureVerifierTest is Test {
    SignatureVerifier public verifier;

    uint256 internal constant PRIVATE_KEY = 0xA11CE;
    address internal signer;

    event MessageSigned(address indexed signer, bytes32 messageHash);

    function setUp() public {
        verifier = new SignatureVerifier();
        // Get the actual signer address from the private key
        signer = vm.addr(PRIVATE_KEY);
    }

    // ========================
    // verifySignature Tests
    // ========================

    function test_verifySignature_validSignature() public view {
        bytes32 message = keccak256("Hello, World!");
        bytes memory signature = _signMessage(message, PRIVATE_KEY);

        assertTrue(verifier.verifySignature(message, signature, signer));
    }

    function test_verifySignature_invalidSigner() public {
        bytes32 message = keccak256("Hello, World!");
        bytes memory signature = _signMessage(message, PRIVATE_KEY);

        address wrongSigner = makeAddr("wrongSigner");
        assertFalse(verifier.verifySignature(message, signature, wrongSigner));
    }

    function test_verifySignature_tamperedMessage() public view {
        bytes32 message = keccak256("Hello, World!");
        bytes32 tamperedMessage = keccak256("Hello, World?");
        bytes memory signature = _signMessage(message, PRIVATE_KEY);

        assertFalse(verifier.verifySignature(tamperedMessage, signature, signer));
    }

    function test_verifySignature_multipleSigners() public {
        uint256 key2 = 0xBEEF;
        uint256 key3 = 0xCAFE;
        address signer2 = vm.addr(key2);
        address signer3 = vm.addr(key3);

        bytes32 message = keccak256("Same message");
        bytes memory sig1 = _signMessage(message, PRIVATE_KEY);
        bytes memory sig2 = _signMessage(message, key2);
        bytes memory sig3 = _signMessage(message, key3);

        assertTrue(verifier.verifySignature(message, sig1, signer));
        assertTrue(verifier.verifySignature(message, sig2, signer2));
        assertTrue(verifier.verifySignature(message, sig3, signer3));

        // Cross-check: each signature only verifies for the correct signer
        assertFalse(verifier.verifySignature(message, sig1, signer2));
        assertFalse(verifier.verifySignature(message, sig2, signer));
    }

    // ========================
    // signMessage Tests
    // ========================

    function test_signMessage_success() public {
        bytes32 message = keccak256("Sign this");
        bytes memory signature = _signMessage(message, PRIVATE_KEY);

        vm.expectEmit(true, false, false, true);
        emit MessageSigned(signer, message);

        verifier.signMessage(message, signature);

        assertTrue(verifier.s_messageSigned(message));
    }

    function test_signMessage_revertsOnDoubleSign() public {
        bytes32 message = keccak256("Sign this");
        bytes memory signature = _signMessage(message, PRIVATE_KEY);

        verifier.signMessage(message, signature);

        vm.expectRevert(SignatureVerifier.SignatureVerifier__AlreadySigned.selector);
        verifier.signMessage(message, signature);
    }

    function test_signMessage_revertsOnInvalidSignature() public {
        bytes32 message = keccak256("Sign this");
        // Use invalid v value (0) which causes ECDSA to revert
        bytes memory badSignature = abi.encodePacked(
            bytes32(uint256(1)),
            bytes32(uint256(1)),
            uint8(0) // invalid v
        );

        vm.expectRevert();
        verifier.signMessage(message, badSignature);
    }

    // ========================
    // Fuzz Test
    // ========================

    function testFuzz_verifySignature_randomMessage(uint256 seed) public view {
        bytes32 message = keccak256(abi.encode(seed));
        bytes memory signature = _signMessage(message, PRIVATE_KEY);

        assertTrue(verifier.verifySignature(message, signature, signer));
    }

    // ========================
    // Internal Helpers
    // ========================

    function _signMessage(bytes32 message, uint256 privateKey) internal pure returns (bytes memory) {
        bytes32 ethSignedHash = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", message)
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, ethSignedHash);
        return abi.encodePacked(r, s, v);
    }
}
