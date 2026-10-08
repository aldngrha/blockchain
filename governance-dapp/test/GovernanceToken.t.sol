// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {GovernanceToken} from "../src/GovernanceToken.sol";

/// @title GovernanceToken test suite (roadmap Sel 22 Sep).
/// @notice Covers: fixed supply mint, delegation (self/other), the "voting power
///         only exists after delegate()" rule, and historic lookups (getPastVotes /
///         getPastTotalSupply) using vm.roll. The token clock is block number (ERC-6372).
contract GovernanceTokenTest is Test {
    GovernanceToken internal token;

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal carol = makeAddr("carol");

    uint256 internal constant SUPPLY = 1_000_000e18;

    function setUp() public {
        // The test contract is msg.sender at deployment, so it receives the whole supply.
        token = new GovernanceToken();
    }

    /*//////////////////////////////////
            METADATA & INITIAL STATE
    //////////////////////////////////*/

    function test_Name() public view {
        assertEq(token.name(), "Governance Token");
    }

    function test_Symbol() public view {
        assertEq(token.symbol(), "GT");
    }

    function test_Decimals() public view {
        assertEq(token.decimals(), 18);
    }

    function test_FixedSupplyMintedToDeployer() public view {
        assertEq(token.totalSupply(), SUPPLY, "fixed supply 1M GT");
        assertEq(token.balanceOf(address(this)), SUPPLY, "deployer holds everything");
        assertEq(token.balanceOf(alice), 0);
    }

    function test_BalanceIsNotVotingPowerUntilDelegate() public {
        token.transfer(alice, 100e18);
        assertEq(token.balanceOf(alice), 100e18);
        // The core ERC20Votes rule: no delegation, no voting weight.
        assertEq(token.getVotes(alice), 0, "votes must be 0 before delegate()");
    }

    /*//////////////////////////////////
                DELEGATION
    //////////////////////////////////*/

    function test_DelegateToSelfActivatesVotes() public {
        token.transfer(alice, 100e18);
        vm.prank(alice);
        token.delegate(alice);
        assertEq(token.getVotes(alice), 100e18);
        assertEq(token.delegates(alice), alice);
    }

    function test_DelegateToOtherAddressMovesWeight() public {
        token.transfer(alice, 100e18);
        vm.prank(alice);
        token.delegate(carol);
        // Carol holds no tokens but holds alice's voting weight.
        assertEq(token.getVotes(carol), 100e18);
        assertEq(token.getVotes(alice), 0);
        assertEq(token.delegates(alice), carol);
        assertEq(token.delegates(carol), address(0), "carol did not delegate herself");
    }

    function test_TransferMovesVotingPowerOnlyAfterBothDelegate() public {
        // Both sides delegate FIRST (while holding 0), then a transfer moves weight 1:1.
        vm.prank(alice);
        token.delegate(alice);
        vm.prank(bob);
        token.delegate(bob);

        token.transfer(alice, 100e18);
        vm.prank(alice);
        token.transfer(bob, 60e18);

        assertEq(token.getVotes(alice), 40e18, "sender keeps weight for what is left");
        assertEq(token.getVotes(bob), 60e18, "receiver gains weight after transfer");
    }

    function test_TransferToNonDelegatedReceiverDestroysWeight() public {
        // Alice delegated, bob is not. Weight leaving alice has nowhere to land:
        // it is destroyed until bob delegates. This is the behavior the frontend
        // must warn users about (delegate before holding tokens).
        vm.prank(alice);
        token.delegate(alice);

        token.transfer(alice, 100e18);
        vm.prank(alice);
        token.transfer(bob, 60e18);

        assertEq(token.getVotes(alice), 40e18);
        assertEq(token.getVotes(bob), 0, "bob never delegated, weight is gone for him");
        assertEq(token.balanceOf(bob), 60e18, "but his token balance is real");

        // Delegating later activates the full balance at THAT block, not retroactively.
        vm.prank(bob);
        token.delegate(bob);
        assertEq(token.getVotes(bob), 60e18);
    }

    /*//////////////////////////////////
            HISTORIC LOOKUPS (vm.roll)
    //////////////////////////////////*/

    function test_PastVotesAtHistoricBlocks() public {
        // forge starts every test at block 1. Guard it: the hardcoded roll targets
        // below depend on that.
        assertEq(block.number, 1, "forge default start block");

        // Block 1: alice receives 100 GT and delegates to herself.
        token.transfer(alice, 100e18);
        vm.prank(alice);
        token.delegate(alice);

        // Block 2: alice sends 40 GT to bob, bob activates his weight.
        // NOTE: targets are ABSOLUTE block numbers, never `block.number + n`. Under
        // via-ir the optimizer re-derives expressions rooted at block properties at
        // their USE site (block.* is constant per EVM transaction), so a local like
        // `uint256 b = block.number` silently changes value across vm.roll calls.
        // Hardcoded targets keep the test deterministic.
        vm.roll(2);
        vm.prank(alice);
        token.transfer(bob, 40e18);
        vm.prank(bob);
        token.delegate(bob);

        // Block 3: look into the past.
        uint256 delegationBlock = 1;
        uint256 transferBlock = 2;
        vm.roll(transferBlock + 1);

        // Value at the END of block N includes actions mined in block N.
        assertEq(token.getPastVotes(alice, delegationBlock), 100e18, "snapshot at delegation block");
        assertEq(token.getPastVotes(alice, transferBlock), 60e18, "snapshot after outgoing transfer");
        assertEq(token.getPastVotes(bob, transferBlock), 40e18);
        assertEq(token.getVotes(alice), 60e18, "current weight");

        // Supply was minted at deployment (block 1), so it is 1M from block 1 on.
        assertEq(token.getPastTotalSupply(delegationBlock), SUPPLY, "past total supply");
        assertEq(token.getPastTotalSupply(1), SUPPLY);
    }

    function test_FutureLookupReverts() public {
        vm.expectRevert();
        token.getPastVotes(alice, block.number); // current block is still "future"
    }

    function test_FutureTotalSupplyLookupReverts() public {
        vm.expectRevert();
        token.getPastTotalSupply(block.number + 1);
    }

    /*//////////////////////////////////
                FUZZ
    //////////////////////////////////*/

    function testFuzz_DelegateToSelfMakesVotesMatchBalance(uint256 amount) public {
        amount = bound(amount, 0, SUPPLY);
        token.transfer(alice, amount);
        vm.prank(alice);
        token.delegate(alice);
        assertEq(token.getVotes(alice), amount);
        assertEq(token.balanceOf(alice), amount);
    }

    function testFuzz_ReDelegateRedirectsAllWeight(uint256 amount, bool toSelf) public {
        amount = bound(amount, 1, SUPPLY);
        token.transfer(alice, amount);

        vm.prank(alice);
        token.delegate(alice);
        assertEq(token.getVotes(alice), amount);

        address target = toSelf ? alice : carol;
        vm.prank(alice);
        token.delegate(target);

        assertEq(token.getVotes(target), amount);
        assertEq(token.getVotes(alice), toSelf ? amount : 0);
        assertEq(token.totalSupply(), SUPPLY, "supply never changes");
    }
}
