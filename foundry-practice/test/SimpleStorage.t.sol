// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "../src/SimpleStorage.sol";

contract SimpleStorageTest is Test {
    SimpleStorage public simpleStorage;

    event NumberUpdated(uint256 oldNumber, uint256 newNumber);

    function setUp() public {
        simpleStorage = new SimpleStorage();
    }

    function test_Store() public {
        vm.expectEmit(true, true, true, true);
        emit NumberUpdated(0, 42);
        simpleStorage.store(42);
        assertEq(simpleStorage.retrieve(), 42);
    }

    function test_StoreMultiple() public {
        simpleStorage.store(100);
        assertEq(simpleStorage.retrieve(), 100);
        
        vm.expectEmit(true, true, true, true);
        emit NumberUpdated(100, 200);
        simpleStorage.store(200);
        assertEq(simpleStorage.retrieve(), 200);
    }
}
