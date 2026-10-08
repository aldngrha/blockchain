// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/// @title SignatureVerifier
/// @notice Verify ECDSA signatures — the foundation of blockchain security
/// @dev Every Ethereum transaction is signed with ECDSA
contract SignatureVerifier {
    mapping(bytes32 => bool) public s_messageSigned;

    error SignatureVerifier__InvalidSignature();
    error SignatureVerifier__AlreadySigned();

    event MessageSigned(address indexed signer, bytes32 messageHash);

    /// @notice Verify a signed message
    /// @param message The original message
    /// @param signature The ECDSA signature (65 bytes: r + s + v)
    /// @param expectedSigner The address that should have signed
    function verifySignature(
        bytes32 message,
        bytes calldata signature,
        address expectedSigner
    ) public pure returns (bool) {
        // Add prefix to prevent signing raw transactions
        bytes32 ethSignedHash = MessageHashEth.sign(message);
        return ECDSA.recover(ethSignedHash, signature) == expectedSigner;
    }

    /// @notice Sign a message and record it
    /// @param message The message to sign
    /// @param signature The ECDSA signature
    function signMessage(bytes32 message, bytes calldata signature) external {
        if (s_messageSigned[message]) revert SignatureVerifier__AlreadySigned();

        bytes32 ethSignedHash = MessageHashEth.sign(message);
        address signer = ECDSA.recover(ethSignedHash, signature);

        if (signer == address(0)) revert SignatureVerifier__InvalidSignature();

        s_messageSigned[message] = true;
        emit MessageSigned(signer, message);
    }
}

/// @notice Helper library to add "\x19Ethereum Signed Message:\n32" prefix
library MessageHashEth {
    function sign(bytes32 hash) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));
    }
}
