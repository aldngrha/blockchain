// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";
import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "openzeppelin-contracts/utils/math/Math.sol";
import {AMMLibrary} from "./AMMLibrary.sol";

/// @title DexPair
/// @notice One contract = one two-token constant-product pool AND its LP token.
/// @dev Deviations from Uniswap v2, all deliberate:
///      1. Explicit-amount API (`transferFrom` inside the pair) instead of v2's
///         "send tokens first, then call" flow. Simpler to use, no factory,
///         no flash swaps in v1.
///      2. CEI ordering (state updated before external calls) instead of v2's
///         optimistic transfer. The Uniswap-style `lock` modifier is kept as
///         defense in depth.
///      3. MINIMUM_LIQUIDITY is minted to `address(this)` instead of `address(0)`
///         because OpenZeppelin v5 forbids minting to the zero address. The
///         effect is identical: 1000 wei LP are unclaimable forever.
///      4. Fee-on-transfer tokens are unsupported and actively detected (revert).
contract DexPair is ERC20 {
    using SafeERC20 for IERC20;

    /// @notice Permanently locked LP wei, minted to the pair itself on the first
    ///         provision. Blocks the first-depositor share-inflation attack and
    ///         keeps reserves away from zero (no division by zero in quote math).
    uint256 public constant MINIMUM_LIQUIDITY = 1000;

    /// @notice First token of the pair (sorted by address: token0 < token1).
    address public immutable token0;
    /// @notice Second token of the pair (sorted by address: token0 < token1).
    address public immutable token1;

    /// @notice Internal pool accounting for token0. Mirrors balanceOf(pair) exactly.
    uint256 public reserve0;
    /// @notice Internal pool accounting for token1. Mirrors balanceOf(pair) exactly.
    uint256 public reserve1;

    // ------------------------------------------------------------------
    // Reentrancy lock, Uniswap v2 style: a plain bool instead of OZ's
    // ReentrancyGuard. Parity with v2 (the pattern every AMM auditor knows),
    // one storage slot, no inheritance overhead.
    // ------------------------------------------------------------------
    bool private unlocked = true;

    modifier lock() {
        if (!unlocked) revert DexPair__Locked();
        unlocked = false;
        _;
        unlocked = true;
    }

    // ----------------------------- Errors -----------------------------
    error DexPair__Locked();
    error DexPair__IdenticalAddresses();
    error DexPair__ZeroAddress();
    error DexPair__ZeroAmount();
    error DexPair__Expired();
    error DexPair__InsufficientOutput();
    error DexPair__InsufficientLiquidityMinted();
    error DexPair__InsufficientLiquidityBurned();
    error DexPair__FeeOnTransferNotSupported();

    // ----------------------------- Events -----------------------------
    event Mint(address indexed sender, uint256 amount0, uint256 amount1);
    event Burn(address indexed sender, uint256 amount0, uint256 amount1);
    event Swap(address indexed sender, bool indexed zeroForOne, uint256 amountIn, uint256 amountOut);
    event Sync(uint256 reserve0, uint256 reserve1);

    /// @param tokenA First token of the pair (any order, gets sorted).
    /// @param tokenB Second token of the pair (any order, gets sorted).
    constructor(address tokenA, address tokenB) ERC20("SimpleDex LP Token", "SDX-LP") {
        if (tokenA == tokenB) revert DexPair__IdenticalAddresses();
        if (tokenA == address(0) || tokenB == address(0)) revert DexPair__ZeroAddress();
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
    }

    /// @notice Current pool reserves, in the canonical token0/token1 order.
    function getReserves() external view returns (uint256, uint256) {
        return (reserve0, reserve1);
    }

    /// @notice Deposit both tokens, receive LP tokens representing pool share.
    ///
    /// First provision: liquidity = sqrt(amount0 * amount1), with MINIMUM_LIQUIDITY
    /// locked forever. Subsequent provisions: liquidity is the minimum of the
    /// proportional shares of both tokens (whichever side is scarcer wins), so
    /// depositing at a bad ratio only mints what the pool ratio justifies and the
    /// surplus stays with the caller (nothing is transferred for the excess).
    ///
    /// CEI: reserves are updated and LP minted BEFORE the transferFrom calls.
    /// @param amount0Desired Max amount of token0 to deposit.
    /// @param amount1Desired Max amount of token1 to deposit.
    /// @return amount0 Actual amount of token0 taken.
    /// @return amount1 Actual amount of token1 taken.
    /// @return liquidity LP tokens minted to the caller.
    function addLiquidity(
        uint256 amount0Desired,
        uint256 amount1Desired
    ) external lock returns (uint256 amount0, uint256 amount1, uint256 liquidity) {
        if (amount0Desired == 0 || amount1Desired == 0) revert DexPair__ZeroAmount();

        uint256 totalLp = totalSupply();
        if (totalLp == 0) {
            // First provision. The geometric mean makes the initial share of any
            // later depositor independent of the deposit order.
            liquidity = AMMLibrary.sqrt(amount0Desired * amount1Desired);
            if (liquidity <= MINIMUM_LIQUIDITY) revert DexPair__InsufficientLiquidityMinted();
            amount0 = amount0Desired;
            amount1 = amount1Desired;
            reserve0 += amount0;
            reserve1 += amount1;
            // Uniswap v2 mints these to address(0); OZ v5 forbids that, so the
            // pair itself holds them. No code path can burn LP held by the pair
            // (removeLiquidity only burns msg.sender's LP), so the lock is as
            // permanent as v2's.
            _mint(address(this), MINIMUM_LIQUIDITY);
            _mint(msg.sender, liquidity - MINIMUM_LIQUIDITY);
        } else {
            // Already-seeded pool: snap to the pool ratio, refund the surplus by
            // simply not pulling it.
            uint256 amount1Optimal = AMMLibrary.quote(amount0Desired, reserve0, reserve1);
            if (amount1Optimal <= amount1Desired) {
                amount0 = amount0Desired;
                amount1 = amount1Optimal;
            } else {
                // Mathematically guaranteed: amount0Optimal <= amount0Desired.
                // (If the required token1 for all of amount0Desired exceeds what
                // the caller offers, the caller's token1 budget is the binding side.)
                uint256 amount0Optimal = AMMLibrary.quote(amount1Desired, reserve1, reserve0);
                assert(amount0Optimal <= amount0Desired);
                amount0 = amount0Optimal;
                amount1 = amount1Desired;
            }
            liquidity = Math.min(
                (amount0 * totalLp) / reserve0,
                (amount1 * totalLp) / reserve1
            );
            if (liquidity == 0) revert DexPair__InsufficientLiquidityMinted();
            reserve0 += amount0;
            reserve1 += amount1;
            _mint(msg.sender, liquidity);
        }

        emit Mint(msg.sender, amount0, amount1);
        emit Sync(reserve0, reserve1);

        _pullToken(token0, msg.sender, amount0);
        _pullToken(token1, msg.sender, amount1);
    }

    /// @notice Burn LP tokens and receive the proportional share of both tokens.
    /// @dev Shares are computed against totalSupply BEFORE the burn, rounded down
    ///      (the dust stays in the pool, backing the locked MINIMUM_LIQUIDITY).
    /// @param lpAmount Amount of LP tokens to burn.
    /// @return amount0 Token0 amount returned.
    /// @return amount1 Token1 amount returned.
    function removeLiquidity(uint256 lpAmount) external lock returns (uint256 amount0, uint256 amount1) {
        if (lpAmount == 0) revert DexPair__ZeroAmount();

        uint256 totalLp = totalSupply();
        amount0 = (lpAmount * reserve0) / totalLp;
        amount1 = (lpAmount * reserve1) / totalLp;
        // A dust burn would pay out 0 on one side and silently strand the other
        // side's share; refuse it instead.
        if (amount0 == 0 || amount1 == 0) revert DexPair__InsufficientLiquidityBurned();

        _burn(msg.sender, lpAmount);
        reserve0 -= amount0;
        reserve1 -= amount1;

        emit Burn(msg.sender, amount0, amount1);
        emit Sync(reserve0, reserve1);

        IERC20(token0).safeTransfer(msg.sender, amount0);
        IERC20(token1).safeTransfer(msg.sender, amount1);
    }

    /// @notice Swap an exact input amount of token0 for token1 (zeroForOne = true)
    ///         or token1 for token0 (zeroForOne = false).
    /// @dev CEI: reserves are updated BEFORE any external call. The `lock` modifier
    ///      blocks reentry anyway (defense in depth, v2 parity).
    ///      Fee-on-transfer tokens revert: the pool requires the full amountIn to
    ///      arrive, otherwise reserve accounting and real balances diverge.
    /// @param amountIn Exact amount of the input token to swap in.
    /// @param amountOutMin Minimum acceptable output (slippage protection).
    /// @param deadline Transaction must be mined before this timestamp.
    /// @param zeroForOne Direction: true = token0 in / token1 out.
    /// @return amountOut Output amount actually sent to the caller.
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        uint256 deadline,
        bool zeroForOne
    ) external lock returns (uint256 amountOut) {
        if (amountIn == 0) revert DexPair__ZeroAmount();
        if (block.timestamp > deadline) revert DexPair__Expired();

        (uint256 reserveIn, uint256 reserveOut) = zeroForOne ? (reserve0, reserve1) : (reserve1, reserve0);
        amountOut = AMMLibrary.getAmountOut(amountIn, reserveIn, reserveOut);
        // getAmountOut can floor to 0 for dust inputs; treat it as insufficient.
        if (amountOut == 0) revert DexPair__InsufficientOutput();
        if (amountOut < amountOutMin) revert DexPair__InsufficientOutput();

        // Effects first: from here on, internal state is already final.
        if (zeroForOne) {
            reserve0 = reserve0 + amountIn;
            reserve1 = reserve1 - amountOut;
        } else {
            reserve1 = reserve1 + amountIn;
            reserve0 = reserve0 - amountOut;
        }

        emit Swap(msg.sender, zeroForOne, amountIn, amountOut);
        emit Sync(reserve0, reserve1);

        // Interactions.
        address tokenIn = zeroForOne ? token0 : token1;
        address tokenOut = zeroForOne ? token1 : token0;
        _pullToken(tokenIn, msg.sender, amountIn);
        IERC20(tokenOut).safeTransfer(msg.sender, amountOut);
    }

    /// @dev Pull an exact input amount from `from`. Fee-on-transfer tokens fail
    ///      loudly: if the pair receives less than `amount`, reserves would
    ///      overstate the real balances and every downstream ratio (LP mint,
    ///      swap output, withdraw share) would be wrong. Used by addLiquidity
    ///      AND swap, so a fee-on-transfer token can never enter the pool's
    ///      accounting through any state-changing entry point.
    function _pullToken(address token, address from, uint256 amount) internal {
        uint256 balanceBefore = IERC20(token).balanceOf(address(this));
        IERC20(token).safeTransferFrom(from, address(this), amount);
        if (IERC20(token).balanceOf(address(this)) != balanceBefore + amount) {
            revert DexPair__FeeOnTransferNotSupported();
        }
    }
}
