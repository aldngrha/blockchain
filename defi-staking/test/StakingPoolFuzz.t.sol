// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {RewardToken} from "../src/RewardToken.sol";
import {StakingPool} from "../src/StakingPool.sol";

/// @title Stateless fuzz (Sel 15 Sep) — Foundry generate input acak, cari edge case.
contract StakingPoolFuzzTest is Test {
    RewardToken internal token;
    StakingPool internal pool;

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    uint256 constant RATE = 10e18;

    function setUp() public {
        token = new RewardToken("Staking Reward Token", "SRT", 20_000e18);
        pool = new StakingPool(address(token));
        token.setStakingPool(address(pool));
        token.transfer(alice, 10_000e18);
        token.transfer(bob, 10_000e18);
    }

    function _stake(address who, uint256 amount) internal {
        vm.startPrank(who);
        token.approve(address(pool), amount);
        pool.stake(amount);
        vm.stopPrank();
    }

    /*//////////////////
        E17: unstakeAndClaim
    //////////////////*/

    function testE17_UnstakeAndClaimWithoutStakeReverts() public {
        vm.expectRevert(StakingPool.StakingPool__NothingStaked.selector);
        pool.unstakeAndClaim();
    }

    function testE17_UnstakeAndClaimNothingToClaimReverts() public {
        _stake(alice, 100e18); // belum ada rate -> owed 0
        vm.prank(alice);
        vm.expectRevert(StakingPool.StakingPool__NothingToClaim.selector);
        pool.unstakeAndClaim();
    }

    /*//////////////////
        FUZZ — property-based
    //////////////////*/

    // I-6 stateless: rPT monoton naik di warp acak (juga ngetes cap periodFinish)
    function testFuzz_RewardPerTokenMonotonic(uint256 dt1, uint256 dt2) public {
        dt1 = bound(dt1, 1, 7 days);
        dt2 = bound(dt2, 1, 7 days);
        _stake(alice, 100e18);
        pool.setRewardRate(RATE);

        vm.warp(block.timestamp + dt1);
        uint256 rpt1 = pool.rewardPerToken();
        vm.warp(block.timestamp + dt2);
        uint256 rpt2 = pool.rewardPerToken();

        assertGe(rpt2, rpt1, "rewardPerToken menurun");
    }

    // E9 stateless: split proporsional di stake acak — cek silang a/b
    function testFuzz_TwoUsersProportionalSplit(uint256 stakeA, uint256 stakeB, uint256 dt) public {
        stakeA = bound(stakeA, 1e18, 1_000e18);
        stakeB = bound(stakeB, 1e18, 1_000e18);
        dt = bound(dt, 10, 7 days);

        _stake(alice, stakeA);
        _stake(bob, stakeB);
        pool.setRewardRate(RATE);
        vm.warp(block.timestamp + dt);

        // earnedA/earnedB == stakeA/stakeB -> earnedA x stakeB == earnedB x stakeA
        uint256 lhs = pool.earned(alice) * stakeB;
        uint256 rhs = pool.earned(bob) * stakeA;
        assertApproxEqRel(lhs, rhs, 1e15, "split gak proporsional");
    }

    // I-5 stateless: unstakeAndClaim dengan input acak selalu bersih
    function testFuzz_UnstakeAndClaimCleanState(uint256 amount, uint256 dt) public {
        amount = bound(amount, 1e18, 10_000e18);
        dt = bound(dt, 2, 7 days);
        _stake(alice, amount);
        pool.setRewardRate(RATE);
        vm.warp(block.timestamp + dt);

        vm.prank(alice);
        pool.unstakeAndClaim();

        assertEq(pool.getStakedBalance(alice), 0, "stake harus 0");
        assertEq(pool.earned(alice), 0, "earned harus 0");
        // stake kembali PENUH (bukan hilang) + reward mint dt x rate.
        // Dust = dua lantai floor (rewardPerTokenStored lalu earned) + totalStaked "jelek"
        // dari bound() -> teramati ~2.6e3 wei. Toleransi 1e6 wei = 1e-12 token, praktis nol.
        assertApproxEqAbs(
            token.balanceOf(alice),
            10_000e18 + dt * RATE,
            1e6,
            "stake balik + reward dt x rate"
        );
    }
}
