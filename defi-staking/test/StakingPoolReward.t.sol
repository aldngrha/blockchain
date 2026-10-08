// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {RewardToken} from "../src/RewardToken.sol";
import {StakingPool} from "../src/StakingPool.sol";
import {IStakingPoolEvents} from "./interfaces/IStakingPoolEvents.sol";

/// @title Test reward calculation (Sen 14 Sep) — TDD, math EKSAK dengan vm.warp.
/// @notice Semua angka reward dihitung manual di komentar — bandingkan dengan hasil kontrak.
///         Layout: rate R token/detik, totalStaked T, user saldo s → reward = s/T x R x waktu.
contract StakingPoolRewardTest is Test {
    RewardToken internal token;
    StakingPool internal pool;

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    uint256 constant RATE = 10e18; // 10 token/detik

    function setUp() public {
        // pre-mint 20k ke deployer (test contract = owner) buat likuiditas stake user —
        // reward tetap lahir via mint oleh pool saat claim
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

    function _setRate(uint256 rate) internal {
        pool.setRewardRate(rate); // test contract = owner pool
    }

    /*//////////////////////////////////
        E12 + SEMANTIK setRewardRate
    //////////////////////////////////*/

    function testE12_SetRewardRateZeroIsAllowed() public {
        _stake(alice, 100e18);
        _setRate(0); // pause reward tanpa pause stake
        assertEq(pool.rewardRate(), 0);
    }

    function testE13_SetRewardRateTooHighReverts() public {
        vm.expectRevert(StakingPool.StakingPool__RewardRateTooHigh.selector);
        pool.setRewardRate(2e24); // > MAX_REWARD_RATE (1e24)
    }

    function testE14_SetRewardRateByNonOwnerReverts() public {
        vm.prank(alice);
        vm.expectRevert();
        pool.setRewardRate(RATE);
    }

    function test_SetRewardRateEmitsEvent() public {
        vm.expectEmit(true, true, true, true);
        emit IStakingPoolEvents.RewardRateSet(RATE);
        pool.setRewardRate(RATE);
    }

    /*//////////////////////////////////
        MATH EKSAK — SATU USER
    //////////////////////////////////*/

    function test_EarnedZeroBeforeAnyReward() public {
        _stake(alice, 100e18);
        assertEq(pool.earned(alice), 0, "belum ada rate, reward = 0");
    }

    function test_EarnedExactAfterTenSeconds_SingleUser() public {
        _stake(alice, 100e18);
        _setRate(RATE);
        // stake() memanggil _updateReward -> lastUpdateTime = t0. Rate diset setelahnya.
        // Periode reward mulai dari setRewardRate.
        vm.warp(block.timestamp + 10);

        // reward = staked/total x rate x 10 detik = 100/100 x 10 x 10 = 100 token
        assertEq(pool.earned(alice), 100e18, "10 detik x 10 token/detik");
    }

    function test_RewardPerTokenGrowsPerSecond() public {
        _stake(alice, 100e18);
        _setRate(RATE);
        vm.warp(block.timestamp + 5);

        // rewardPerToken = rate x 5 x 1e18 / totalStaked = 10x5x1e18/100 = 0.5e18
        assertEq(pool.rewardPerToken(), 5e17);
    }

    function test_RewardPerTokenFrozenWhenTotalStakedZero() public {
        _setRate(RATE); // jalan tanpa staker (E10)
        uint256 before = pool.rewardPerToken();
        vm.warp(block.timestamp + 100);
        // totalStaked == 0 -> guard div-by-zero, akumulator diam
        assertEq(pool.rewardPerToken(), before, "gak boleh naik saat pool kosong");
    }

    function test_E8_StakeAndUnstakeSameBlockEarnsNothing() public {
        _setRate(RATE);
        _stake(alice, 100e18);
        uint256 earnedBefore = pool.earned(alice);
        vm.prank(alice);
        pool.unstake(100e18);
        assertEq(pool.earned(alice), earnedBefore, "delta waktu 0 = 0 reward");
    }

    /*//////////////////////////////////
        MATH EKSAK — DUA USER (E9)
    //////////////////////////////////*/

    function test_E9_TwoUsersProportionalRewards() public {
        _stake(alice, 300e18);
        _stake(bob, 100e18); // total 400; alice 75%, bob 25%

        _setRate(RATE);
        vm.warp(block.timestamp + 40);

        // alice: 300/400 x 10 x 40 = 300 token
        // bob:   100/400 x 10 x 40 = 100 token
        assertEq(pool.earned(alice), 300e18, "75% dari 400 token total");
        assertEq(pool.earned(bob), 100e18, "25% dari 400 token total");
        assertEq(pool.earned(alice) + pool.earned(bob), 400e18, "total = rate x waktu");
    }

    function test_UnstakeStopsRewardAccrual() public {
        _stake(alice, 100e18);
        _setRate(RATE);
        vm.warp(block.timestamp + 10);
        // sampai sini: 100 token earned

        vm.prank(alice);
        pool.unstake(100e18);
        vm.warp(block.timestamp + 100);

        // setelah unstake, saldo 0 -> earned gak bertambah
        assertEq(pool.earned(alice), 100e18, "reward berhenti akumulasi setelah unstake");
    }

    function test_NewStakerGetsFairShareAfterJoining() public {
        _stake(alice, 100e18);
        _setRate(RATE);
        vm.warp(block.timestamp + 10);
        // alice earned 100 token

        _stake(bob, 100e18); // bob masuk di t+10, total jadi 200
        vm.warp(block.timestamp + 20);

        // 10 detik pertama: cuma alice (100 token). 20 detik berikut: split 50/50 (masing2 100 token)
        assertEq(pool.earned(alice), 200e18, "100 (solo) + 100 (50%)");
        assertEq(pool.earned(bob), 100e18, "hanya dari 20 detik setelah join");
    }

    /*//////////////////////////////////
            CLAIM REWARD (E7, E5)
    //////////////////////////////////*/

    function test_ClaimMintsExactAmount() public {
        _stake(alice, 100e18);
        _setRate(RATE);
        vm.warp(block.timestamp + 10);

        vm.prank(alice);
        pool.claimReward();

        // reward = 100 token -> di-mint ke alice oleh pool
        // 10_000 awal - 100 stake (masih nanggung di pool) + 100 reward mint = 10_000
        assertEq(token.balanceOf(alice), 10_000e18, "stake masih di pool, reward mint di atasnya");
        assertEq(pool.earned(alice), 0, "rewards direset setelah claim");
        assertEq(pool.getStakedBalance(alice), 100e18, "stake gak terpengaruh");
        assertEq(token.totalSupply(), 20_000e18 + 100e18, "supply = pre-mint + reward minted");
    }

    function testE7_ClaimWithNothingEarnedReverts() public {
        _stake(alice, 100e18); // belum ada rate
        vm.prank(alice);
        vm.expectRevert(StakingPool.StakingPool__NothingToClaim.selector);
        pool.claimReward();
    }

    function test_ClaimEmitsRewardPaidEvent() public {
        _stake(alice, 100e18);
        _setRate(RATE);
        vm.warp(block.timestamp + 10);

        vm.prank(alice);
        vm.expectEmit(true, true, true, true);
        emit IStakingPoolEvents.RewardPaid(alice, 100e18);
        pool.claimReward();
    }

    function test_MintedByPoolViaClaim_AllowsPoolToMint() public {
        // bukti rantai izin: pool manggil mint di RewardToken saat claim
        _stake(alice, 100e18);
        _setRate(RATE);
        vm.warp(block.timestamp + 10);
        vm.prank(alice);
        pool.claimReward();
        assertEq(token.balanceOf(alice), 10_000e18); // 10_000 - 100 stake + 100 mint
    }

    /*//////////////////////////////////
        E5: EMERGENCY WITHDRAW FORFEITS REWARD
    //////////////////////////////////*/

    function testE5_EmergencyWithdrawForfeitsRewards() public {
        _stake(alice, 100e18);
        _setRate(RATE);
        vm.warp(block.timestamp + 10);
        assertTrue(pool.earned(alice) > 0, "pastikan ada reward dulu");

        vm.prank(alice);
        pool.emergencyWithdraw();

        assertEq(pool.earned(alice), 0, "reward FORFEIT");
        assertEq(token.balanceOf(alice), 10_000e18, "cuma dapat stake balik, tanpa reward");
        assertEq(pool.getStakedBalance(alice), 0);
    }

    function testE6_EmergencyWithdrawThenRestake_NoPhantomRewards() public {
        _stake(alice, 100e18);
        _setRate(RATE);
        vm.warp(block.timestamp + 10);

        vm.prank(alice);
        pool.emergencyWithdraw();
        _stake(alice, 100e18);
        vm.warp(block.timestamp + 10);

        // fresh start: reward baru hanya dari 10 detik kedua, gak ada phantom dari periode pertama
        assertEq(pool.earned(alice), 100e18, "accounting fresh, gak ada phantom reward");
    }

    /*//////////////////////////////////
        E11: SET RATE MID-PERIOD
    //////////////////////////////////*/

    function testE11_SetRateMidPeriodFreezesOldAccrual() public {
        _stake(alice, 100e18);
        _setRate(RATE);
        vm.warp(block.timestamp + 10);
        assertEq(pool.earned(alice), 100e18); // periode 1: 10 token/detik

        _setRate(2 * RATE); // ganti rate di tengah jalan
        vm.warp(block.timestamp + 10);

        // periode 2: 20 token/detik x 10 detik = 200 token. Total 100 + 200 = 300
        assertEq(pool.earned(alice), 300e18, "akumulasi lama di-freeze, periode baru jalan");
    }

    /*//////////////////////////////////
        PERIODE 7 HARI: ACCRUAL BERHENTI
    //////////////////////////////////*/

    function test_RewardStopsAccruingAfterPeriodFinish() public {
        _stake(alice, 100e18);
        _setRate(RATE);
        vm.warp(block.timestamp + 7 days); // tepat di periodFinish

        uint256 earnedAtFinish = pool.earned(alice);
        // full period: rate 10/detik x 7 hari = 6_048_000 token
        assertEq(earnedAtFinish, RATE * 7 days, "akumulasi penuh sampai periodFinish");

        vm.warp(block.timestamp + 30 days); // lewat periode
        assertEq(pool.lastTimeRewardApplicable(), pool.periodFinish(), "cap di periodFinish");
        assertEq(pool.earned(alice), earnedAtFinish, "reward gak jalan melewati periode");
    }

    /*//////////////////////////////////
            VIEW KONSISTENSI + FUZZ
    //////////////////////////////////*/

    function testFuzz_EarnedMatchesFormula(uint256 stakeAmount, uint256 elapsed) public {
        stakeAmount = bound(stakeAmount, 1e18, 10_000e18);
        elapsed = bound(elapsed, 1, 7 days); // accrual berhenti di periodFinish (DURATION = 7 days)

        _stake(alice, stakeAmount);
        _setRate(RATE);
        vm.warp(block.timestamp + elapsed);

        // rumus manual: stake/total x rate x elapsed (= rate x elapsed, single user)
        uint256 expected = RATE * elapsed;
        // toleransi dust: deficit pembulatan < stakeAmount/1e18 wei (floor di rewardPerToken lalu di earned)
        assertApproxEqAbs(pool.earned(alice), expected, stakeAmount / 1e18 + 1, "earned = rate x elapsed (single user)");
    }

    function testFuzz_ClaimTotalNeverExceedsRateTimesElapsed(uint256 elapsed) public {
        elapsed = bound(elapsed, 1, 7 days); // cap periode
        _stake(alice, 100e18);
        _stake(bob, 100e18);
        _setRate(RATE);
        vm.warp(block.timestamp + elapsed);

        vm.prank(alice);
        pool.claimReward();
        vm.prank(bob);
        pool.claimReward();

        // total yang di-mint gak boleh lebih dari rate x waktu (gak ada mint bocor)
        assertLe(token.balanceOf(alice) + token.balanceOf(bob), 10_000e18 * 2 + RATE * elapsed + 1);
        assertEq(pool.earned(alice) + pool.earned(bob), 0, "semua ter-claim bersih");
    }
}
