// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title AMMLibrary
/// @notice Pure math for a Uniswap-v2-style constant-product AMM with a 0.3% swap fee.
/// @dev Rounding is always chosen to favor the pool:
///      - outputs (`getAmountOut`, `quote`) round down,
///      - required inputs (`getAmountIn`) round up (+1).
///      All functions are `pure` so they are trivially testable without state.
library AMMLibrary {
    /// @dev 0.3% fee encoded as 997/1000 (Uniswap v2 convention).
    uint256 internal constant FEE_NUMERATOR = 997;
    uint256 internal constant FEE_DENOMINATOR = 1000;

    error AMMLibrary__InsufficientInput();
    error AMMLibrary__InsufficientOutput();
    error AMMLibrary__InsufficientLiquidity();

    /// @notice Given an input amount and pair reserves, returns the maximum output
    ///         amount of the other asset, after the 0.3% fee.
    /// @dev Derived from x*y=k with the fee applied to the input:
    ///      (reserveIn + amountIn*997/1000) * (reserveOut - amountOut) = reserveIn * reserveOut
    ///      solved for amountOut:
    ///      amountOut = (amountIn * 997 * reserveOut) / (reserveIn * 1000 + amountIn * 997)
    ///      Integer division rounds down, which leaves the fee dust inside the pool.
    ///
    ///      DOMAIN (Uniswap v2 convention): the math is only guaranteed while
    ///      amountIn * 997 * reserveOut < 2^256. With reserves and inputs <= 2^112
    ///      (Uniswap v2 uses uint112 reserves for exactly this), the product is
    ///      <= 2^112 * 2^10 * 2^120 < 2^256 and can never overflow. Outside that
    ///      domain the function PANICS (arithmetic overflow, Solidity 0.8) which
    ///      reverts the transaction: failure-safe, no state change, no fund loss.
    ///      Callers that need the full uint256 range must bound inputs themselves.
    /// @param amountIn  Amount of the input asset being swapped in.
    /// @param reserveIn Pool balance of the input asset.
    /// @param reserveOut Pool balance of the output asset.
    /// @return amountOut Amount of the output asset the caller receives.
    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) internal pure returns (uint256 amountOut) {
        if (amountIn == 0) revert AMMLibrary__InsufficientInput();
        if (reserveIn == 0 || reserveOut == 0) revert AMMLibrary__InsufficientLiquidity();
        uint256 amountInWithFee = amountIn * FEE_NUMERATOR;
        amountOut = (amountInWithFee * reserveOut) / (reserveIn * FEE_DENOMINATOR + amountInWithFee);
    }

    /// @notice Given an output amount and pair reserves, returns the required input
    ///         amount of the other asset, after the 0.3% fee.
    /// @dev Inverse of getAmountOut, rounded up (+1 wei) so the pool never pays
    ///      for rounding. Guarantees getAmountOut(getAmountIn(x, ...)) >= x.
    /// @param amountOut Desired amount of the output asset.
    /// @param reserveIn Pool balance of the input asset.
    /// @param reserveOut Pool balance of the output asset.
    /// @return amountIn Required amount of the input asset.
    function getAmountIn(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut
    ) internal pure returns (uint256 amountIn) {
        if (amountOut == 0) revert AMMLibrary__InsufficientOutput();
        if (reserveIn == 0 || reserveOut == 0 || amountOut >= reserveOut) {
            revert AMMLibrary__InsufficientLiquidity();
        }
        uint256 numerator = reserveIn * amountOut * FEE_DENOMINATOR;
        uint256 denominator = (reserveOut - amountOut) * FEE_NUMERATOR;
        // The +1 is the ceiling: without it, getAmountOut(round-trip) could fall
        // 1 wei short of the requested output and the pool would subsidize the user.
        amountIn = numerator / denominator + 1;
    }

    /// @notice Given some amount of one asset and the pair reserves, returns the
    ///         corresponding amount of the other asset at the current reserve ratio.
    /// @dev Used for LP minting: deposit at the pool ratio and `quote` tells you
    ///      the matching side. Rounds down (favors the pool).
    /// @param amountA Amount of asset A.
    /// @param reserveA Pool balance of asset A.
    /// @param reserveB Pool balance of asset B.
    /// @return amountB Corresponding amount of asset B.
    function quote(
        uint256 amountA,
        uint256 reserveA,
        uint256 reserveB
    ) internal pure returns (uint256 amountB) {
        if (amountA == 0) revert AMMLibrary__InsufficientInput();
        if (reserveA == 0 || reserveB == 0) revert AMMLibrary__InsufficientLiquidity();
        amountB = (amountA * reserveB) / reserveA;
    }

    /// @notice Integer square root (Babylonian method), floor(sqrt(y)).
    /// @dev Used for first-provision LP minting: liquidity = sqrt(amount0 * amount1).
    ///      Iterates x' = (y/x + x) / 2 until fixpoint. Standard Uniswap v2 code.
    /// @param y The value to take the square root of.
    /// @return z floor(sqrt(y)); sqrt(0) = 0.
    function sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
        // else z = 0
    }
}
