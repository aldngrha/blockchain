// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {MultiToken} from "../src/ERC1155.sol";

contract ERC1155Test is Test {
    MultiToken public multiToken;
    address public alice;
    address public bob;

    function setUp() public {
        multiToken = new MultiToken();
        alice = makeAddr("alice");
        bob = makeAddr("bob");
    }

    function test_createAndMint() public {
        // Create a fungible token (ID 0)
        uint256 tokenId = multiToken.createToken(0, "ipfs://token0");
        assertEq(tokenId, 0);

        // Mint 100 units to alice (fungible)
        multiToken.mint(alice, 0, 100);
        assertEq(multiToken.balanceOf(alice, 0), 100);
    }

    function test_batchMint() public {
        uint256[] memory ids = new uint256[](2);
        ids[0] = 0;
        ids[1] = 1;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 50;
        amounts[1] = 10;

        multiToken.batchMint(alice, ids, amounts);

        assertEq(multiToken.balanceOf(alice, 0), 50);
        assertEq(multiToken.balanceOf(alice, 1), 10);
    }

    function test_batchTransfer() public {
        multiToken.mint(alice, 0, 100);
        multiToken.mint(alice, 1, 50);

        uint256[] memory ids = new uint256[](2);
        ids[0] = 0;
        ids[1] = 1;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 30;
        amounts[1] = 20;

        vm.prank(alice);
        multiToken.batchTransfer(alice, bob, ids, amounts);

        assertEq(multiToken.balanceOf(bob, 0), 30);
        assertEq(multiToken.balanceOf(bob, 1), 20);
        assertEq(multiToken.balanceOf(alice, 0), 70);
        assertEq(multiToken.balanceOf(alice, 1), 30);
    }

    function test_burn() public {
        multiToken.mint(alice, 0, 100);

        vm.prank(alice);
        multiToken.burn(alice, 0, 30);

        assertEq(multiToken.balanceOf(alice, 0), 70);
    }

    function test_nftAndFungibleTogether() public {
        // Token 0 = fungible (unlimited)
        multiToken.createToken(0, "ipfs://coin");
        // Token 1 = non-fungible (1 of 1)
        multiToken.createToken(1, "ipfs://nft");

        // Mint 1000 coins to alice
        multiToken.mint(alice, 0, 1000);
        // Mint 1 NFT to bob
        multiToken.mint(bob, 1, 1);

        assertEq(multiToken.balanceOf(alice, 0), 1000);
        assertEq(multiToken.balanceOf(bob, 1), 1);
    }
}
