// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "../src/Modiefiers.sol";

contract ModifiersTest is Test {
    Modifiers public modifiers;
    address public owner = address(this);
    address public user1 = address(0x1);

    function setUp() public {
        modifiers = new Modifiers();
    }

    function test_InitialState() public view {
        assertEq(modifiers.owner(), owner);
        assertFalse(modifiers.paused());
        assertEq(modifiers.price(), 0.01 ether);
    }

    function test_PauseUnpause() public {
        modifiers.pause();
        assertTrue(modifiers.paused());
        
        modifiers.unpause();
        assertFalse(modifiers.paused());
    }

    function test_RevertPauseNotOwner() public {
        vm.prank(user1);
        vm.expectRevert("Not owner!");
        modifiers.pause();
    }

    function test_DoSomething() public {
        vm.deal(user1, 1 ether);
        vm.prank(user1);
        modifiers.doSomething{value: 0.01 ether}();
    }

    function test_RevertDoSomethingWhenPaused() public {
        modifiers.pause();
        vm.deal(user1, 1 ether);
        vm.prank(user1);
        vm.expectRevert("Contract is paused!");
        modifiers.doSomething{value: 0.01 ether}();
    }

    function test_RevertDoSomethingInsufficientETH() public {
        vm.deal(user1, 1 ether);
        vm.prank(user1);
        vm.expectRevert("Not enough ETH!");
        modifiers.doSomething{value: 0.009 ether}();
    }

    function test_SensitiveAction() public {
        modifiers.sensitiveAction();
    }

    function test_Withdraw() public {
        vm.deal(address(modifiers), 1 ether);
        uint256 balanceBefore = owner.balance;
        modifiers.withdraw();
        assertEq(owner.balance, balanceBefore + 1 ether);
    }

    receive() external payable {}
}

import "./RevertingContract.sol";

contract ModifiersFailTest is Test {
    Modifiers public modifiers;
    RevertingContract public reverter;

    function setUp() public {
        reverter = new RevertingContract();
        vm.prank(address(reverter));
        modifiers = new Modifiers();
    }

    function test_RevertIfWithdrawFails() public {
        vm.deal(address(modifiers), 1 ether);
        vm.prank(address(reverter));
        vm.expectRevert("Transfer failed.");
        modifiers.withdraw();
    }
}
