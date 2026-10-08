// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "../src/DataTypes.sol";

contract DataTypesTest is Test {
    DataTypes public dataTypes;

    function setUp() public {
        dataTypes = new DataTypes();
    }

    function test_InitialValues() public view {
        assertEq(dataTypes.bigNumber(), 1000);
        assertEq(dataTypes.signedNum(), -500);
        assertEq(dataTypes.smallNum(), 255);
        assertTrue(dataTypes.isActive());
        assertEq(dataTypes.owner(), 0x1234567890123456789012345678901234567890);
        assertEq(dataTypes.data(), "hello");
        assertEq(dataTypes.dynamicData(), "hello");
        assertEq(dataTypes.name(), "Aldi");
    }

    function test_PublicFunc() public view {
        assertEq(dataTypes.publicFunc(), "siapapun bisa panggil ini");
    }

    function test_ExternalFunc() public view {
        assertEq(dataTypes.externalFunc(), "hanya dari luar kontrak");
    }

    function test_GetOwner() public view {
        assertEq(dataTypes.getOwner(), 0x1234567890123456789012345678901234567890);
    }

    function test_Add() public view {
        assertEq(dataTypes.add(10, 20), 30);
    }

    function test_DepositAndBalance() public {
        vm.deal(address(this), 1 ether);
        dataTypes.deposit{value: 1 ether}();
        assertEq(dataTypes.getBalance(), 1 ether);
    }
}
