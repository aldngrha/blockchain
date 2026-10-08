// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "../src/WhitelistMinter.sol";

contract WhitelistMinterTest is Test {
    WhitelistMinter public minter;
    address public owner = address(this);
    address public user1 = address(0x1);
    address public user2 = address(0x2);

    function setUp() public {
        minter = new WhitelistMinter(10, 0.1 ether);
    }

    function test_InitialState() public view {
        assertEq(minter.maxSupply(), 10);
        assertEq(minter.mintPrice(), 0.1 ether);
        assertEq(minter.owner(), owner);
    }

    function test_AddToWhitelist() public {
        minter.addToWhitelist(user1);
        assertTrue(minter.whitelist(user1));
    }

    function test_AddBatchToWhitelist() public {
        address[] memory users = new address[](2);
        users[0] = user1;
        users[1] = user2;
        minter.addBatchToWhitelist(users);
        assertTrue(minter.whitelist(user1));
        assertTrue(minter.whitelist(user2));
    }

    function test_RemoveFromWhitelist() public {
        minter.addToWhitelist(user1);
        minter.removeFromWhitelist(user1);
        assertFalse(minter.whitelist(user1));
    }

    function test_Mint() public {
        minter.addToWhitelist(user1);
        vm.deal(user1, 1 ether);
        vm.prank(user1);
        minter.mint{value: 0.1 ether}(1);
        
        assertEq(minter.totalMinted(), 1);
        assertEq(minter.mintedCount(user1), 1);
        assertEq(minter.remainingSupply(), 9);
    }

    function test_MintWithRefund() public {
        minter.addToWhitelist(user1);
        vm.deal(user1, 1 ether);
        uint256 balanceBefore = user1.balance;
        vm.prank(user1);
        minter.mint{value: 0.5 ether}(1);
        
        assertEq(user1.balance, balanceBefore - 0.1 ether);
    }

    function test_RevertMintNotWhitelisted() public {
        vm.deal(user1, 1 ether);
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(WhitelistMinter.NotWhitelisted.selector, user1));
        minter.mint{value: 0.1 ether}(1);
    }

    function test_RevertMintInsufficientPayment() public {
        minter.addToWhitelist(user1);
        vm.deal(user1, 1 ether);
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(WhitelistMinter.InsufficientPayment.selector, 0.05 ether, 0.1 ether));
        minter.mint{value: 0.05 ether}(1);
    }

    function test_RevertMintExceedsSupply() public {
        minter.addToWhitelist(user1);
        vm.deal(user1, 2 ether);
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(WhitelistMinter.ExceedsMaxSupply.selector, 11, 10));
        minter.mint{value: 1.1 ether}(11);
    }

    function test_PauseUnpause() public {
        minter.pause();
        assertTrue(minter.paused());
        
        minter.addToWhitelist(user1);
        vm.deal(user1, 1 ether);
        vm.prank(user1);
        // Using string signature because of inheritance visibility in same file
        vm.expectRevert(abi.encodeWithSignature("ContractPaused()"));
        minter.mint{value: 0.1 ether}(1);

        minter.unpause();
        vm.prank(user1);
        minter.mint{value: 0.1 ether}(1);
    }

    function test_Withdraw() public {
        minter.addToWhitelist(user1);
        vm.deal(user1, 1 ether);
        vm.prank(user1);
        minter.mint{value: 0.1 ether}(1);

        uint256 balanceBefore = owner.balance;
        minter.withdraw();
        assertEq(owner.balance, balanceBefore + 0.1 ether);
    }

    function test_TransferOwnership() public {
        minter.transferOwnership(user1);
        assertEq(minter.owner(), user1);
    }

    function test_RevertTransferOwnershipZeroAddress() public {
        vm.expectRevert("Zero address");
        minter.transferOwnership(address(0));
    }

    function test_RevertAlreadyWhitelisted() public {
        minter.addToWhitelist(user1);
        vm.expectRevert(abi.encodeWithSelector(WhitelistMinter.AlreadyWhitelisted.selector, user1));
        minter.addToWhitelist(user1);
    }

    function test_RevertNotInWhitelist() public {
        vm.expectRevert(abi.encodeWithSelector(WhitelistMinter.NotInWhitelist.selector, user1));
        minter.removeFromWhitelist(user1);
    }

    function test_AddBatchToWhitelist_Mixed() public {
        minter.addToWhitelist(user1);
        address[] memory users = new address[](2);
        users[0] = user1; // already whitelisted
        users[1] = user2; // new
        minter.addBatchToWhitelist(users);
        assertTrue(minter.whitelist(user1));
        assertTrue(minter.whitelist(user2));
    }

    receive() external payable {}
}

import "./RevertingContract.sol";

contract WhitelistMinterRefundFailTest is Test {
    WhitelistMinter public minter;
    RevertingContract public reverter;

    function setUp() public {
        minter = new WhitelistMinter(10, 0.1 ether);
        reverter = new RevertingContract();
    }

    function test_RevertIfRefundFails() public {
        minter.addToWhitelist(address(reverter));
        vm.deal(address(reverter), 1 ether);
        
        vm.prank(address(reverter));
        vm.expectRevert("Refund failed.");
        minter.mint{value: 0.2 ether}(1);
    }
}
