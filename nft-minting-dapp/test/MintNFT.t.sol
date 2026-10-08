// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/MintNFT.sol";

contract MintNFTTest is Test {
    MintNFT nft;
    address owner = address(this);
    address user1 = address(0x1);
    address user2 = address(0x2);

    receive() external payable {}

    function setUp() public {
        nft = new MintNFT();
    }

    // ============ BASIC TESTS ============

    function test_Initial_state() public view {
        assertEq(nft.name(), "Freebuff NFT");
        assertEq(nft.symbol(), "FBNFT");
        assertEq(nft.mintPrice(), 0.01 ether);
        assertEq(nft.maxSupply(), 100);
        assertTrue(nft.mintingActive());
        assertEq(nft.totalMinted(), 0);
        assertEq(nft.remaining(), 100);
    }

    // ============ MINT TESTS ============

    function test_Mint_NFT() public {
        vm.deal(user1, 1 ether);
        vm.prank(user1);
        nft.mint{value: 0.01 ether}("ipfs://QmTest123");

        assertEq(nft.ownerOf(0), user1);
        assertEq(nft.tokenURI(0), "ipfs://QmTest123");
        assertEq(nft.totalMinted(), 1);
        assertEq(nft.remaining(), 99);
    }

    function test_Mint_multiple_NFTs() public {
        vm.deal(user1, 1 ether);

        vm.prank(user1);
        nft.mint{value: 0.01 ether}("ipfs://QmToken0");

        vm.prank(user1);
        nft.mint{value: 0.01 ether}("ipfs://QmToken1");

        vm.prank(user1);
        nft.mint{value: 0.01 ether}("ipfs://QmToken2");

        assertEq(nft.totalMinted(), 3);
        assertEq(nft.ownerOf(0), user1);
        assertEq(nft.ownerOf(1), user1);
        assertEq(nft.ownerOf(2), user1);
    }

    function test_Mint_reverts_insufficient_payment() public {
        vm.deal(user1, 1 ether);
        vm.prank(user1);
        vm.expectRevert("Insufficient payment");
        nft.mint{value: 0.005 ether}("ipfs://QmTest");
    }

    function test_Mint_reverts_when_not_active() public {
        nft.toggleMinting(); // deactivate

        vm.deal(user1, 1 ether);
        vm.prank(user1);
        vm.expectRevert("Minting is not active");
        nft.mint{value: 0.01 ether}("ipfs://QmTest");
    }

    function test_Mint_reverts_at_max_supply() public {
        // Mint all 100
        for (uint256 i = 0; i < 100; i++) {
            vm.deal(user1, 1 ether);
            vm.prank(user1);
            nft.mint{value: 0.01 ether}("ipfs://QmTest");
        }

        // Try mint 101st
        vm.deal(user1, 1 ether);
        vm.prank(user1);
        vm.expectRevert("Max supply reached");
        nft.mint{value: 0.01 ether}("ipfs://QmTest");
    }

    // ============ OWNER MINT ============

    function test_OwnerMint() public {
        nft.ownerMint(user1, "ipfs://QmOwner");

        assertEq(nft.ownerOf(0), user1);
        assertEq(nft.tokenURI(0), "ipfs://QmOwner");
    }

    function test_OwnerMint_reverts_when_not_owner() public {
        vm.prank(user1);
        vm.expectRevert();
        nft.ownerMint(user2, "ipfs://QmTest");
    }

    // ============ ADMIN FUNCTIONS ============

    function test_SetMintPrice() public {
        nft.setMintPrice(0.05 ether);
        assertEq(nft.mintPrice(), 0.05 ether);
    }

    function test_SetMintPrice_reverts_when_not_owner() public {
        vm.prank(user1);
        vm.expectRevert();
        nft.setMintPrice(0.05 ether);
    }

    function test_ToggleMinting() public {
        nft.toggleMinting();
        assertFalse(nft.mintingActive());

        nft.toggleMinting();
        assertTrue(nft.mintingActive());
    }

    function test_ToggleMinting_reverts_when_not_owner() public {
        vm.prank(user1);
        vm.expectRevert();
        nft.toggleMinting();
    }

    // ============ PAYMENT GOES TO OWNER ============

    function test_Payment_goes_to_contract() public {
        vm.deal(user1, 1 ether);
        vm.prank(user1);
        nft.mint{value: 0.01 ether}("ipfs://QmTest");

        assertEq(address(nft).balance, 0.01 ether);
    }

    function test_Withdraw_sends_to_owner() public {
        vm.deal(user1, 1 ether);
        vm.prank(user1);
        nft.mint{value: 0.01 ether}("ipfs://QmTest");

        uint256 ownerBalBefore = owner.balance;
        nft.withdraw();
        assertEq(owner.balance - ownerBalBefore, 0.01 ether);
        assertEq(address(nft).balance, 0);
    }

    // ============ ETH CAN BE SENT TO CONTRACT ============

    function test_Receive_ETH() public {
        vm.deal(user1, 1 ether);
        vm.prank(user1);
        (bool success,) = address(nft).call{value: 0.5 ether}("");
        assertTrue(success);
        assertEq(address(nft).balance, 0.5 ether);
    }
}
