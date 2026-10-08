// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {IERC20Errors} from "openzeppelin-contracts/interfaces/IERC6093.sol";
import {DexPair} from "../src/DexPair.sol";
import {ERC20Mock} from "../src/mocks/ERC20Mock.sol";
import {FeeOnTransferMock} from "../src/mocks/FeeOnTransferMock.sol";

/// @title DexPair liquidity tests (roadmap Sab 3 Okt).
/// @notice Exact vectors are hand-computed (python: isqrt and integer division),
///         never copied from a run of the contract under test. The pair sorts
///         tokens in the constructor, so every test speaks in canonical
///         token0/token1 terms via the helpers below.
contract DexPairLiquidityTest is Test {
    uint256 internal constant E18 = 1e18;
    uint256 internal constant ML = 1000; // DexPair.MINIMUM_LIQUIDITY

    ERC20Mock internal tokenA;
    ERC20Mock internal tokenB;
    DexPair internal pair;

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    function setUp() public {
        tokenA = new ERC20Mock("Token A", "TKA");
        tokenB = new ERC20Mock("Token B", "TKB");
        pair = new DexPair(address(tokenA), address(tokenB));

        tokenA.mint(alice, 1_000_000 * E18);
        tokenB.mint(alice, 1_000_000 * E18);
        tokenA.mint(bob, 1_000_000 * E18);
        tokenB.mint(bob, 1_000_000 * E18);

        vm.startPrank(alice);
        tokenA.approve(address(pair), type(uint256).max);
        tokenB.approve(address(pair), type(uint256).max);
        vm.stopPrank();
        vm.startPrank(bob);
        tokenA.approve(address(pair), type(uint256).max);
        tokenB.approve(address(pair), type(uint256).max);
        vm.stopPrank();
    }

    // ------------------------------------------------------------------
    // Canonical-order helpers
    // ------------------------------------------------------------------

    function _t0() internal view returns (ERC20Mock) {
        return pair.token0() == address(tokenA) ? tokenA : tokenB;
    }

    function _t1() internal view returns (ERC20Mock) {
        return pair.token0() == address(tokenA) ? tokenB : tokenA;
    }

    /// @dev Seed with (4e18, 9e18): LP = sqrt(4e18 * 9e18) = 6e18, all to alice.
    function _seed4x9() internal {
        vm.prank(alice);
        pair.addLiquidity(4 * E18, 9 * E18);
    }

    /// @dev Seed with (1000e18, 1000e18): LP = sqrt(1e42) = 1e21, all to alice.
    function _seed1000x1000() internal {
        vm.prank(alice);
        pair.addLiquidity(1000 * E18, 1000 * E18);
    }

    // ------------------------------------------------------------------
    // First provision (sqrt math + MINIMUM_LIQUIDITY)
    // ------------------------------------------------------------------

    function test_FirstProvision_SqrtMathExact() public {
        vm.prank(alice);
        (uint256 a0, uint256 a1, uint256 liq) = pair.addLiquidity(4 * E18, 9 * E18);

        // liquidity = sqrt(amount0 * amount1) = sqrt(36e36) = 6e18, exact.
        assertEq(a0, 4 * E18, "empty pool takes the full desired amount0");
        assertEq(a1, 9 * E18, "empty pool takes the full desired amount1");
        assertEq(liq, 6 * E18, "LP = sqrt(4e18 * 9e18)");

        // User holds LP - MINIMUM_LIQUIDITY; the pair itself holds the rest.
        assertEq(pair.balanceOf(alice), 6 * E18 - ML, "user LP = 6e18 - 1000");
        assertEq(pair.balanceOf(address(pair)), ML, "MINIMUM_LIQUIDITY held by pair");
        assertEq(pair.totalSupply(), 6 * E18, "totalSupply includes locked LP");

        (uint256 r0, uint256 r1) = pair.getReserves();
        assertEq(r0, 4 * E18, "reserve0");
        assertEq(r1, 9 * E18, "reserve1");

        // Exact token movement: nothing extra pulled, nothing left behind.
        assertEq(_t0().balanceOf(alice), 1_000_000 * E18 - 4 * E18, "alice token0 spent");
        assertEq(_t1().balanceOf(alice), 1_000_000 * E18 - 9 * E18, "alice token1 spent");
        assertEq(_t0().balanceOf(address(pair)), 4 * E18, "pair token0 balance");
        assertEq(_t1().balanceOf(address(pair)), 9 * E18, "pair token1 balance");
    }

    function test_FirstProvision_GeometricMeanIsDepositOrderIndependent() public {
        // sqrt(a * b) is symmetric, so LP minted must not depend on which side
        // got the 4 and which got the 9. Same two tokens, mirrored deposit.
        vm.prank(alice);
        (, , uint256 liqAB) = pair.addLiquidity(4 * E18, 9 * E18);

        DexPair mirrored = new DexPair(address(tokenB), address(tokenA));
        vm.startPrank(alice);
        tokenA.approve(address(mirrored), type(uint256).max);
        tokenB.approve(address(mirrored), type(uint256).max);
        (, , uint256 liqBA) = mirrored.addLiquidity(9 * E18, 4 * E18);
        vm.stopPrank();

        assertEq(liqAB, liqBA, "LP must be symmetric in the deposit amounts");
    }

    function test_FirstProvision_MinimumLiquidityLockedForever() public {
        _seed4x9();

        // The locked 1000 wei sit on the pair (OZ v5 forbids minting to
        // address(0); the effect is identical to Uniswap v2: unclaimable).
        assertEq(pair.balanceOf(address(pair)), ML);
        // No entry point moves them: alice burning everything she owns leaves
        // the locked share backing 667/1500 wei of reserves (1000 * r / 6e18).
        uint256 aliceLp = pair.balanceOf(alice);
        vm.prank(alice);
        (uint256 got0, uint256 got1) = pair.removeLiquidity(aliceLp);
        assertEq(got0, 3999999999999999333, "remove-all amount0 (floor)");
        assertEq(got1, 8999999999999998500, "remove-all amount1 (floor)");

        (uint256 r0, uint256 r1) = pair.getReserves();
        assertEq(r0, 667, "residual reserve0 == locked LP share");
        assertEq(r1, 1500, "residual reserve1 == locked LP share");
        assertEq(pair.totalSupply(), ML, "only the locked LP remains");
        assertEq(_t0().balanceOf(address(pair)), 667, "pool still holds the dust");
        assertEq(_t1().balanceOf(address(pair)), 1500, "pool still holds the dust");
    }

    function test_FirstProvision_TooSmallReverts() public {
        // sqrt(1000 * 1000) = 1000 == MINIMUM_LIQUIDITY: user would get 0 LP.
        vm.startPrank(alice);
        vm.expectRevert(DexPair.DexPair__InsufficientLiquidityMinted.selector);
        pair.addLiquidity(1000, 1000);
        // sqrt(1 * 1) = 1: same outcome.
        vm.expectRevert(DexPair.DexPair__InsufficientLiquidityMinted.selector);
        pair.addLiquidity(1, 1);
        vm.stopPrank();
        // Nothing was taken and no LP exists.
        assertEq(pair.totalSupply(), 0, "reverted provision must not mint");
        (uint256 r0, uint256 r1) = pair.getReserves();
        assertEq(r0, 0, "reverted provision must not touch reserves");
        assertEq(r1, 0, "reverted provision must not touch reserves");
    }

    // ------------------------------------------------------------------
    // Subsequent provisions (proportional / unbalanced + refund)
    // ------------------------------------------------------------------

    function test_AddLiquidity_ProportionalExact() public {
        _seed1000x1000();

        vm.prank(bob);
        (uint256 a0, uint256 a1, uint256 liq) = pair.addLiquidity(10 * E18, 10 * E18);

        assertEq(a0, 10 * E18, "deposit at pool ratio takes amount0 fully");
        assertEq(a1, 10 * E18, "deposit at pool ratio takes amount1 fully");
        // liquidity = amount0 * totalSupply / reserve0 = 10e18 * 1e21 / 1000e18
        assertEq(liq, 10 * E18, "LP = 1% of supply for 1% of the pool");
        assertEq(pair.balanceOf(bob), 10 * E18, "bob LP balance");
        assertEq(pair.totalSupply(), 1e21 + 10 * E18, "supply grows by minted LP");
        (uint256 r0, uint256 r1) = pair.getReserves();
        assertEq(r0, 1010 * E18, "reserve0 grows by deposit");
        assertEq(r1, 1010 * E18, "reserve1 grows by deposit");
        // Alice owns 1e21 - 1000 LP (she paid for the locked share), so her
        // implied claim on the 1010e18 reserve is 1000e18 minus the dust the
        // 1000 locked wei absorb: (1e21-1000) * 1010e18 / 1.01e21 floored.
        assertEq(
            (pair.balanceOf(alice) * r0) / pair.totalSupply(),
            999999999999999999000,
            "alice still owns her side minus locked-share dust"
        );
    }

    function test_AddLiquidity_Unbalanced_Token0ExcessNotPulled() public {
        _seed1000x1000();
        uint256 aliceT0Before = _t0().balanceOf(alice);
        uint256 aliceT1Before = _t1().balanceOf(alice);

        // Desired (10e18, 5e18) against a 1:1 pool: the binding side is token1,
        // only (5e18, 5e18) is pulled, the token0 surplus is refunded by NOT
        // pulling it (no real transfer for the excess).
        vm.prank(alice);
        (uint256 a0, uint256 a1, uint256 liq) = pair.addLiquidity(10 * E18, 5 * E18);

        assertEq(a0, 5 * E18, "token0 pulled = optimal, not desired");
        assertEq(a1, 5 * E18, "token1 pulled = desired (binding side)");
        // LP = min(5e18 * 1e21 / 1000e18, 5e18 * 1e21 / 1000e18) = 5e18
        assertEq(liq, 5 * E18, "LP minted per min-formula");
        assertEq(_t0().balanceOf(alice), aliceT0Before - 5 * E18, "only 5e18 token0 left alice");
        assertEq(_t1().balanceOf(alice), aliceT1Before - 5 * E18, "only 5e18 token1 left alice");
    }

    function test_AddLiquidity_Unbalanced_Token1BindingSide() public {
        _seed4x9(); // ratio 4:9
        uint256 bobT0Before = _t0().balanceOf(bob);

        // Desired (10e18, 10e18): quote(10e18, 4e18, 9e18) = 22.5e18 > 10e18, so
        // token1 budget binds: amount0Optimal = quote(10e18, 9e18, 4e18) = 4.44e18.
        vm.prank(bob);
        (uint256 a0, uint256 a1, uint256 liq) = pair.addLiquidity(10 * E18, 10 * E18);

        assertEq(a0, 4444444444444444444, "token0 pulled = floor(10e18 * 4 / 9)");
        assertEq(a1, 10 * E18, "token1 pulled fully (binding side)");
        // LP = min(4444444444444444444 * 6e18 / 4e18, 10e18 * 6e18 / 9e18)
        //    = min(6666666666666666666, 6666666666666666666)
        assertEq(liq, 6666666666666666666, "LP per min-formula on a 4:9 pool");
        assertEq(_t0().balanceOf(bob), bobT0Before - 4444444444444444444, "excess token0 refunded");
        assertEq(
            _t0().balanceOf(address(pair)),
            4 * E18 + 4444444444444444444,
            "pair holds exactly the used amounts"
        );
    }

    function testFuzz_AddLiquidity_LpMatchesMinFormula(uint128 amount0, uint128 amount1) public {
        _seed1000x1000();
        amount0 = uint128(bound(amount0, 1e12, 100 * E18));
        amount1 = uint128(bound(amount1, 1e12, 100 * E18));

        uint256 tsBefore = pair.totalSupply();
        (uint256 r0, uint256 r1) = pair.getReserves();

        vm.prank(bob);
        (uint256 used0, uint256 used1, uint256 liq) = pair.addLiquidity(amount0, amount1);

        // The pool takes the optimal ratio-corrected amounts, never more than
        // desired, and mints exactly the min-formula LP for what it took.
        assertLe(used0, amount0, "never pulls more token0 than desired");
        assertLe(used1, amount1, "never pulls more token1 than desired");
        assertEq(
            liq,
            (used0 * tsBefore) / r0 < (used1 * tsBefore) / r1
                ? (used0 * tsBefore) / r0
                : (used1 * tsBefore) / r1,
            "LP == min(amount0 * ts / r0, amount1 * ts / r1)"
        );
    }

    function test_AddLiquidity_ZeroAmountReverts() public {
        vm.startPrank(alice);
        vm.expectRevert(DexPair.DexPair__ZeroAmount.selector);
        pair.addLiquidity(0, 1 * E18);
        vm.expectRevert(DexPair.DexPair__ZeroAmount.selector);
        pair.addLiquidity(1 * E18, 0);
        vm.stopPrank();
    }

    // ------------------------------------------------------------------
    // removeLiquidity
    // ------------------------------------------------------------------

    function test_RemoveLiquidity_ProportionalExact() public {
        _seed4x9();
        uint256 aliceLp = pair.balanceOf(alice); // 6e18 - 1000
        uint256 half = aliceLp / 2; // 2999999999999999500

        vm.prank(alice);
        (uint256 got0, uint256 got1) = pair.removeLiquidity(half);

        // amounts = lp * reserves / totalSupply, computed against supply BEFORE
        // the burn: 2999999999999999500 * 4e18 / 6e18 and * 9e18 / 6e18.
        assertEq(got0, 1999999999999999666, "remove amount0 (floor)");
        assertEq(got1, 4499999999999999250, "remove amount1 (floor)");
        assertEq(_t0().balanceOf(alice), 1_000_000 * E18 - 4 * E18 + got0, "token0 returned");
        assertEq(_t1().balanceOf(alice), 1_000_000 * E18 - 9 * E18 + got1, "token1 returned");
        assertEq(pair.balanceOf(alice), aliceLp - half, "LP burned");
        assertEq(pair.totalSupply(), 6 * E18 - half, "supply shrinks by burned LP");
        (uint256 r0, uint256 r1) = pair.getReserves();
        assertEq(r0, 4 * E18 - got0, "reserve0 shrinks by payout");
        assertEq(r1, 9 * E18 - got1, "reserve1 shrinks by payout");
        // Pool still fully solvent after the burn.
        assertEq(_t0().balanceOf(address(pair)), r0, "pair balance0 == reserve0");
        assertEq(_t1().balanceOf(address(pair)), r1, "pair balance1 == reserve1");
    }

    function test_RemoveLiquidity_ZeroReverts() public {
        _seed4x9();
        vm.expectRevert(DexPair.DexPair__ZeroAmount.selector);
        pair.removeLiquidity(0);
    }

    function test_RemoveLiquidity_MoreThanBalanceReverts() public {
        _seed4x9();
        uint256 aliceLp = pair.balanceOf(alice);
        // _burn underflows the caller balance: OZ ERC20InsufficientBalance.
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientBalance.selector, alice, aliceLp, aliceLp + 1
            )
        );
        vm.prank(alice);
        pair.removeLiquidity(aliceLp + 1);
        // A holder with no LP at all hits the same guard once the amount is big
        // enough to pass the dust guard (with 1 wei the InsufficientLiquidityBurned
        // check fires first: floor amounts to 0 before _burn is reached).
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, bob, 0, 2 * E18)
        );
        vm.prank(bob);
        pair.removeLiquidity(2 * E18);
    }

    function test_RemoveLiquidity_DustReverts() public {
        // (1e6, 1e18) pool: totalSupply = sqrt(1e24) = 1e12, alice owns 1e12-1000.
        vm.prank(alice);
        pair.addLiquidity(1e6, 1 * E18);
        assertEq(pair.totalSupply(), 1e12, "pool seeded");

        // Burning 1000 LP pays floor(1000 * 1e6 / 1e12) = 0 on token0 while
        // token1 would pay out: refuse instead of stranding the share.
        vm.expectRevert(DexPair.DexPair__InsufficientLiquidityBurned.selector);
        vm.prank(alice);
        pair.removeLiquidity(1000);
    }

    // ------------------------------------------------------------------
    // Constructor: sorting + guards
    // ------------------------------------------------------------------

    function test_Constructor_SortsTokens() public view {
        address tA = address(tokenA);
        address tB = address(tokenB);
        assertEq(pair.token0(), tA < tB ? tA : tB, "token0 is the lower address");
        assertEq(pair.token1(), tA < tB ? tB : tA, "token1 is the higher address");
        assertLt(uint160(pair.token0()), uint160(pair.token1()), "canonical order");
    }

    function test_Constructor_RevertsOnBadTokens() public {
        vm.expectRevert(DexPair.DexPair__IdenticalAddresses.selector);
        new DexPair(address(tokenA), address(tokenA));
        vm.expectRevert(DexPair.DexPair__ZeroAddress.selector);
        new DexPair(address(tokenA), address(0));
        vm.expectRevert(DexPair.DexPair__ZeroAddress.selector);
        new DexPair(address(0), address(tokenB));
    }

    // ------------------------------------------------------------------
    // Fee-on-transfer tokens (active detection, addLiquidity side)
    // ------------------------------------------------------------------

    function test_AddLiquidity_FeeOnTransferRejected() public {
        FeeOnTransferMock fot = new FeeOnTransferMock("Fee Token", "FOT", 100); // 1% fee
        ERC20Mock clean = new ERC20Mock("Clean", "CLN");
        DexPair fotPair = new DexPair(address(fot), address(clean));
        fot.mint(alice, 1000 * E18);
        clean.mint(alice, 1000 * E18);
        vm.startPrank(alice);
        fot.approve(address(fotPair), type(uint256).max);
        clean.approve(address(fotPair), type(uint256).max);

        // The pair would receive 99% of the deposit while reserves would count
        // 100%: detected and reverted, so a FoT token can never seed the pool.
        vm.expectRevert(DexPair.DexPair__FeeOnTransferNotSupported.selector);
        fotPair.addLiquidity(1000 * E18, 1000 * E18);
        vm.stopPrank();

        assertEq(fotPair.totalSupply(), 0, "nothing minted");
        (uint256 r0, uint256 r1) = fotPair.getReserves();
        assertEq(r0, 0, "no reserve recorded");
        assertEq(r1, 0, "no reserve recorded");
    }

    // ------------------------------------------------------------------
    // Events
    // ------------------------------------------------------------------

    function test_Events_MintSyncBurn() public {
        vm.expectEmit(true, false, false, true, address(pair));
        emit DexPair.Mint(alice, 4 * E18, 9 * E18);
        vm.expectEmit(false, false, false, true, address(pair));
        emit DexPair.Sync(4 * E18, 9 * E18);
        _seed4x9();

        vm.expectEmit(true, false, false, true, address(pair));
        emit DexPair.Burn(alice, 1999999999999999666, 4499999999999999250);
        vm.expectEmit(false, false, false, true, address(pair));
        emit DexPair.Sync(4 * E18 - 1999999999999999666, 9 * E18 - 4499999999999999250);
        // Capture first: vm.prank applies to the very next external call, and
        // `pair.balanceOf(alice)` inside the argument list is itself one, it
        // would silently consume the prank and the burn would run as the test
        // contract (reverting with ERC20InsufficientBalance).
        uint256 aliceLp = pair.balanceOf(alice);
        vm.prank(alice);
        pair.removeLiquidity(aliceLp / 2);
    }
}
