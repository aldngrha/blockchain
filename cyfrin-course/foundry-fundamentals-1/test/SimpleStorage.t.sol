// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {SimpleStorage} from "../src/SimpleStorage.sol";
import {DeploySimpleStorage} from "../script/DeploySimpleStorage.s.sol";

contract SimpleStorageTest is Test {
    SimpleStorage public simpleStorage;

    function setUp() public {
        DeploySimpleStorage deployer = new DeploySimpleStorage();
        simpleStorage = deployer.run();
    }

    function testInitialFavoriteNumberIsZero() public {
        assertEq(simpleStorage.retrieve(), 0);
    }

    function testStoreFavoriteNumber() public {
        uint256 favoriteNumber = 7;
        simpleStorage.store(favoriteNumber);
        assertEq(simpleStorage.retrieve(), favoriteNumber);
    }

    function testAddPerson() public {
        string memory name = "Patrick";
        uint256 favoriteNumber = 7;

        simpleStorage.addPerson(name, favoriteNumber);

        (uint256 storedFavoriteNumber, string memory storedName) = simpleStorage.listOfPeople(0);
        assertEq(storedFavoriteNumber, favoriteNumber);
        assertEq(storedName, name);

        assertEq(simpleStorage.nameToFavoriteNumber(name), favoriteNumber);
    }
}
