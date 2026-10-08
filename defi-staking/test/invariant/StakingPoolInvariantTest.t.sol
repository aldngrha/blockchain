// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {StakingPool} from "../../src/StakingPool.sol";
import {StakingPoolHandler} from "./StakingPoolHandler.t.sol";

/// @title Invariant tests — properti yang HARUS benar setelah urutan call acak apapun.
contract StakingPoolInvariantTest is Test {
    StakingPoolHandler internal handler;

    function setUp() public {
        handler = new StakingPoolHandler();
        targetContract(address(handler));
    }

    // I-2: sum(stakedBalance[u]) == totalStaked — pembukuan = kenyataan
    function invariant_I2_SumBalancesEqualsTotalStaked() public view {
        uint256 sum;
        for (uint256 i = 0; i < handler.NUM_ACTORS(); i++) {
            sum += handler.pool().getStakedBalance(handler.actors(i));
        }
        assertEq(sum, handler.pool().totalStaked(), "I-2: sum(balances) != totalStaked");
    }

    // I-3: token.balanceOf(pool) == totalStaked — gak ada token nyangkut/idle
    function invariant_I3_PoolHoldsExactlyTotalStaked() public view {
        assertEq(
            handler.token().balanceOf(address(handler.pool())),
            handler.pool().totalStaked(),
            "I-3: token nyangkut atau hilang di pool"
        );
    }

    // I-4: totalSupply == pre-mint + minted-via-claim — gak ada mint bocor
    function invariant_I4_NoLeakedMint() public view {
        assertEq(
            handler.token().totalSupply(),
            handler.PRE_MINT() + handler.ghost_totalMinted(),
            "I-4: mint bocor di luar jalur claim"
        );
    }

    // I-6: rewardPerToken gak pernah turun (double-check final state;
    // pemeriksaan utama ada di handler._sync() setelah TIAP aksi)
    function invariant_I6_RewardPerTokenNonDecreasing() public view {
        assertGe(
            handler.pool().rewardPerToken(),
            handler.ghost_lastRewardPerToken(),
            "I-6: rewardPerToken turun"
        );
    }

    // I-7: total mint dibatasi jadwal emisi (rate x detik efektif) + dust pembulatan
    function invariant_I7_MintBoundedByEmissionSchedule() public view {
        assertLe(
            handler.token().totalSupply(),
            handler.PRE_MINT() + handler.ghost_maxMint() + 1e12, // slack dust < 1e-6 token
            "I-7: mint melebihi jadwal emisi"
        );
    }
}
