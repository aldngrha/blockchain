// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/SimpleStorage.sol";

contract SimpleStorageTest is Test {
    SimpleStorage simpleStorage;

    function setUp() public {
        simpleStorage = new SimpleStorage();
    }

    function test_StoreAndRetrieve() public {
        simpleStorage.store(42);
        assertEq(simpleStorage.retrieve(), 42);
    }

    function test_AddPerson() public {
        simpleStorage.addPerson("Alice", 7);
        (string memory name, uint256 number) = simpleStorage.getPerson(0);
        assertEq(name, "Alice");
        assertEq(number, 7);
    }

    function test_MultipleUsers() public {
        vm.prank(address(0x1));
        simpleStorage.store(10);

        vm.prank(address(0x2));
        simpleStorage.store(20);

        assertEq(simpleStorage.s_addressToNumber(address(0x1)), 10);
        assertEq(simpleStorage.s_addressToNumber(address(0x2)), 20);
        assertEq(simpleStorage.s_numberCount(), 2);
    }
}
