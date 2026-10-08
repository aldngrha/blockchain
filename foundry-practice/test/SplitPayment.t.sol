// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "../src/SplitPayment.sol";

contract SplitPaymentTest is Test {
    SplitPayment public splitPayment;
    address public owner = address(this);
    address[] public wallets;
    uint256[] public percentages;

    function setUp() public {
        wallets.push(address(0x1));
        wallets.push(address(0x2));
        percentages.push(6000); // 60%
        percentages.push(4000); // 40%
        splitPayment = new SplitPayment(wallets, percentages);
    }

    function test_InitialRecipients() public view {
        SplitPayment.Recipient[] memory recipients = splitPayment.getRecipients();
        assertEq(recipients.length, 2);
        assertEq(recipients[0].wallet, wallets[0]);
        assertEq(recipients[0].percentage, percentages[0]);
    }

    function test_ReceivePayment() public {
        vm.deal(address(0x3), 1 ether);
        vm.prank(address(0x3));
        (bool success, ) = address(splitPayment).call{value: 1 ether}("");
        assertTrue(success);

        assertEq(splitPayment.totalReceived(), 1 ether);
        assertEq(splitPayment.paymentCount(), 1);
        assertEq(splitPayment.balances(wallets[0]), 0.6 ether);
        assertEq(splitPayment.balances(wallets[1]), 0.4 ether);

        SplitPayment.Payment memory p = splitPayment.getPayment(1);
        assertEq(p.payer, address(0x3));
        assertEq(p.amount, 1 ether);
    }

    function test_Withdraw() public {
        vm.deal(address(0x3), 1 ether);
        vm.prank(address(0x3));
        (bool success, ) = address(splitPayment).call{value: 1 ether}("");
        assertTrue(success);

        uint256 balanceBefore = wallets[0].balance;
        vm.prank(wallets[0]);
        splitPayment.withdraw();
        assertEq(wallets[0].balance, balanceBefore + 0.6 ether);
        assertEq(splitPayment.balances(wallets[0]), 0);
    }

    function test_UpdateSplit() public {
        address[] memory newWallets = new address[](1);
        newWallets[0] = address(0x4);
        uint256[] memory newPercentages = new uint256[](1);
        newPercentages[0] = 10000;

        splitPayment.updateSplit(newWallets, newPercentages);
        
        SplitPayment.Recipient[] memory recipients = splitPayment.getRecipients();
        assertEq(recipients.length, 1);
        assertEq(recipients[0].wallet, address(0x4));
    }

    function test_RevertUpdateSplitNotOwner() public {
        vm.prank(address(0x1));
        vm.expectRevert(abi.encodeWithSelector(SplitPayment.NotOwner.selector, address(0x1)));
        splitPayment.updateSplit(wallets, percentages);
    }

    function test_RevertInvalidPercentage() public {
        percentages[0] = 5000;
        vm.expectRevert(abi.encodeWithSelector(SplitPayment.InvalidPercentageTotal.selector, 9000));
        new SplitPayment(wallets, percentages);
    }

    function test_RevertArrayMismatch() public {
        uint256[] memory shortPercentages = new uint256[](1);
        shortPercentages[0] = 10000;
        vm.expectRevert(SplitPayment.ArrayLengthMismatch.selector);
        new SplitPayment(wallets, shortPercentages);
    }

    function test_RevertZeroPayment() public {
        vm.expectRevert(SplitPayment.ZeroPayment.selector);
        (bool success, ) = address(splitPayment).call{value: 0}(""); success;
    }

    function test_RevertWithdrawNothing() public {
        vm.prank(address(0x1));
        vm.expectRevert(SplitPayment.NothingToWithdraw.selector);
        splitPayment.withdraw();
    }

    receive() external payable {}
}

import "./RevertingContract.sol";

contract SplitPaymentFailTest is Test {
    SplitPayment public splitPayment;
    RevertingContract public reverter;

    function setUp() public {
        reverter = new RevertingContract();
        address[] memory wallets = new address[](1);
        wallets[0] = address(reverter);
        uint256[] memory percentages = new uint256[](1);
        percentages[0] = 10000;
        splitPayment = new SplitPayment(wallets, percentages);
    }

    function test_RevertIfWithdrawFails() public {
        vm.deal(address(0x1), 1 ether);
        vm.prank(address(0x1));
        (bool success, ) = address(splitPayment).call{value: 1 ether}("");
        assertTrue(success);

        vm.prank(address(reverter));
        vm.expectRevert("Transfer failed.");
        splitPayment.withdraw();
    }
}
