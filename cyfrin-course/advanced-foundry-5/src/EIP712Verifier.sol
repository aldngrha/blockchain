// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

/// @title EIP712Verifier
/// @notice Verify EIP-712 structured data signatures — the proper way to sign in Web3
/// @dev EIP-712 prevents phishing by showing users exactly what they're signing
/// @dev Used by MetaMask, Uniswap, OpenSea, etc.
contract EIP712Verifier is EIP712 {
    // Typehash for Order struct
    bytes32 private constant ORDER_TYPEHASH =
        keccak256("Order(address maker,address token,uint256 amount,uint256 deadline)");

    mapping(bytes32 => bool) public s_executedOrders;

    error EIP712Verifier__InvalidSignature();
    error EIP712Verifier__OrderAlreadyExecuted();
    error EIP712Verifier__OrderExpired();

    event OrderExecuted(address indexed maker, address indexed token, uint256 amount);

    constructor() EIP712("EIP712Verifier", "1") {}

    /// @notice Execute an order with EIP-712 signature verification
    function executeOrder(
        address maker,
        address token,
        uint256 amount,
        uint256 deadline,
        bytes calldata signature
    ) external {
        // 1. Check expiration
        if (block.timestamp > deadline) revert EIP712Verifier__OrderExpired();

        // 2. Compute order hash
        bytes32 orderHash = _hashOrder(maker, token, amount, deadline);

        // 3. Check if already executed
        if (s_executedOrders[orderHash]) revert EIP712Verifier__OrderAlreadyExecuted();

        // 4. Verify EIP-712 signature
        address signer = ECDSA.recover(orderHash, signature);
        if (signer != maker) revert EIP712Verifier__InvalidSignature();

        // 5. Mark as executed
        s_executedOrders[orderHash] = true;

        emit OrderExecuted(maker, token, amount);
    }

    /// @notice Generate order hash (for signing off-chain)
    function hashOrder(
        address maker,
        address token,
        uint256 amount,
        uint256 deadline
    ) external view returns (bytes32) {
        return _hashOrder(maker, token, amount, deadline);
    }

    /// @dev Internal: hash order with EIP-712 domain separator
    function _hashOrder(
        address maker,
        address token,
        uint256 amount,
        uint256 deadline
    ) internal view returns (bytes32) {
        bytes32 structHash = keccak256(
            abi.encode(ORDER_TYPEHASH, maker, token, amount, deadline)
        );
        return _hashTypedDataV4(structHash);
    }
}
