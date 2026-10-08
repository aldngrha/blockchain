import { useMemo } from "react";
import { getAddress } from "viem";
import { useReadContract } from "wagmi";
import {
  DEX_PAIR_ABI,
  ERC20_ABI,
  PAIR_ADDRESS,
  TOKEN_A_ADDRESS,
  TOKEN_B_ADDRESS,
} from "../config";
import { shareBps } from "../lib/amm";

// Per-token reads (balance/allowance are polled lightly so numbers survive
// transfers made outside this app, e.g. with cast).
function useTokenReads(tokenAddress, { address, enabled }) {
  const symbol = useReadContract({
    address: tokenAddress,
    abi: ERC20_ABI,
    functionName: "symbol",
    query: { enabled },
  });
  const decimals = useReadContract({
    address: tokenAddress,
    abi: ERC20_ABI,
    functionName: "decimals",
    query: { enabled },
  });
  const balance = useReadContract({
    address: tokenAddress,
    abi: ERC20_ABI,
    functionName: "balanceOf",
    args: [address],
    query: { enabled, refetchInterval: 10000 },
  });
  const allowance = useReadContract({
    address: tokenAddress,
    abi: ERC20_ABI,
    functionName: "allowance",
    args: [address, PAIR_ADDRESS],
    query: { enabled, refetchInterval: 10000 },
  });
  return {
    address: tokenAddress,
    symbol: symbol.data,
    decimals: decimals.data,
    balance: balance.data,
    allowance: allowance.data,
    // Raw query results, kept for loading/error aggregation by the caller.
    queries: [symbol, decimals, balance, allowance],
  };
}

// Every piece of chain state both panels show, via useReadContract.
//
// The pair sorts its two tokens into token0/token1 by address (devlog 5 Okt:
// "tokenA bisa jadi token1"), so the canonical order is read from the pair and
// the configured TokenA/TokenB labels are matched onto it by address. All swap
// and liquidity math below uses this canonical order exclusively.
export function usePairReads({ address, enabled }) {
  const token0Raw = useReadContract({
    address: PAIR_ADDRESS,
    abi: DEX_PAIR_ABI,
    functionName: "token0",
    query: { enabled },
  });
  const token1Raw = useReadContract({
    address: PAIR_ADDRESS,
    abi: DEX_PAIR_ABI,
    functionName: "token1",
    query: { enabled },
  });
  const reserves = useReadContract({
    address: PAIR_ADDRESS,
    abi: DEX_PAIR_ABI,
    functionName: "getReserves",
    query: { enabled, refetchInterval: 5000 },
  });
  const lpTotalSupply = useReadContract({
    address: PAIR_ADDRESS,
    abi: DEX_PAIR_ABI,
    functionName: "totalSupply",
    query: { enabled, refetchInterval: 5000 },
  });
  const lpBalance = useReadContract({
    address: PAIR_ADDRESS,
    abi: DEX_PAIR_ABI,
    functionName: "balanceOf",
    args: [address],
    query: { enabled, refetchInterval: 10000 },
  });

  const tokenA = useTokenReads(TOKEN_A_ADDRESS, { address, enabled });
  const tokenB = useTokenReads(TOKEN_B_ADDRESS, { address, enabled });

  // Map the canonical token0 address onto the configured deploy labels.
  const zeroIsA = useMemo(() => {
    const raw = token0Raw.data;
    if (!raw || !TOKEN_A_ADDRESS) return null;
    try {
      return getAddress(raw) === getAddress(TOKEN_A_ADDRESS);
    } catch {
      return null;
    }
  }, [token0Raw.data]);

  const reserve0 = reserves.data?.[0];
  const reserve1 = reserves.data?.[1];
  const share = shareBps(lpBalance.data, lpTotalSupply.data);

  const allReads = [
    token0Raw, token1Raw, reserves, lpTotalSupply, lpBalance,
    ...tokenA.queries, ...tokenB.queries,
  ];

  return {
    // Canonical sides: null while token0/token1 are still loading.
    token0: zeroIsA === null ? null : zeroIsA ? tokenA : tokenB,
    token1: zeroIsA === null ? null : zeroIsA ? tokenB : tokenA,
    tokenA,
    tokenB,
    reserve0,
    reserve1,
    lpTotalSupply: lpTotalSupply.data,
    lpBalance: lpBalance.data,
    lpSymbol: "SDX-LP",
    shareBps: share,
    readsLoading: allReads.some((r) => r?.isLoading),
    readsError: allReads.find((r) => r?.isError)?.error ?? null,
  };
}
