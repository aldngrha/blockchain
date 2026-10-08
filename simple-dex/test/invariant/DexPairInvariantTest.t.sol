// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {DexPairHandler} from "./DexPairHandler.t.sol";

/// @title DexPair invariant tests (roadmap Sen 5 Okt).
/// @notice Properties that must hold after ANY random action sequence produced
///         by the handler. Primary per-action checks live in the handler; these
///         functions re-verify the global state at the end of every sequence.
contract DexPairInvariantTest is Test {
    DexPairHandler internal handler;
    uint256 internal constant HOLDERS = 5; // 3 actors + lpOwner + the pair itself

    function setUp() public {
        handler = new DexPairHandler();
        targetContract(address(handler));
    }

    // I-b solvency: recorded reserves mirror the REAL token balances exactly.
    // Sides are resolved through the pair: the handler deploys tokenA first,
    // but the pair SORTS, so tokenA is token1 here (address order).
    function invariant_I1_ReservesMatchActualBalances() public view {
        bool aIsToken0 = handler.pair().token0() == address(handler.tokenA());
        assertEq(
            (aIsToken0 ? handler.tokenA() : handler.tokenB()).balanceOf(address(handler.pair())),
            handler.pair().reserve0(),
            "I-b: token0 balance of pair != reserve0 (stuck or phantom funds)"
        );
        assertEq(
            (aIsToken0 ? handler.tokenB() : handler.tokenA()).balanceOf(address(handler.pair())),
            handler.pair().reserve1(),
            "I-b: token1 balance of pair != reserve1 (stuck or phantom funds)"
        );
    }

    // I-c LP accounting: totalSupply == all minted LP - all burned LP.
    function invariant_I2_LpSupplyAccounting() public view {
        assertEq(
            handler.pair().totalSupply(),
            handler.ghost_lpMinted() - handler.ghost_lpBurned(),
            "I-c: LP supply drifted from mint/burn bookkeeping"
        );
    }

    // MINIMUM_LIQUIDITY is permanently locked: supply never drops below it and
    // the unclaimable share always sits on the pair itself.
    function invariant_I3_MinimumLiquidityLocked() public view {
        assertGe(
            handler.pair().totalSupply(),
            handler.pair().MINIMUM_LIQUIDITY(),
            "locked LP was somehow removed from the supply"
        );
        assertEq(
            handler.pair().balanceOf(address(handler.pair())),
            handler.pair().MINIMUM_LIQUIDITY(),
            "locked LP share moved off the pair"
        );
    }

    // LP backing: the sum of every holder's floored proportional claim on each
    // reserve can never exceed the reserve, and the rounding dust stays below
    // one wei per holder.
    function invariant_I4_LpBackingConsistent() public view {
        (uint256 r0, uint256 r1) = handler.pair().getReserves();
        uint256 ts = handler.pair().totalSupply();

        uint256 claim0;
        uint256 claim1;
        for (uint256 i = 0; i < handler.NUM_ACTORS(); i++) {
            uint256 lp = handler.pair().balanceOf(handler.actors(i));
            claim0 += (lp * r0) / ts;
            claim1 += (lp * r1) / ts;
        }
        uint256 ownerLp = handler.pair().balanceOf(handler.lpOwner());
        claim0 += (ownerLp * r0) / ts;
        claim1 += (ownerLp * r1) / ts;
        uint256 pairLp = handler.pair().balanceOf(address(handler.pair()));
        claim0 += (pairLp * r0) / ts;
        claim1 += (pairLp * r1) / ts;

        assertLe(claim0, r0, "claims on token0 exceed the reserve");
        assertLe(claim1, r1, "claims on token1 exceed the reserve");
        assertLe(r0 - claim0, HOLDERS, "token0 rounding dust exceeds one wei per holder");
        assertLe(r1 - claim1, HOLDERS, "token1 rounding dust exceeds one wei per holder");
    }

    // I-a echo: the last swap in the sequence did not decrease k (primary check
    // runs inside the handler after EVERY swap).
    function invariant_I5_KNeverDecreasedOnLastSwap() public view {
        if (handler.ghost_swapCount() > 0) {
            assertGe(
                handler.ghost_lastSwapKAfter(),
                handler.ghost_lastSwapKBefore(),
                "I-a: k decreased through a swap (final echo)"
            );
        }
    }
}
