import { useReadContract } from "wagmi";
import { POOL_ADDRESS, STAKING_POOL_ABI, TOKEN_ADDRESS, REWARD_TOKEN_ABI } from "../config";

// Every piece of chain state the dashboard shows, via useReadContract.
//
// earned/ staked/ TVL are also lightly polled (seconds, not milliseconds):
// rewards accrue every second on chain, and event watching only fires on
// transactions, so a quiet account would otherwise show stale numbers.
export function usePoolReads({ address, enabled }) {
  const staked = useReadContract({
    address: POOL_ADDRESS,
    abi: STAKING_POOL_ABI,
    functionName: "getStakedBalance",
    args: [address],
    query: { enabled, refetchInterval: 5000 },
  });

  const earned = useReadContract({
    address: POOL_ADDRESS,
    abi: STAKING_POOL_ABI,
    functionName: "earned",
    args: [address],
    query: { enabled, refetchInterval: 3000 },
  });

  const totalStaked = useReadContract({
    address: POOL_ADDRESS,
    abi: STAKING_POOL_ABI,
    functionName: "getTotalStaked",
    query: { enabled, refetchInterval: 5000 },
  });

  const rewardRate = useReadContract({
    address: POOL_ADDRESS,
    abi: STAKING_POOL_ABI,
    functionName: "rewardRate",
    query: { enabled },
  });

  const symbol = useReadContract({
    address: TOKEN_ADDRESS,
    abi: REWARD_TOKEN_ABI,
    functionName: "symbol",
    query: { enabled },
  });

  const decimals = useReadContract({
    address: TOKEN_ADDRESS,
    abi: REWARD_TOKEN_ABI,
    functionName: "decimals",
    query: { enabled },
  });

  const balance = useReadContract({
    address: TOKEN_ADDRESS,
    abi: REWARD_TOKEN_ABI,
    functionName: "balanceOf",
    args: [address],
    query: { enabled, refetchInterval: 10000 },
  });

  const allowance = useReadContract({
    address: TOKEN_ADDRESS,
    abi: REWARD_TOKEN_ABI,
    functionName: "allowance",
    args: [address, POOL_ADDRESS],
    query: { enabled, refetchInterval: 10000 },
  });

  const reads = [staked, earned, totalStaked, rewardRate, symbol, decimals, balance, allowance];

  return {
    stakedBalance: staked.data,
    earned: earned.data,
    totalStaked: totalStaked.data,
    rewardRate: rewardRate.data,
    tokenSymbol: symbol.data,
    tokenDecimals: decimals.data,
    tokenBalance: balance.data,
    allowance: allowance.data,
    readsLoading: reads.some((r) => r.isLoading),
    readsError: reads.find((r) => r.isError)?.error ?? null,
  };
}
