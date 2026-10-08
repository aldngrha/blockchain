// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "../src/AdvancedStorage.sol";

contract AdvancedStorageTest is Test {
    AdvancedStorage public advancedStorage;
    address public owner = address(this);
    address public user1 = address(0x1);
    address public user2 = address(0x2);

    event EntryCreated(uint256 indexed id, address indexed creator, string data);
    event EntryDeleted(uint256 indexed id, address indexed deletedBy);
    event ContractPaused(address indexed by);
    event ContractUnpaused(address indexed by);

    function setUp() public {
        advancedStorage = new AdvancedStorage();
    }

    function test_CreateEntry() public {
        vm.startPrank(user1);
        vm.expectEmit(true, true, true, true);
        emit EntryCreated(1, user1, "Hello World");
        advancedStorage.createEntry("Hello World");
        vm.stopPrank();

        AdvancedStorage.Entry memory entry = advancedStorage.getEntry(1);
        assertEq(entry.id, 1);
        assertEq(entry.data, "Hello World");
        assertEq(entry.creator, user1);
        assertEq(entry.timestamp, block.timestamp);

        uint256[] memory userEntries = advancedStorage.getUserEntries(user1);
        assertEq(userEntries.length, 1);
        assertEq(userEntries[0], 1);
    }

    function test_RevertCreateEntryWhenPaused() public {
        advancedStorage.pause();
        vm.expectRevert(AdvancedStorage.ContractIsPaused.selector);
        advancedStorage.createEntry("Data");
    }

    function test_RevertCreateEntryEmptyData() public {
        vm.expectRevert(AdvancedStorage.EmptyData.selector);
        advancedStorage.createEntry("");
    }

    function test_DeleteEntryByCreator() public {
        vm.prank(user1);
        advancedStorage.createEntry("Data");

        vm.prank(user1);
        vm.expectEmit(true, true, true, true);
        emit EntryDeleted(1, user1);
        advancedStorage.deleteEntry(1);

        vm.expectRevert(abi.encodeWithSelector(AdvancedStorage.EntryNotFound.selector, 1));
        advancedStorage.getEntry(1);
    }

    function test_DeleteEntryByOwner() public {
        vm.prank(user1);
        advancedStorage.createEntry("Data");

        vm.expectEmit(true, true, true, true);
        emit EntryDeleted(1, owner);
        advancedStorage.deleteEntry(1);
    }

    function test_RevertDeleteEntryNotCreatorOrOwner() public {
        vm.prank(user1);
        advancedStorage.createEntry("Data");

        vm.prank(user2);
        vm.expectRevert(abi.encodeWithSelector(AdvancedStorage.NotCreator.selector, user2, 1));
        advancedStorage.deleteEntry(1);
    }

    function test_RevertDeleteEntryNotFound() public {
        vm.expectRevert(abi.encodeWithSelector(AdvancedStorage.EntryNotFound.selector, 999));
        advancedStorage.deleteEntry(999);
    }

    function test_PauseUnpause() public {
        vm.expectEmit(true, true, true, true);
        emit ContractPaused(owner);
        advancedStorage.pause();
        assertTrue(advancedStorage.paused());

        vm.expectEmit(true, true, true, true);
        emit ContractUnpaused(owner);
        advancedStorage.unpause();
        assertFalse(advancedStorage.paused());
    }

    function test_RevertPauseNotOwner() public {
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(AdvancedStorage.NotOwner.selector, user1));
        advancedStorage.pause();
    }

    function test_DeleteEntryByOwnerWhoIsCreator() public {
        advancedStorage.createEntry("Data");
        advancedStorage.deleteEntry(1);
    }
}
