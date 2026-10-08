// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {MerkleProofWhitelist} from "../src/MerkleProofWhitelist.sol";

contract MerkleProofWhitelistTest is Test {
    MerkleProofWhitelist public whitelist;

    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");
    address user3 = makeAddr("user3");
    address user4 = makeAddr("user4");
    address nonWhitelisted = makeAddr("nonWhitelisted");

    // Leaves
    bytes32 leaf1;
    bytes32 leaf2;
    bytes32 leaf3;
    bytes32 leaf4;

    // Merkle root
    bytes32 merkleRoot;

    // Proofs (sorted pairs)
    bytes32[] proof1;
    bytes32[] proof2;
    bytes32[] proof3;
    bytes32[] proof4;

    /// @dev Helper: compute keccak256 in sorted order (OpenZeppelin convention)
    function _sortedHash(bytes32 a, bytes32 b) internal pure returns (bytes32) {
        return a < b
            ? keccak256(abi.encodePacked(a, b))
            : keccak256(abi.encodePacked(b, a));
    }

    event Claimed(address indexed user);
    event MerkleRootUpdated(bytes32 indexed oldRoot, bytes32 indexed newRoot);

    function setUp() public {
        // Generate leaves: keccak256(abi.encodePacked(address))
        leaf1 = keccak256(abi.encodePacked(user1));
        leaf2 = keccak256(abi.encodePacked(user2));
        leaf3 = keccak256(abi.encodePacked(user3));
        leaf4 = keccak256(abi.encodePacked(user4));

        // Build tree with 4 leaves (perfect binary tree)
        //
        //         root
        //        /    \
        //      h12     h34
        //     /  \    /  \
        //   l1   l2  l3   l4
        //
        bytes32 h12 = _sortedHash(leaf1, leaf2);
        bytes32 h34 = _sortedHash(leaf3, leaf4);
        merkleRoot = _sortedHash(h12, h34);

        // Proofs for each leaf (sorted pairs at each level)
        // user1: [leaf2, h34]
        proof1 = new bytes32[](2);
        proof1[0] = leaf2;
        proof1[1] = h34;

        // user2: [leaf1, h34]
        proof2 = new bytes32[](2);
        proof2[0] = leaf1;
        proof2[1] = h34;

        // user3: [leaf4, h12]
        proof3 = new bytes32[](2);
        proof3[0] = leaf4;
        proof3[1] = h12;

        // user4: [leaf3, h12]
        proof4 = new bytes32[](2);
        proof4[0] = leaf3;
        proof4[1] = h12;

        whitelist = new MerkleProofWhitelist(merkleRoot);
    }

    // ========================
    // Constructor Tests
    // ========================

    function test_constructor_setsRootAndOwner() public view {
        assertEq(whitelist.s_merkleRoot(), merkleRoot);
        assertEq(whitelist.owner(), address(this));
    }

    function test_constructor_revertsOnZeroRoot() public {
        vm.expectRevert(MerkleProofWhitelist.MerkleProofWhitelist__ZeroAddress.selector);
        new MerkleProofWhitelist(bytes32(0));
    }

    // ========================
    // Claim Tests
    // ========================

    function test_claim_success_user1() public {
        vm.prank(user1);
        whitelist.claim(proof1, leaf1);
        assertTrue(whitelist.s_claimed(user1));
    }

    function test_claim_success_user2() public {
        vm.prank(user2);
        whitelist.claim(proof2, leaf2);
        assertTrue(whitelist.s_claimed(user2));
    }

    function test_claim_success_user3() public {
        vm.prank(user3);
        whitelist.claim(proof3, leaf3);
        assertTrue(whitelist.s_claimed(user3));
    }

    function test_claim_success_user4() public {
        vm.prank(user4);
        whitelist.claim(proof4, leaf4);
        assertTrue(whitelist.s_claimed(user4));
    }

    function test_claim_allUsersCanClaim() public {
        vm.prank(user1);
        whitelist.claim(proof1, leaf1);

        vm.prank(user2);
        whitelist.claim(proof2, leaf2);

        vm.prank(user3);
        whitelist.claim(proof3, leaf3);

        vm.prank(user4);
        whitelist.claim(proof4, leaf4);

        assertTrue(whitelist.s_claimed(user1));
        assertTrue(whitelist.s_claimed(user2));
        assertTrue(whitelist.s_claimed(user3));
        assertTrue(whitelist.s_claimed(user4));
    }

    function test_claim_emitsEvent() public {
        vm.prank(user1);
        vm.expectEmit(true, false, false, true);
        emit Claimed(user1);
        whitelist.claim(proof1, leaf1);
    }

    function test_claim_revertsOnDoubleClaim() public {
        vm.prank(user1);
        whitelist.claim(proof1, leaf1);

        vm.prank(user1);
        vm.expectRevert(MerkleProofWhitelist.MerkleProofWhitelist__AlreadyClaimed.selector);
        whitelist.claim(proof1, leaf1);
    }

    function test_claim_revertsOnInvalidProof() public {
        // user1 tries to claim with user2's leaf but user1's proof
        vm.prank(user1);
        vm.expectRevert(MerkleProofWhitelist.MerkleProofWhitelist__InvalidProof.selector);
        whitelist.claim(proof1, leaf2); // wrong leaf!
    }

    function test_claim_revertsOnNonWhitelisted() public {
        bytes32 fakeLeaf = keccak256(abi.encodePacked(nonWhitelisted));
        bytes32[] memory fakeProof = new bytes32[](0);

        vm.prank(nonWhitelisted);
        vm.expectRevert(MerkleProofWhitelist.MerkleProofWhitelist__InvalidProof.selector);
        whitelist.claim(fakeProof, fakeLeaf);
    }

    function test_claim_revertsOnSwappedProof() public {
        // user1 tries with user3's proof
        vm.prank(user1);
        vm.expectRevert(MerkleProofWhitelist.MerkleProofWhitelist__InvalidProof.selector);
        whitelist.claim(proof3, leaf1);
    }

    // ========================
    // setMerkleRoot Tests
    // ========================

    function test_setMerkleRoot_success() public {
        bytes32 newRoot = keccak256("newRoot");

        vm.expectEmit(true, false, false, true);
        emit MerkleRootUpdated(merkleRoot, newRoot);

        whitelist.setMerkleRoot(newRoot);
        assertEq(whitelist.s_merkleRoot(), newRoot);
    }

    function test_setMerkleRoot_revertsOnNonOwner() public {
        vm.prank(user1);
        vm.expectRevert(MerkleProofWhitelist.MerkleProofWhitelist__NotOwner.selector);
        whitelist.setMerkleRoot(keccak256("newRoot"));
    }

    function test_setMerkleRoot_revertsOnZeroRoot() public {
        vm.expectRevert(MerkleProofWhitelist.MerkleProofWhitelist__ZeroAddress.selector);
        whitelist.setMerkleRoot(bytes32(0));
    }

    // ========================
    // generateLeaf Tests
    // ========================

    function test_generateLeaf_matchesManualHash() public view {
        bytes32 generated = whitelist.generateLeaf(user1);
        assertEq(generated, leaf1);
    }

    // ========================
    // Fuzz Test
    // ========================

    function testFuzz_claim_revertsOnWrongProof(address user) public {
        vm.assume(user != user1 && user != user2 && user != user3 && user != user4);

        bytes32 fakeLeaf = keccak256(abi.encodePacked(user));
        bytes32[] memory fakeProof = new bytes32[](0);

        vm.prank(user);
        vm.expectRevert(MerkleProofWhitelist.MerkleProofWhitelist__InvalidProof.selector);
        whitelist.claim(fakeProof, fakeLeaf);
    }
}
