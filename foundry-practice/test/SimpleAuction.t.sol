// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "../src/SimpleAuction.sol";

contract SimpleAuctionTest is Test {
    SimpleAuction public auction;
    address public owner = address(this);
    address public bidder1 = address(0x1);
    address public bidder2 = address(0x2);
    uint256 public duration = 1 hours;

    event NewBid(address indexed bidder, uint256 amount);
    event AuctionEnded(address indexed winner, uint256 amount);
    event Withdrawn(address indexed bidder, uint256 amount);

    function setUp() public {
        auction = new SimpleAuction(duration);
    }

    function test_Bid() public {
        vm.deal(bidder1, 1 ether);
        vm.prank(bidder1);
        vm.expectEmit(true, true, true, true);
        emit NewBid(bidder1, 0.5 ether);
        auction.bid{value: 0.5 ether}();

        assertEq(auction.highestBidder(), bidder1);
        assertEq(auction.highestBid(), 0.5 ether);
    }

    function test_HigherBid() public {
        vm.deal(bidder1, 1 ether);
        vm.prank(bidder1);
        auction.bid{value: 0.5 ether}();

        vm.deal(bidder2, 2 ether);
        vm.prank(bidder2);
        auction.bid{value: 0.8 ether}();

        assertEq(auction.highestBidder(), bidder2);
        assertEq(auction.highestBid(), 0.8 ether);
        assertEq(auction.pendingReturns(bidder1), 0.5 ether);
    }

    function test_RevertBidTooLow() public {
        vm.deal(bidder1, 1 ether);
        vm.prank(bidder1);
        auction.bid{value: 0.5 ether}();

        vm.deal(bidder2, 1 ether);
        vm.prank(bidder2);
        vm.expectRevert(abi.encodeWithSelector(SimpleAuction.BidTooLow.selector, 0.5 ether, 0.5 ether + 1));
        auction.bid{value: 0.4 ether}();
    }

    function test_RevertBidAuctionEnded() public {
        vm.warp(block.timestamp + duration + 1);
        vm.deal(bidder1, 1 ether);
        vm.prank(bidder1);
        vm.expectRevert(SimpleAuction.AuctionAlreadyEnded.selector);
        auction.bid{value: 0.5 ether}();
    }

    function test_Withdraw() public {
        vm.deal(bidder1, 1 ether);
        vm.prank(bidder1);
        auction.bid{value: 0.5 ether}();

        vm.deal(bidder2, 1 ether);
        vm.prank(bidder2);
        auction.bid{value: 0.8 ether}();

        uint256 balanceBefore = bidder1.balance;
        vm.prank(bidder1);
        vm.expectEmit(true, true, true, true);
        emit Withdrawn(bidder1, 0.5 ether);
        auction.withdraw();
        assertEq(bidder1.balance, balanceBefore + 0.5 ether);
        assertEq(auction.pendingReturns(bidder1), 0);
    }

    function test_RevertWithdrawNothing() public {
        vm.prank(bidder1);
        vm.expectRevert(SimpleAuction.NothingToWithdraw.selector);
        auction.withdraw();
    }

    function test_EndAuction() public {
        vm.deal(bidder1, 1 ether);
        vm.prank(bidder1);
        auction.bid{value: 0.5 ether}();

        vm.warp(block.timestamp + duration + 1);
        
        uint256 balanceBefore = owner.balance;
        vm.expectEmit(true, true, true, true);
        emit AuctionEnded(bidder1, 0.5 ether);
        auction.endAuction();
        
        assertTrue(auction.ended());
        assertEq(owner.balance, balanceBefore + 0.5 ether);
    }

    function test_RevertEndAuctionNotOwner() public {
        vm.warp(block.timestamp + duration + 1);
        vm.prank(bidder1);
        vm.expectRevert(abi.encodeWithSelector(SimpleAuction.NotOwner.selector, bidder1));
        auction.endAuction();
    }

    function test_RevertEndAuctionTooEarly() public {
        vm.expectRevert(SimpleAuction.AuctionNotYetEnded.selector);
        auction.endAuction();
    }

    function test_RevertEndAuctionAlreadyCalled() public {
        vm.warp(block.timestamp + duration + 1);
        auction.endAuction();
        vm.expectRevert(SimpleAuction.AuctionEndAlreadyCalled.selector);
        auction.endAuction();
    }

    function test_TimeRemaining() public {
        assertEq(auction.timeRemaining(), duration);
        vm.warp(block.timestamp + 30 minutes);
        assertEq(auction.timeRemaining(), 30 minutes);
        vm.warp(block.timestamp + 40 minutes);
        assertEq(auction.timeRemaining(), 0);
    }

    function test_RevertBidAfterAuctionEnded() public {
        vm.warp(block.timestamp + duration + 1);
        auction.endAuction();
        
        vm.deal(bidder1, 1 ether);
        vm.prank(bidder1);
        vm.expectRevert(SimpleAuction.AuctionAlreadyEnded.selector);
        auction.bid{value: 0.5 ether}();
    }

    receive() external payable {}
}

import "./RevertingContract.sol";

contract SimpleAuctionFailTest is Test {
    SimpleAuction public auction;
    RevertingContract public reverter;

    function setUp() public {
        auction = new SimpleAuction(1 hours);
        reverter = new RevertingContract();
    }

    function test_RevertIfWithdrawFails() public {
        vm.deal(address(0x1), 1 ether);
        vm.prank(address(0x1));
        auction.bid{value: 0.1 ether}();

        vm.deal(address(reverter), 1 ether);
        vm.prank(address(reverter));
        auction.bid{value: 0.2 ether}();

        // address(0x1) is now in pendingReturns.
        // Let's make reverter the one who gets outbid
        vm.deal(address(0x2), 1 ether);
        vm.prank(address(0x2));
        auction.bid{value: 0.3 ether}();

        // reverter is now in pendingReturns[reverter] = 0.2 ether
        vm.prank(address(reverter));
        vm.expectRevert("Transfer failed.");
        auction.withdraw();
    }

    function test_RevertIfEndAuctionTransferFails() public {
        // Owner is reverter
        vm.startPrank(address(0x1));
        new SimpleAuction(1 hours);
        // Transfer ownership to reverter
        // Wait, SimpleAuction has owner set in constructor.
        // I'll deploy it FROM reverter or just a contract that reverts.
        vm.stopPrank();
        
        // Actually, I'll just deploy a new auction where the reverter IS the owner.
        vm.prank(address(reverter));
        SimpleAuction auctionWithRevertingOwner = new SimpleAuction(1 hours);
        
        vm.deal(address(0x1), 1 ether);
        vm.prank(address(0x1));
        auctionWithRevertingOwner.bid{value: 0.1 ether}();
        
        vm.warp(block.timestamp + 2 hours);
        
        vm.prank(address(reverter));
        vm.expectRevert("Transfer failed.");
        auctionWithRevertingOwner.endAuction();
    }
}
