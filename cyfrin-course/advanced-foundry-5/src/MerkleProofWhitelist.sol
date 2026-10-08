// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

/// @title MerkleProofWhitelist
/// @notice Merkle tree whitelist verification — gas-efficient way to whitelist many addresses
/// @dev Users prove membership by providing a Merkle proof instead of storing all addresses on-chain
contract MerkleProofWhitelist {
    bytes32 public s_merkleRoot;
    address public owner;

    mapping(address => bool) public s_claimed;

    error MerkleProofWhitelist__NotOwner();
    error MerkleProofWhitelist__AlreadyClaimed();
    error MerkleProofWhitelist__InvalidProof();
    error MerkleProofWhitelist__ZeroAddress();

    event MerkleRootUpdated(bytes32 indexed oldRoot, bytes32 indexed newRoot);
    event Claimed(address indexed user);

    modifier onlyOwner() {
        if (msg.sender != owner) revert MerkleProofWhitelist__NotOwner();
        _;
    }

    /// @param merkleRoot The root of the Merkle tree
    constructor(bytes32 merkleRoot) {
        if (merkleRoot == bytes32(0)) revert MerkleProofWhitelist__ZeroAddress();
        s_merkleRoot = merkleRoot;
        owner = msg.sender;
    }

    /// @notice Claim whitelist spot by providing Merkle proof
    /// @param merkleProof Array of sibling hashes from leaf to root
    /// @param leaf The leaf hash (keccak256(abi.encodePacked(address)))
    function claim(bytes32[] calldata merkleProof, bytes32 leaf) external {
        if (s_claimed[msg.sender]) revert MerkleProofWhitelist__AlreadyClaimed();

        // Verify the proof — this is the core Merkle logic
        if (!MerkleProof.verify(merkleProof, s_merkleRoot, leaf)) {
            revert MerkleProofWhitelist__InvalidProof();
        }

        s_claimed[msg.sender] = true;
        emit Claimed(msg.sender);
    }

    /// @notice Update the Merkle root (only owner)
    /// @param newMerkleRoot The new root
    function setMerkleRoot(bytes32 newMerkleRoot) external onlyOwner {
        if (newMerkleRoot == bytes32(0)) revert MerkleProofWhitelist__ZeroAddress();
        bytes32 oldRoot = s_merkleRoot;
        s_merkleRoot = newMerkleRoot;
        emit MerkleRootUpdated(oldRoot, newMerkleRoot);
    }

    /// @notice Helper: generate leaf hash from address
    function generateLeaf(address user) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(user));
    }
}
