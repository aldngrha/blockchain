// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {RewardToken} from "../src/RewardToken.sol";
import {StakingPool} from "../src/StakingPool.sol";
import {IERC20} from "./interfaces/IERC20Events.sol";
import {IStakingPoolEvents} from "./interfaces/IStakingPoolEvents.sol";

/// @title Test suite StakingPool core (Min 13 Sep) — TDD fase merah.
/// @notice Scope HARI INI: stake/unstake/emergencyWithdraw + edge cases E1-E6, E17.
///         Reward math E8-E12 menyusul besok (Sen 14 Sep).
contract StakingPoolCoreTest is Test {
    RewardToken internal token;
    StakingPool internal pool;

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal carol = makeAddr("carol");

    uint256 constant LIQ = 1_000_000e18;

    function setUp() public {
        token = new RewardToken("Staking Reward Token", "SRT", LIQ);
        pool = new StakingPool(address(token));
        token.setStakingPool(address(pool));

        token.transfer(alice, 10_000e18);
        token.transfer(bob, 10_000e18);
        token.transfer(carol, 10_000e18);
    }

    /*//////////////////////////////////
              DEPLOY & STATE AWAL
    //////////////////////////////////*/

    function test_InitialState() public view {
        assertEq(address(pool.rewardToken()), address(token));
        assertEq(pool.totalStaked(), 0);
    }

    /*//////////////////////////////////
              STAKE (happy path)
    //////////////////////////////////*/

    function test_StakeMovesTokenToPool() public {
        vm.startPrank(alice);
        token.approve(address(pool), 100e18);
        pool.stake(100e18);
        vm.stopPrank();

        assertEq(pool.getStakedBalance(alice), 100e18);
        assertEq(pool.getTotalStaked(), 100e18);
        assertEq(token.balanceOf(address(pool)), 100e18, "token harus pindah ke pool");
        assertEq(token.balanceOf(alice), 10_000e18 - 100e18);
    }

    function test_StakeMultipleTimesAccumulates() public {
        vm.startPrank(alice);
        token.approve(address(pool), 300e18);
        pool.stake(100e18);
        pool.stake(200e18);
        vm.stopPrank();

        assertEq(pool.getStakedBalance(alice), 300e18);
        assertEq(pool.getTotalStaked(), 300e18);
    }

    function test_StakeEmitsEvent() public {
        vm.startPrank(alice);
        token.approve(address(pool), 100e18);
        vm.expectEmit(true, true, true, true);
        emit IStakingPoolEvents.Staked(alice, 100e18);
        pool.stake(100e18);
        vm.stopPrank();
    }

    function test_StakeWithoutApprovalReverts() public {
        vm.prank(alice);
        vm.expectRevert();
        pool.stake(100e18); // allowance 0 -> ERC20InsufficientAllowance
    }

    /*//////////////////////////////////
        EDGE CASES STAKE (E1)
    //////////////////////////////////*/

    function testE1_StakeZeroReverts() public {
        vm.prank(alice);
        vm.expectRevert(StakingPool.StakingPool__ZeroAmount.selector);
        pool.stake(0);
    }

    /*//////////////////////////////////
              UNSTAKE (happy path)
    //////////////////////////////////*/

    function test_UnstakeReturnsTokens() public {
        vm.startPrank(alice);
        token.approve(address(pool), 500e18);
        pool.stake(500e18);
        pool.unstake(200e18);
        vm.stopPrank();

        assertEq(pool.getStakedBalance(alice), 300e18);
        assertEq(pool.getTotalStaked(), 300e18);
        assertEq(token.balanceOf(alice), 10_000e18 - 300e18);
    }

    function test_UnstakeAllThenRestake() public {
        vm.startPrank(alice);
        token.approve(address(pool), 1_000e18);
        pool.stake(1_000e18);
        pool.unstake(1_000e18);
        assertEq(pool.getTotalStaked(), 0);
        // allowance 1_000e18 udah kepake abis oleh stake pertama -> approve lagi
        token.approve(address(pool), 400e18);
        pool.stake(400e18);
        vm.stopPrank();

        assertEq(pool.getStakedBalance(alice), 400e18);
    }

    function test_UnstakeEmitsEvent() public {
        vm.startPrank(alice);
        token.approve(address(pool), 100e18);
        pool.stake(100e18);
        vm.expectEmit(true, true, true, true);
        emit IStakingPoolEvents.Unstaked(alice, 100e18);
        pool.unstake(100e18);
        vm.stopPrank();
    }

    /*//////////////////////////////////
        EDGE CASES UNSTAKE (E2-E4, E17)
    //////////////////////////////////*/

    function testE2_UnstakeZeroReverts() public {
        vm.prank(alice);
        vm.expectRevert(StakingPool.StakingPool__ZeroAmount.selector);
        pool.unstake(0);
    }

    function testE3_UnstakeMoreThanStakedReverts() public {
        vm.startPrank(alice);
        token.approve(address(pool), 100e18);
        pool.stake(100e18);
        vm.expectRevert(StakingPool.StakingPool__InsufficientStake.selector);
        pool.unstake(101e18);
        vm.stopPrank();
    }

    function testE4_UnstakeWithoutStakingReverts() public {
        vm.prank(bob);
        vm.expectRevert(StakingPool.StakingPool__InsufficientStake.selector);
        pool.unstake(1);
    }

    /*//////////////////////////////////
              MULTI-USER
    //////////////////////////////////*/

    function test_MultipleUsersAccounting() public {
        _stake(alice, 100e18);
        _stake(bob, 300e18);
        _stake(carol, 600e18);

        assertEq(pool.getTotalStaked(), 1_000e18);
        assertEq(pool.getStakedBalance(alice), 100e18);
        assertEq(pool.getStakedBalance(bob), 300e18);
        assertEq(pool.getStakedBalance(carol), 600e18);
        assertEq(token.balanceOf(address(pool)), 1_000e18);

        _unstake(bob, 100e18);
        assertEq(pool.getTotalStaked(), 900e18);
        assertEq(token.balanceOf(address(pool)), 900e18);
    }

    function test_UsersCannotAffectEachOthersBalance() public {
        _stake(alice, 100e18);
        _stake(bob, 100e18);

        // alice unstake semua -> bob gak terpengaruh sama sekali
        _unstake(alice, 100e18);

        assertEq(pool.getStakedBalance(bob), 100e18);
        assertEq(pool.getTotalStaked(), 100e18);
    }

    function testFuzz_StakeUnstakeRoundTrip(uint256 amount) public {
        amount = bound(amount, 1, 10_000e18);
        _stake(alice, amount);
        assertEq(token.balanceOf(address(pool)), amount);
        _unstake(alice, amount);

        assertEq(pool.getStakedBalance(alice), 0);
        assertEq(pool.getTotalStaked(), 0);
        assertEq(token.balanceOf(address(pool)), 0, "gak boleh ada token nyangkut di pool");
        assertEq(token.balanceOf(alice), 10_000e18, "balance balik ke kondisi awal");
    }

    /*//////////////////////////////////
        EMERGENCY WITHDRAW (E5, E6)
    //////////////////////////////////*/

    function testE5_EmergencyWithdrawReturnsFullStake() public {
        _stake(alice, 500e18);

        vm.prank(alice);
        pool.emergencyWithdraw();

        assertEq(pool.getStakedBalance(alice), 0);
        assertEq(pool.getTotalStaked(), 0);
        assertEq(token.balanceOf(alice), 10_000e18, "100% stake balik");
    }

    function testE5_EmergencyWithdrawEmitsEvent() public {
        _stake(alice, 500e18);
        vm.expectEmit(true, true, true, true);
        emit IStakingPoolEvents.EmergencyWithdraw(alice, 500e18);
        vm.prank(alice);
        pool.emergencyWithdraw();
    }

    function testE6_EmergencyWithdrawThenRestake_AccountingFresh() public {
        _stake(alice, 500e18);
        vm.prank(alice);
        pool.emergencyWithdraw();
        _stake(alice, 200e18);

        assertEq(pool.getStakedBalance(alice), 200e18);
        assertEq(pool.getTotalStaked(), 200e18);
        assertEq(token.balanceOf(address(pool)), 200e18);

        // unstake normal setelahnya harus tetap konsisten
        _unstake(alice, 200e18);
        assertEq(token.balanceOf(address(pool)), 0);
    }

    function test_EmergencyWithdrawWhenNothingStakedReverts() public {
        vm.prank(alice);
        vm.expectRevert(StakingPool.StakingPool__NothingStaked.selector);
        pool.emergencyWithdraw();
    }

    /*//////////////////////////////////
            FUZZ AKUMULASI MULTI-USER
    //////////////////////////////////*/

    function testFuzz_TotalStakedEqualsSumOfBalances(
        uint256 a,
        uint256 b,
        uint256 c
    ) public {
        a = bound(a, 0, 2_000e18);
        b = bound(b, 0, 2_000e18);
        c = bound(c, 0, 2_000e18);

        if (a > 0) _stake(alice, a);
        if (b > 0) _stake(bob, b);
        if (c > 0) _stake(carol, c);

        assertEq(pool.getTotalStaked(), a + b + c, "totalStaked == sum(stakedBalance)");

        uint256 poolTokenBalance = token.balanceOf(address(pool));
        assertEq(poolTokenBalance, a + b + c, "pool pegang persis total stake");
    }

    /*//////////////////////////////////
              HELPERS
    //////////////////////////////////*/

    function _stake(address who, uint256 amount) internal {
        vm.startPrank(who);
        token.approve(address(pool), amount);
        pool.stake(amount);
        vm.stopPrank();
    }

    function _unstake(address who, uint256 amount) internal {
        vm.prank(who);
        pool.unstake(amount);
    }
}
