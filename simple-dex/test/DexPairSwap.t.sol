// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {AMMLibrary} from "../src/AMMLibrary.sol";
import {DexPair} from "../src/DexPair.sol";
import {ERC20Mock} from "../src/mocks/ERC20Mock.sol";

/// @title DexPair swap tests (roadmap Min 4 Okt).
/// @notice The exact output vector is hand-computed:
///         out = floor(10e18 * 997 * 1000e18 / (1000e18 * 1000 + 10e18 * 997))
///             = 9871580343970612988
contract DexPairSwapTest is Test {
    uint256 internal constant E18 = 1e18;

    ERC20Mock internal tokenA;
    ERC20Mock internal tokenB;
    DexPair internal pair;

    address internal alice = makeAddr("alice");
    address internal trader = makeAddr("trader");

    function setUp() public {
        tokenA = new ERC20Mock("Token A", "TKA");
        tokenB = new ERC20Mock("Token B", "TKB");
        pair = new DexPair(address(tokenA), address(tokenB));

        tokenA.mint(alice, 1_000_000 * E18);
        tokenB.mint(alice, 1_000_000 * E18);
        vm.startPrank(alice);
        tokenA.approve(address(pair), type(uint256).max);
        tokenB.approve(address(pair), type(uint256).max);
        pair.addLiquidity(1000 * E18, 1000 * E18); // LP total = 1e21
        vm.stopPrank();

        tokenA.mint(trader, 10_000 * E18);
        tokenB.mint(trader, 10_000 * E18);
        vm.startPrank(trader);
        tokenA.approve(address(pair), type(uint256).max);
        tokenB.approve(address(pair), type(uint256).max);
        vm.stopPrank();
    }

    function _t0() internal view returns (ERC20Mock) {
        return pair.token0() == address(tokenA) ? tokenA : tokenB;
    }

    function _t1() internal view returns (ERC20Mock) {
        return pair.token0() == address(tokenA) ? tokenB : tokenA;
    }

    /// @dev Marginal price of token0 in token1 terms (res1/res0), scaled 1e18.
    function _price0In1() internal view returns (uint256) {
        (uint256 r0, uint256 r1) = pair.getReserves();
        return (r1 * 1e18) / r0;
    }

    // ------------------------------------------------------------------
    // Exact math
    // ------------------------------------------------------------------

    function test_Swap_ExactOutputVector() public {
        uint256 t0Before = _t0().balanceOf(trader);
        uint256 t1Before = _t1().balanceOf(trader);

        vm.prank(trader);
        uint256 out = pair.swapExactTokensForTokens(10 * E18, 0, block.timestamp + 1, true);

        assertEq(out, 9871580343970612988, "exact vector for 10e18 into a 1000/1000 pool");
        (uint256 r0, uint256 r1) = pair.getReserves();
        assertEq(r0, 1010 * E18, "reserve0 grows by the full input");
        assertEq(r1, 1000 * E18 - out, "reserve1 shrinks by the exact output");
        assertEq(_t0().balanceOf(trader), t0Before - 10 * E18, "input left the trader");
        assertEq(_t1().balanceOf(trader), t1Before + out, "output reached the trader");
        assertEq(_t0().balanceOf(address(pair)), 1010 * E18, "pair holds what reserves say");
        assertEq(_t1().balanceOf(address(pair)), 1000 * E18 - out, "pair holds what reserves say");
    }

    function testFuzz_Swap_MatchesLibraryFormula(
        uint112 amountIn,
        bool zeroForOne
    ) public {
        // Cap at 10% of the reserve so the fuzz stays in a sane price band and
        // the internal product never overflows (997 * 1e20 * 1e21 << 2^256).
        amountIn = uint112(bound(amountIn, 1e9, 100 * E18));
        (uint256 r0, uint256 r1) = pair.getReserves();
        (uint256 rIn, uint256 rOut) = zeroForOne ? (r0, r1) : (r1, r0);

        vm.prank(trader);
        uint256 out = pair.swapExactTokensForTokens(amountIn, 0, block.timestamp + 1, zeroForOne);

        assertEq(out, AMMLibrary.getAmountOut(amountIn, rIn, rOut), "pair == library formula");
        assertLt(out, rOut, "output can never exceed the output reserve");
        (uint256 nr0, uint256 nr1) = pair.getReserves();
        if (zeroForOne) {
            assertEq(nr0, r0 + amountIn, "reserve0 accounting");
            assertEq(nr1, r1 - out, "reserve1 accounting");
        } else {
            assertEq(nr1, r1 + amountIn, "reserve1 accounting");
            assertEq(nr0, r0 - out, "reserve0 accounting");
        }
    }

    // ------------------------------------------------------------------
    // Price direction
    // ------------------------------------------------------------------

    function test_Swap_ZeroForOne_PushesToken0PriceDown() public {
        uint256 priceBefore = _price0In1(); // 1e18 (1:1 pool)

        vm.prank(trader);
        pair.swapExactTokensForTokens(10 * E18, 0, block.timestamp + 1, true);

        // Selling token0 floods the pool with token0: its price in token1 terms
        // must FALL (more reserve0 per unit of reserve1).
        assertLt(_price0In1(), priceBefore, "token0 price must drop after selling token0");
    }

    function test_Swap_OneForZero_PushesToken0PriceUp() public {
        uint256 priceBefore = _price0In1();

        vm.prank(trader);
        pair.swapExactTokensForTokens(10 * E18, 0, block.timestamp + 1, false);

        assertGt(_price0In1(), priceBefore, "token0 price must rise after buying token0");
    }

    // ------------------------------------------------------------------
    // Constant product + fee
    // ------------------------------------------------------------------

    function test_Swap_ProductNeverDecreases_FeeStaysInPool() public {
        (uint256 r0, uint256 r1) = pair.getReserves();
        uint256 kBefore = r0 * r1;

        vm.prank(trader);
        uint256 out = pair.swapExactTokensForTokens(10 * E18, 0, block.timestamp + 1, true);

        (uint256 nr0, uint256 nr1) = pair.getReserves();
        uint256 kAfter = nr0 * nr1;
        // x*y=k with a 0.3% fee: the new product is the old product plus the
        // fee (and rounding dust), never smaller.
        assertGt(kAfter, kBefore, "k must grow by the fee on every swap");
        assertEq(nr0 - r0, 10 * E18, "pool keeps the whole input");
        assertEq(r1 - nr1, out, "pool pays out only the post-fee output");
        // LP supply is untouched by swaps: fees accrue to ALL LPs via k, not via mint.
        assertEq(pair.totalSupply(), 1e21, "no LP minted by a swap");
    }

    // ------------------------------------------------------------------
    // Slippage + deadline
    // ------------------------------------------------------------------

    function test_Swap_SlippageReverts() public {
        vm.prank(trader);
        // One wei above the exact output must trip the guard.
        vm.expectRevert(DexPair.DexPair__InsufficientOutput.selector);
        pair.swapExactTokensForTokens(10 * E18, 9871580343970612989, block.timestamp + 1, true);

        // A wildly optimistic min reverts as well.
        vm.expectRevert(DexPair.DexPair__InsufficientOutput.selector);
        pair.swapExactTokensForTokens(10 * E18, 12 * E18, block.timestamp + 1, true);

        // At-the-boundary min passes: check is `amountOut < amountOutMin`.
        vm.prank(trader);
        uint256 out = pair.swapExactTokensForTokens(10 * E18, 9871580343970612988, block.timestamp + 1, true);
        assertEq(out, 9871580343970612988);
    }

    function test_Swap_DeadlineReverts() public {
        vm.warp(1000);
        // Strictly past the deadline reverts.
        vm.prank(trader);
        vm.expectRevert(DexPair.DexPair__Expired.selector);
        pair.swapExactTokensForTokens(1 * E18, 0, 999, true);
        // Equal timestamp is still valid (block.timestamp > deadline is false).
        vm.prank(trader);
        uint256 out = pair.swapExactTokensForTokens(1 * E18, 0, 1000, true);
        assertGt(out, 0, "swap at the exact deadline goes through");
    }

    // ------------------------------------------------------------------
    // Guard rails
    // ------------------------------------------------------------------

    function test_Swap_ZeroAmountReverts() public {
        vm.expectRevert(DexPair.DexPair__ZeroAmount.selector);
        pair.swapExactTokensForTokens(0, 0, block.timestamp + 1, true);
    }

    function test_Swap_DustInputRevertsAsInsufficientOutput() public {
        // 1 wei into a 1000e18 pool: out = floor(1 * 997 * 1e21 / (1e21*1000 + 997)) = 0.
        // The library returns 0 without reverting; the pair refuses to send it.
        vm.prank(trader);
        vm.expectRevert(DexPair.DexPair__InsufficientOutput.selector);
        pair.swapExactTokensForTokens(1, 0, block.timestamp + 1, true);
    }

    function test_Swap_EmptyPoolReverts() public {
        DexPair empty = new DexPair(address(tokenA), address(tokenB));
        vm.expectRevert(AMMLibrary.AMMLibrary__InsufficientLiquidity.selector);
        empty.swapExactTokensForTokens(1 * E18, 0, block.timestamp + 1, true);
    }

    // ------------------------------------------------------------------
    // Events
    // ------------------------------------------------------------------

    function test_Swap_Events() public {
        vm.expectEmit(true, true, false, true, address(pair));
        emit DexPair.Swap(trader, true, 10 * E18, 9871580343970612988);
        vm.expectEmit(false, false, false, true, address(pair));
        emit DexPair.Sync(1010 * E18, 1000 * E18 - 9871580343970612988);
        vm.prank(trader);
        pair.swapExactTokensForTokens(10 * E18, 0, block.timestamp + 1, true);
    }
}
