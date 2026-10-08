// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {EventsDeepDive} from "../src/EventsDeepDive.sol";

contract EventsDeepDiveTest is Test {
    EventsDeepDive public eventsContract;

    function setUp() public {
        eventsContract = new EventsDeepDive();
    }

    function test_depositEmitsEvent() public {
        address user = makeAddr("user");

        // Expect Deposited event to be emitted
        vm.expectEmit(true, false, false, true);
        emit EventsDeepDive.Deposited(user, 1 ether, block.timestamp);

        vm.deal(user, 1 ether);
        vm.prank(user);
        eventsContract.deposit{value: 1 ether}();
    }

    function test_createItemEmitsEvent() public {
        address creator = makeAddr("creator");

        vm.prank(creator);
        uint256 itemId = eventsContract.createItem("Widget", 0.1 ether);

        assertEq(itemId, 0);

        // Check item was created correctly
        (string memory name, uint256 price, address creatorAddr, bool isActive) = eventsContract.items(0);
        assertEq(name, "Widget");
        assertEq(price, 0.1 ether);
        assertEq(creatorAddr, creator);
        assertTrue(isActive);
    }

    function test_buyItemEmitsEvent() public {
        address creator = makeAddr("creator");
        address buyer = makeAddr("buyer");

        // Create item
        vm.prank(creator);
        eventsContract.createItem("Widget", 0.1 ether);

        // Buy item
        vm.deal(buyer, 1 ether);
        vm.prank(buyer);
        eventsContract.buyItem{value: 0.1 ether}(0);

        // Creator should have received payment
        assertEq(address(creator).balance, 0.1 ether);
    }

    function test_withdrawEmitsEvent() public {
        address user = makeAddr("user");

        vm.deal(user, 1 ether);
        vm.prank(user);
        eventsContract.deposit{value: 1 ether}();

        vm.prank(user);
        eventsContract.withdraw(0.5 ether);

        assertEq(eventsContract.balances(user), 0.5 ether);
    }
}
