// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "../src/ErrorHandling.sol";

contract ErrorHandlingTest is Test {
    ErrorHandling public errorHandling;
    address public owner = address(this);
    address public user1 = address(0x1);
    address public user2 = address(0x2);

    function setUp() public {
        errorHandling = new ErrorHandling();
    }

    function test_Deposit() public {
        vm.prank(user1);
        errorHandling.deposit(100);
        assertEq(errorHandling.balances(user1), 100);
        assertEq(errorHandling.totalSupply(), 100);
    }

    function test_RevertDepositZeroAmount() public {
        vm.expectRevert("Amount must be greater than 0");
        errorHandling.deposit(0);
    }

    function test_RevertDepositExceedsMaxSupply() public {
        vm.expectRevert("Exceeds max supply");
        errorHandling.deposit(1001);
    }

    function test_Withdraw() public {
        vm.startPrank(user1);
        errorHandling.deposit(100);
        errorHandling.withdraw(40);
        assertEq(errorHandling.balances(user1), 60);
        assertEq(errorHandling.totalSupply(), 60);
        vm.stopPrank();
    }

    function test_RevertWithdrawZeroAmount() public {
        vm.expectRevert("Amount must be greater than 0");
        errorHandling.withdraw(0);
    }

    function test_RevertWithdrawInsufficientBalance() public {
        vm.prank(user1);
        errorHandling.deposit(50);
        vm.prank(user1);
        vm.expectRevert("Insufficient balance");
        errorHandling.withdraw(51);
    }

    function test_Transfer() public {
        vm.prank(user1);
        errorHandling.deposit(100);
        
        vm.prank(user1);
        errorHandling.transfer(user2, 40);
        
        assertEq(errorHandling.balances(user1), 60);
        assertEq(errorHandling.balances(user2), 40);
    }

    function test_RevertTransferZeroAddress() public {
        vm.prank(user1);
        errorHandling.deposit(100);
        vm.prank(user1);
        vm.expectRevert(ErrorHandling.ZeroAddress.selector);
        errorHandling.transfer(address(0), 50);
    }

    function test_RevertTransferInsufficientBalance() public {
        vm.prank(user1);
        errorHandling.deposit(50);
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(ErrorHandling.InsufficientBalance.selector, 50, 100));
        errorHandling.transfer(user2, 100);
    }

    function test_RevertTransferZeroAmount() public {
        vm.prank(user1);
        errorHandling.deposit(100);
        vm.prank(user1);
        vm.expectRevert(ErrorHandling.ZeroAmount.selector);
        errorHandling.transfer(user2, 0);
    }

    function test_Mint() public {
        errorHandling.mint(user1, 100);
        assertEq(errorHandling.balances(user1), 100);
        assertEq(errorHandling.totalSupply(), 100);
    }

    function test_RevertMintNotOwner() public {
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(ErrorHandling.NotOwner.selector, user1));
        errorHandling.mint(user2, 100);
    }

    function test_RevertMintExceedsMaxSupply() public {
        vm.expectRevert(abi.encodeWithSelector(ErrorHandling.ExceedsMaxSupply.selector, 0, 1000, 1001));
        errorHandling.mint(user1, 1001);
    }

    function test_Burn() public {
        vm.prank(user1);
        errorHandling.deposit(100);
        
        vm.prank(user1);
        errorHandling.burn(40);
        assertEq(errorHandling.balances(user1), 60);
        assertEq(errorHandling.totalSupply(), 60);
    }

    function test_RevertBurnInsufficientBalance() public {
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(ErrorHandling.InsufficientBalance.selector, 0, 10));
        errorHandling.burn(10);
    }
}
