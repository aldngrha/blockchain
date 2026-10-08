// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {DexPair} from "../../src/DexPair.sol";
import {ERC20Mock} from "../../src/mocks/ERC20Mock.sol";

/// @title Handler for the DexPair invariant suite (roadmap Sen 5 Okt).
/// @notice The invariant runner hits this handler with random sequences of
///         addLiquidity / removeLiquidity / swap / warp (runs x depth). All
///         guards live here: with fail_on_revert = true, a revert in a handler
///         is a FAIL (including failed asserts, which revert the handler frame),
///         so every action is bounded or skipped (skip, not revert). Ghost
///         variables track aggregates that are invisible on the pair.
contract DexPairHandler is Test {
    ERC20Mock public tokenA;
    ERC20Mock public tokenB;
    DexPair public pair;

    address[] public actors;
    uint256 public constant NUM_ACTORS = 3;
    address public lpOwner; // seeds the pool in the constructor, keeps LP
    uint256 public constant PRE_MINT = 1_000_000e18;
    uint256 public constant SEED = 1000e18;

    // ===== Ghost variables =====
    uint256 public ghost_lpMinted; // every LP minted (incl. the 1000 to the pair)
    uint256 public ghost_lpBurned; // every LP burned via removeLiquidity
    uint256 public ghost_swapCount;
    uint256 public ghost_lastSwapKBefore; // I-a echo for the final check
    uint256 public ghost_lastSwapKAfter;
    // Per-swap snapshot (storage, not stack: swap() sits at the stack limit)
    uint256 internal ghost_swapRIn;
    uint256 internal ghost_swapROut;
    uint256 internal ghost_swapAmountIn;
    uint256 internal ghost_balInBefore;
    uint256 internal ghost_balOutBefore;

    uint256 internal constant MIN_UNIT = 1e9;

    constructor() {
        tokenA = new ERC20Mock("Actor Token A", "ATA");
        tokenB = new ERC20Mock("Actor Token B", "ATB");
        pair = new DexPair(address(tokenA), address(tokenB));

        lpOwner = makeAddr("lp-owner");
        tokenA.mint(lpOwner, PRE_MINT);
        tokenB.mint(lpOwner, PRE_MINT);
        vm.startPrank(lpOwner);
        tokenA.approve(address(pair), type(uint256).max);
        tokenB.approve(address(pair), type(uint256).max);
        vm.stopPrank();

        for (uint256 i = 0; i < NUM_ACTORS; i++) {
            address a = makeAddr(string.concat("actor-", vm.toString(i)));
            actors.push(a);
            tokenA.mint(a, PRE_MINT);
            tokenB.mint(a, PRE_MINT);
            vm.startPrank(a);
            tokenA.approve(address(pair), type(uint256).max);
            tokenB.approve(address(pair), type(uint256).max);
            vm.stopPrank();
        }

        // Seed (1000e18, 1000e18): LP = 1e21, of which 1000 are locked on the pair.
        // NOTE: on the first provision the RETURNED liquidity is the FULL mint
        // (locked 1000 included); the caller receives liquidity - 1000.
        vm.prank(lpOwner);
        (, , uint256 liq) = pair.addLiquidity(SEED, SEED);
        ghost_lpMinted = liq;
    }

    // ------------------------------------------------------------------
    // Canonical helpers: the pair SORTS its tokens, so tokenA is token0
    // only by luck. Every handler must resolve sides through the pair.
    // ------------------------------------------------------------------

    function _t0() internal view returns (ERC20Mock) {
        return pair.token0() == address(tokenA) ? tokenA : tokenB;
    }

    function _t1() internal view returns (ERC20Mock) {
        return pair.token0() == address(tokenA) ? tokenB : tokenA;
    }

    function _actor(uint256 seed) internal view returns (address) {
        return actors[seed % NUM_ACTORS];
    }

    // ------------------------------------------------------------------
    // Actions
    // ------------------------------------------------------------------

    /// @dev Pool is always seeded, so this is always the proportional branch.
    function addLiquidity(uint256 actorSeed, uint256 amount0, uint256 amount1) external {
        address a = _actor(actorSeed);
        // Below ~1e12 the mint could floor to 0 and revert; skip instead.
        if (_t0().balanceOf(a) < 1e12 || _t1().balanceOf(a) < 1e12) return;
        amount0 = bound(amount0, 1e12, _t0().balanceOf(a));
        amount1 = bound(amount1, 1e12, _t1().balanceOf(a));

        uint256 tsBefore = pair.totalSupply();
        (uint256 r0, uint256 r1) = pair.getReserves();
        uint256 bal0Before = _t0().balanceOf(a);
        uint256 bal1Before = _t1().balanceOf(a);
        uint256 lpBefore = pair.balanceOf(a);

        vm.prank(a);
        (uint256 used0, uint256 used1, uint256 liq) = pair.addLiquidity(amount0, amount1);

        // LP backing property: minted LP equals the min-formula for what was taken.
        uint256 side0 = (used0 * tsBefore) / r0;
        uint256 side1 = (used1 * tsBefore) / r1;
        assertEq(liq, side0 < side1 ? side0 : side1, "LP != min-formula on used amounts");
        // Refund property: only the used amounts ever leave the actor.
        assertEq(_t0().balanceOf(a), bal0Before - used0, "token0 pulled != used0");
        assertEq(_t1().balanceOf(a), bal1Before - used1, "token1 pulled != used1");
        assertEq(pair.balanceOf(a), lpBefore + liq, "LP credited to the provider");

        ghost_lpMinted += liq;
    }

    function removeLiquidity(uint256 actorSeed, uint256 lpAmount) external {
        address a = _actor(actorSeed);
        uint256 lpBal = pair.balanceOf(a);
        // Dust burns revert (InsufficientLiquidityBurned); keep amounts chunky.
        if (lpBal < 1e6) return;
        lpAmount = bound(lpAmount, 1e6, lpBal);

        uint256 ts = pair.totalSupply();
        (uint256 r0, uint256 r1) = pair.getReserves();
        // Expected payout is the floor against supply BEFORE the burn.
        uint256 exp0 = (lpAmount * r0) / ts;
        uint256 exp1 = (lpAmount * r1) / ts;
        uint256 bal0Before = _t0().balanceOf(a);
        uint256 bal1Before = _t1().balanceOf(a);

        vm.prank(a);
        (uint256 got0, uint256 got1) = pair.removeLiquidity(lpAmount);

        // I-d: proportional payout, exact, against pre-call state.
        assertEq(got0, exp0, "remove payout0 not proportional");
        assertEq(got1, exp1, "remove payout1 not proportional");
        assertEq(_t0().balanceOf(a), bal0Before + got0, "token0 payout lost");
        assertEq(_t1().balanceOf(a), bal1Before + got1, "token1 payout lost");

        ghost_lpBurned += lpAmount;
    }

    function swap(uint256 actorSeed, uint256 amountIn, bool zeroForOne) external {
        address a = _actor(actorSeed);
        (uint256 ra, uint256 rb) = pair.getReserves();
        uint256 rIn = zeroForOne ? ra : rb;
        uint256 rOut = zeroForOne ? rb : ra;
        // Guards come FIRST: an early return must never leave stale ghost
        // snapshots behind (a later echo compare would pair two points in time).
        if (rIn / 100 < MIN_UNIT) return;
        amountIn = bound(amountIn, MIN_UNIT, rIn / 100);
        ERC20Mock tokenIn = zeroForOne ? _t0() : _t1();
        ERC20Mock tokenOut = zeroForOne ? _t1() : _t0();
        uint256 balIn = tokenIn.balanceOf(a);
        if (balIn < amountIn) {
            if (balIn < MIN_UNIT) return;
            amountIn = balIn;
        }

        ghost_lastSwapKBefore = ra * rb;
        ghost_balInBefore = balIn;
        ghost_balOutBefore = tokenOut.balanceOf(a);
        ghost_swapAmountIn = amountIn;
        ghost_swapRIn = rIn;
        ghost_swapROut = rOut;

        vm.prank(a);
        uint256 out = pair.swapExactTokensForTokens(amountIn, 0, block.timestamp + 1, zeroForOne);

        _checkSwapOutcome(a, zeroForOne, out);
        ghost_swapCount++;
    }

    /// @dev I-a primary check plus exact-in/exact-out bookkeeping. Reads the
    ///      pre-swap snapshot from ghosts; split out of swap() to keep the EVM
    ///      stack within limits.
    function _checkSwapOutcome(address a, bool zeroForOne, uint256 out) internal {
        (uint256 nr0, uint256 nr1) = pair.getReserves();
        // I-a: k must never decrease through a swap (an invariant function would
        // only see the last swap and go vacuous in between).
        assertGe(nr0 * nr1, ghost_lastSwapKBefore, "I-a: k decreased through a swap");
        assertEq(
            zeroForOne ? nr1 : nr0,
            ghost_swapROut - out,
            "output reserve shrinks by exactly the payout"
        );
        assertEq(
            (zeroForOne ? _t1() : _t0()).balanceOf(a),
            ghost_balOutBefore + out,
            "trader received the exact output"
        );
        assertEq(
            (zeroForOne ? _t0() : _t1()).balanceOf(a),
            ghost_balInBefore - ghost_swapAmountIn,
            "trader paid the exact input"
        );
        // Sanity: the pool kept the whole input (fee dust included).
        assertEq(
            zeroForOne ? nr0 : nr1,
            ghost_swapRIn + ghost_swapAmountIn,
            "input reserve grew by exactly the input"
        );
        ghost_lastSwapKAfter = nr0 * nr1;
    }

    function warp(uint256 dt) external {
        vm.warp(block.timestamp + bound(dt, 1, 7 days));
    }
}
