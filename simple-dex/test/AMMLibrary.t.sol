// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
// forge-std versi baru: Test gak lagi ngeriv StdError, jadi import eksplisit.
import {stdError} from "forge-std/StdError.sol";
import {AMMLibrary} from "../src/AMMLibrary.sol";

/// @title AMMLibrary tests (roadmap Jum 2 Okt).
/// @notice Vektor eksak dihitung manual (python, lihat docs/uniswap-v2-research.md),
///         bukan dikutip dari hasil run library-nya sendiri.
contract AMMLibraryTest is Test {
    uint256 internal constant E18 = 1e18;

    LibraryCaller internal caller;

    function setUp() public {
        caller = new LibraryCaller();
    }

    // ------------------------------------------------------------------
    // getAmountOut: vektor eksak
    // ------------------------------------------------------------------

    /// @dev (10e18 * 997 * 100e18) / (100e18 * 1000 + 10e18 * 997)
    ///      = 997e39 / 10997e19 = 9066108938801491315 (floor).
    function test_GetAmountOut_ExactHalfPool() public pure {
        uint256 out = AMMLibrary.getAmountOut(10 * E18, 100 * E18, 100 * E18);
        assertEq(out, 9066108938801491315, "10% of pool with fee, pool 100/100");
    }

    function test_GetAmountOut_ExactSmallSwap() public pure {
        uint256 out = AMMLibrary.getAmountOut(1 * E18, 100 * E18, 100 * E18);
        assertEq(out, 987158034397061298, "1% of pool with fee, pool 100/100");
    }

    function test_GetAmountOut_ExactUnbalancedReserves() public pure {
        // (5e18 * 997 * 50e18) / (200e18 * 1000 + 5e18 * 997) = 1215942629948532819
        uint256 out = AMMLibrary.getAmountOut(5 * E18, 200 * E18, 50 * E18);
        assertEq(out, 1215942629948532819, "swap against 200/50 pool");
    }

    /// @dev Tanpa fee, 10e18 ke pool 100/100 harusnya dapat 9.0909e18
    ///      (10e18*100e18/110e18). Dengan fee 0.3% hasilnya 9.0661e18, jadi
    ///      harus di antara 9e18 (batas longgar bawah) dan nilai tanpa fee.
    function test_GetAmountOut_FeeReducesOutput() public pure {
        uint256 out = AMMLibrary.getAmountOut(10 * E18, 100 * E18, 100 * E18);
        assertLt(out, 9090909090909090909, "fee harus mengurangi output");
        assertGt(out, 9 * E18, "fee tidak boleh memangkas 0.3% lebih drastis dari ini");
    }

    function test_GetAmountOut_ZeroInputReverts() public {
        vm.expectRevert(AMMLibrary.AMMLibrary__InsufficientInput.selector);
        caller.callGetAmountOut(0, 100 * E18, 100 * E18);
    }

    function test_GetAmountOut_EmptyReserveReverts() public {
        vm.expectRevert(AMMLibrary.AMMLibrary__InsufficientLiquidity.selector);
        caller.callGetAmountOut(1 * E18, 0, 100 * E18);
        vm.expectRevert(AMMLibrary.AMMLibrary__InsufficientLiquidity.selector);
        caller.callGetAmountOut(1 * E18, 100 * E18, 0);
    }

    // ------------------------------------------------------------------
    // getAmountOut: properti (fuzz)
    // ------------------------------------------------------------------

    /// @dev amountOut must be < reserveOut (a swap can never drain the pool).
    ///      Widths are chosen so the internal product 997 * in * reserveOut cannot
    ///      overflow uint256: 997 * 2^112 * 2^128 ~= 2^250 < 2^256. On overflow
    ///      Solidity panics (revert), which fails the fuzz run.
    function testFuzz_GetAmountOut_NeverDrainsPool(
        uint112 amountIn,
        uint120 reserveIn,
        uint128 reserveOut
    ) public pure {
        vm.assume(reserveIn > 0 && reserveOut > 0 && amountIn > 0);
        uint256 out = AMMLibrary.getAmountOut(amountIn, reserveIn, reserveOut);
        assertLt(out, uint256(reserveOut));
    }

    /// @dev amountOut is monotonic non-decreasing in amountIn with reserves fixed.
    function testFuzz_GetAmountOut_MonotonicInInput(
        uint112 amountInA,
        uint112 amountInB,
        uint120 reserveIn,
        uint128 reserveOut
    ) public pure {
        vm.assume(reserveIn > 0 && reserveOut > 0);
        vm.assume(amountInA > 0 && amountInB > amountInA);
        uint256 outA = AMMLibrary.getAmountOut(amountInA, reserveIn, reserveOut);
        uint256 outB = AMMLibrary.getAmountOut(amountInB, reserveIn, reserveOut);
        assertGe(outB, outA);
    }

    /// @dev Invariant k: (reserveIn + amountIn) * (reserveOut - amountOut) >= reserveIn * reserveOut.
    ///      Fee 0.3% menjamin produk SESUDAH swap selalu >= produk SEBELUM (integer
    ///      pembulatan ke bawah bikin strictly lebih besar hampir selalu).
    function testFuzz_GetAmountOut_ProductNeverDecreases(
        uint112 amountIn,
        uint120 reserveIn,
        uint128 reserveOut
    ) public pure {
        vm.assume(reserveIn > 0 && reserveOut > 0 && amountIn > 0);
        uint256 out = AMMLibrary.getAmountOut(amountIn, reserveIn, reserveOut);
        uint256 kBefore = uint256(reserveIn) * uint256(reserveOut);
        // Bounded by (2^120 + 2^112) * 2^128 < 2^249, no overflow.
        uint256 kAfter = (uint256(reserveIn) + amountIn) * (uint256(reserveOut) - out);
        assertGe(kAfter, kBefore);
    }

    // ------------------------------------------------------------------
    // getAmountIn
    // ------------------------------------------------------------------

    /// @dev Vektor eksak: getAmountIn(9066108938801491315, 100e18, 100e18) = 10e18.
    ///      (round-trip persis untuk swap 10e18 di pool 100/100)
    function test_GetAmountIn_Exact() public pure {
        uint256 inp = AMMLibrary.getAmountIn(9066108938801491315, 100 * E18, 100 * E18);
        assertEq(inp, 10 * E18);
    }

    /// @dev Round-trip: getAmountOut(getAmountIn(x, ...)) >= x selalu (ceil +1).
    ///      DOMAIN: round-trip cuma didefinisikan kalau requiredIn masih muat di
    ///      domain input getAmountOut. Konvensi Uniswap v2: reserve & input <= 2^112,
    ///      supaya amountIn*997*reserveOut <= 2^112 * 2^10 * 2^120 < 2^256 gak overflow.
    ///      Kalau reserveIn kecil banget relatif ke amountOut (mis. 10756 vs ~2^120),
    ///      requiredIn meledak di luar domain itu dan getAmountOut PANIC overflow.
    ///      Itu failure-safe (revert, gak ada dana pindah), didokumentasikan sebagai
    ///      batas domain, bukan bug: lihat test domain-boundary di bawah.
    function testFuzz_GetAmountIn_ConsistentWithGetAmountOut(
        uint120 amountOut,
        uint120 reserveIn,
        uint120 reserveOut
    ) public pure {
        vm.assume(reserveIn > 0 && reserveOut > 1 && amountOut > 0 && amountOut < reserveOut);
        uint256 requiredIn = AMMLibrary.getAmountIn(amountOut, reserveIn, reserveOut);
        // Skip konfigurasi yang requiredIn-nya keluar domain input (>= 2^112):
        // di luar ini getAmountOut sengaja gak dijamin (lihat natspec AMMLibrary).
        vm.assume(requiredIn <= type(uint112).max);
        uint256 achievedOut = AMMLibrary.getAmountOut(requiredIn, reserveIn, reserveOut);
        assertGe(achievedOut, uint256(amountOut));
    }

    /// @dev Boundary domain: config ekstrem (reserveIn mungil, amountOut ~ reserveOut)
    ///      menghasilkan requiredIn >> 2^112, dan round-trip-nya PANIC overflow di
    ///      getAmountOut. Test ini nge-kunci perilaku itu secara eksplisit supaya
    ///      batas domainnya kontrak dokumen, bukan kejadian yang nge-skip diem-diem.
    function test_GetAmountIn_RoundTripOutsideDomainPanics() public {
        // Counterexample asli dari fuzz run (amountOut = reserveOut - 2, reserveIn mungil).
        uint256 amountOut = 1329227995784915872903807060280344572; // ~2^120
        uint256 reserveIn = 10_756;
        uint256 reserveOut = 1329227995784915872903807060280344574;
        uint256 requiredIn = AMMLibrary.getAmountIn(amountOut, reserveIn, reserveOut);
        assertGt(requiredIn, type(uint112).max, "config ini harus di luar domain");
        // Panic(0x11) = arithmetic overflow: failure-safe, tx revert tanpa state change.
        vm.expectRevert(stdError.arithmeticError);
        caller.callGetAmountOut(requiredIn, reserveIn, reserveOut);
    }

    /// @dev Corner dalam domain: requiredIn pas di sekitar 2^112 tetap round-trip.
    function test_GetAmountIn_RoundTripAtDomainEdge() public pure {
        // Pool ekstrem tapi valid: reserveIn kecil, output besar, requiredIn ~1.002e15
        // (masih < 2^112 ~ 5.19e33) dan perkalian internal aman.
        uint256 amountOut = 999_000e18;
        uint256 reserveIn = 1e12;
        uint256 reserveOut = 1_000_000e18;
        uint256 requiredIn = AMMLibrary.getAmountIn(amountOut, reserveIn, reserveOut);
        assertLe(requiredIn, type(uint112).max, "harus masih di dalam domain");
        uint256 achievedOut = AMMLibrary.getAmountOut(requiredIn, reserveIn, reserveOut);
        assertGe(achievedOut, amountOut, "ceil +1 harus menjamin round-trip");
    }

    function testFuzz_GetAmountIn_MonotonicInOutput(
        uint120 amountOutA,
        uint120 amountOutB,
        uint120 reserveIn,
        uint120 reserveOut
    ) public pure {
        vm.assume(reserveIn > 0 && reserveOut > 1);
        vm.assume(amountOutA > 0 && amountOutB > amountOutA && amountOutB < reserveOut);
        uint256 inA = AMMLibrary.getAmountIn(amountOutA, reserveIn, reserveOut);
        uint256 inB = AMMLibrary.getAmountIn(amountOutB, reserveIn, reserveOut);
        assertGe(inB, inA);
    }

    function test_GetAmountIn_ZeroOutputReverts() public {
        vm.expectRevert(AMMLibrary.AMMLibrary__InsufficientOutput.selector);
        caller.callGetAmountIn(0, 100 * E18, 100 * E18);
    }

    function test_GetAmountIn_OutputTooLargeReverts() public {
        vm.expectRevert(AMMLibrary.AMMLibrary__InsufficientLiquidity.selector);
        caller.callGetAmountIn(100 * E18, 100 * E18, 100 * E18);
    }

    // ------------------------------------------------------------------
    // quote
    // ------------------------------------------------------------------

    function test_Quote_Exact() public pure {
        assertEq(AMMLibrary.quote(5 * E18, 10 * E18, 20 * E18), 10 * E18);
        // Pembulatan ke bawah: 1e18 * 3e18 / 2e18 = 1.5e18 -> floor 1.5e18 persis.
        assertEq(AMMLibrary.quote(1 * E18, 2 * E18, 3 * E18), 15e17);
        // Kasus yang bener-bener floor: 1e18 * 1 / 3 = 0.333e18
        assertEq(AMMLibrary.quote(1, 3, 1), 0);
    }

    function testFuzz_Quote_Proportional(uint128 amountA, uint128 reserveA, uint128 reserveB) public pure {
        // amountA < reserveA is required for the second assert: quoting MORE of
        // asset A than the pool holds yields amountB >= reserveB (correct behavior,
        // out of scope for this proportional-share property).
        vm.assume(amountA > 0 && reserveA > 0 && reserveB > 0 && amountA < reserveA);
        uint256 b = AMMLibrary.quote(amountA, reserveA, reserveB);
        // Rasio tetap terjaga dalam batas pembulatan: b * reserveA <= amountA * reserveB
        assertLe(uint256(b) * uint256(reserveA), uint256(amountA) * uint256(reserveB));
        assertLt(uint256(b), uint256(reserveB));
    }

    // ------------------------------------------------------------------
    // sqrt (Babylonian)
    // ------------------------------------------------------------------

    function test_Sqrt_ExactVectors() public pure {
        assertEq(AMMLibrary.sqrt(0), 0);
        assertEq(AMMLibrary.sqrt(1), 1);
        assertEq(AMMLibrary.sqrt(2), 1);
        assertEq(AMMLibrary.sqrt(3), 1);
        assertEq(AMMLibrary.sqrt(4), 2);
        assertEq(AMMLibrary.sqrt(99), 9);
        assertEq(AMMLibrary.sqrt(100), 10);
        assertEq(AMMLibrary.sqrt(1e18), 1e9);
        // sqrt(4e18 * 9e18) = 6e18 (vektor first provision di DexPair tests)
        assertEq(AMMLibrary.sqrt(4 * E18 * 9 * E18), 6 * E18);
    }

    function testFuzz_Sqrt_FloorBounds(uint256 y) public pure {
        uint256 z = AMMLibrary.sqrt(y);
        assertLe(z * z, y);
        // Guard the upper-bound check itself: when z == 2^128 - 1 (y near
        // 2^256), (z + 1) * (z + 1) == 2^256 overflows uint256. In that corner
        // the bound holds trivially (y < 2^256), so skip the multiplication.
        if (z < (uint256(1) << 128) - 1) {
            assertLt(y, (z + 1) * (z + 1));
        }
    }
}

/// @dev Internal library functions are linked into the CALLING contract, so a
///      revert raised by the library happens at the test function's own frame.
///      vm.expectRevert only observes reverts from a lower call depth and would
///      report "call didn't revert at a lower depth than cheatcode call depth".
///      Routing the calls through this helper gives the revert a real call frame.
contract LibraryCaller {
    function callGetAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) external pure returns (uint256) {
        return AMMLibrary.getAmountOut(amountIn, reserveIn, reserveOut);
    }

    function callGetAmountIn(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut
    ) external pure returns (uint256) {
        return AMMLibrary.getAmountIn(amountOut, reserveIn, reserveOut);
    }
}
