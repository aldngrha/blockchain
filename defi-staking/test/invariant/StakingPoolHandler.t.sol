// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {RewardToken} from "../../src/RewardToken.sol";
import {StakingPool} from "../../src/StakingPool.sol";

/// @title Handler invariant suite (Sel 15 Sep, SPEC §7).
/// @notice Invariant suite menyerang handler ini dengan urutan call acak (runs x depth).
///         Ghost variables nge-track agregat yang gak kelihatan dari kontrak.
contract StakingPoolHandler is Test {
    RewardToken public token;
    StakingPool public pool;

    address[] public actors;
    uint256 public constant NUM_ACTORS = 3;
    uint256 public constant PRE_MINT = 100_000e18;

    // ===== Ghost variables (SPEC §7) =====
    uint256 public ghost_totalMinted;        // I-4: mint via claim
    uint256 public ghost_lastRewardPerToken; // I-6: monotonik rPT
    uint256 public ghost_maxMint;            // I-7: upper bound rate x detik efektif
    uint256 public ghost_periodEnd;          // helper I-7

    constructor() {
        token = new RewardToken("Staking Reward Token", "SRT", PRE_MINT);
        pool = new StakingPool(address(token));
        token.setStakingPool(address(pool));
        for (uint256 i = 0; i < NUM_ACTORS; i++) {
            address a = makeAddr(string.concat("actor-", vm.toString(i)));
            actors.push(a);
            token.transfer(a, 10_000e18);
        }
    }

    function _actor(uint256 seed) internal view returns (address) {
        return actors[seed % NUM_ACTORS];
    }

    function _sync() internal {
        uint256 rpt = pool.rewardPerToken();
        // I-6 dicek DI SINI, tiap aksi — bukan cuma di akhir sequence. Kalau cuma di
        // invariant function, ghost ke-timpa oleh _sync terakhir sebelum pengecekan
        // -> perbandingan jadi nilai vs dirinya sendiri (vacuous, gak pernah bisa gagal).
        assertGe(rpt, ghost_lastRewardPerToken, "I-6: rewardPerToken turun");
        ghost_lastRewardPerToken = rpt;
    }

    function stake(uint256 actorSeed, uint256 amount) external {
        address a = _actor(actorSeed);
        uint256 balance = token.balanceOf(a);
        if (balance < 1e15) return; // skip, bukan revert
        amount = bound(amount, 1e15, balance);

        vm.startPrank(a);
        token.approve(address(pool), amount);
        pool.stake(amount);
        vm.stopPrank();
        _sync();
    }

    function unstake(uint256 actorSeed, uint256 amount) external {
        address a = _actor(actorSeed);
        uint256 staked = pool.getStakedBalance(a);
        if (staked == 0) return;
        amount = bound(amount, 1, staked);

        vm.prank(a);
        pool.unstake(amount);
        _sync();
    }

    function claim(uint256 actorSeed) external {
        address a = _actor(actorSeed);
        uint256 owed = pool.earned(a);
        if (owed == 0) return;

        vm.prank(a);
        pool.claimReward();
        ghost_totalMinted += owed;
        _sync();
    }

    function unstakeAndClaim(uint256 actorSeed) external {
        address a = _actor(actorSeed);
        uint256 staked = pool.getStakedBalance(a);
        uint256 owed = pool.earned(a);
        if (staked == 0 || owed == 0) return; // jalur revert E17 dites stateless

        vm.prank(a);
        pool.unstakeAndClaim();

        // I-5: exit bersih — gak ada stuck funds
        assertEq(pool.getStakedBalance(a), 0, "I-5: staked harus 0 setelah exit");
        assertEq(pool.earned(a), 0, "I-5: earned harus 0 setelah exit");

        ghost_totalMinted += owed;
        _sync();
    }

    function emergencyWithdraw(uint256 actorSeed) external {
        address a = _actor(actorSeed);
        if (pool.getStakedBalance(a) == 0) return;

        vm.prank(a);
        pool.emergencyWithdraw();
        _sync();
    }

    function setRate(uint256 rate) external {
        rate = bound(rate, 0, 1e20); // kecil biar bound I-7 bermakna (< MAX_REWARD_RATE)
        pool.setRewardRate(rate);
        ghost_periodEnd = block.timestamp + 7 days;
        _sync();
    }

    function warp(uint256 dt) external {
        dt = bound(dt, 1, 7 days);
        uint256 target = block.timestamp + dt;
        // I-7 helper: detik accrual efektif = min(dt, sisa periode)
        if (block.timestamp < ghost_periodEnd) {
            uint256 remaining = ghost_periodEnd - block.timestamp;
            ghost_maxMint += pool.rewardRate() * (dt < remaining ? dt : remaining);
        }
        vm.warp(target);
        _sync();
    }
}
