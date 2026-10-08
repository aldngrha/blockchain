import "./RevertingContract.sol";
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "../src/NFT.sol";

contract NFTExtraTest is Test {
    AldiNFT nft;
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    function setUp() public {
        // Small max supply for testing supply limits
        nft = new AldiNFT("AldiNFT", "ALDI", 2, 0.01 ether, 2);
        vm.deal(alice, 1 ether);
    }

    function test_RevertMintExceedsMaxSupply() public {
        vm.startPrank(alice);
        nft.mint{value: 0.01 ether}("URI1");
        nft.mint{value: 0.01 ether}("URI2");
        
        vm.expectRevert(abi.encodeWithSelector(AldiNFT.ExceedsMaxSupply.selector, 1, 0));
        nft.mint{value: 0.01 ether}("URI3");
        vm.stopPrank();
    }

    function test_RevertOwnerMintExceedsMaxSupply() public {
        nft.ownerMint(alice, "URI1");
        nft.ownerMint(alice, "URI2");
        
        vm.expectRevert(abi.encodeWithSelector(AldiNFT.ExceedsMaxSupply.selector, 1, 0));
        nft.ownerMint(alice, "URI3");
    }

    function test_SetMintPrice() public {
        nft.setMintPrice(0.02 ether);
        assertEq(nft.mintPrice(), 0.02 ether);
    }

    function test_RevertSetMintPriceNotOwner() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        nft.setMintPrice(0.02 ether);
    }

    function test_RevertPauseNotOwner() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        nft.pause();
    }

    function test_RevertWithdrawNotOwner() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        nft.withdraw();
    }

    function test_RevertOwnerMintNotOwner() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        nft.ownerMint(bob, "URI");
    }

    function test_TransferWhilePaused() public {
        vm.prank(alice);
        nft.mint{value: 0.01 ether}("URI1");
        
        nft.pause();
        
        vm.prank(alice);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        nft.transferFrom(alice, bob, 1);
        
        nft.unpause();
        vm.prank(alice);
        nft.transferFrom(alice, bob, 1);
        assertEq(nft.ownerOf(1), bob);
    }

    function test_TokensOfOwner_Empty() public view {
        uint256[] memory tokens = nft.tokensOfOwner(alice);
        assertEq(tokens.length, 0);
    }

    function test_TokensOfOwner_MultipleOwners() public {
        nft.ownerMint(alice, "A1");
        nft.ownerMint(bob, "B1");
        
        uint256[] memory aliceTokens = nft.tokensOfOwner(alice);
        assertEq(aliceTokens.length, 1);
        assertEq(aliceTokens[0], 1);
        
        uint256[] memory bobTokens = nft.tokensOfOwner(bob);
        assertEq(bobTokens.length, 1);
        assertEq(bobTokens[0], 2);
    }
}

contract NFTWithdrawFailTest is Test {
    AldiNFT nft;
    RevertingContract reverter;

    function setUp() public {
        reverter = new RevertingContract();
        // Deploy NFT with reverter as owner (by pranking reverter during deployment)
        vm.prank(address(reverter));
        nft = new AldiNFT("AldiNFT", "ALDI", 100, 0.01 ether, 10);
    }

    function test_RevertIfWithdrawFails() public {
        vm.deal(address(0x1), 1 ether);
        vm.prank(address(0x1));
        nft.mint{value: 0.01 ether}("URI");

        vm.prank(address(reverter));
        vm.expectRevert("Withdraw failed");
        nft.withdraw();
    }
}
