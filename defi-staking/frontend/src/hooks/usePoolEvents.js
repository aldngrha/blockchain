import { useEffect } from "react";
import { useQueryClient } from "@tanstack/react-query";
import { watchContractEvent } from "wagmi/actions";
import { POOL_ADDRESS, wagmiConfig } from "../config";
import { STAKING_POOL_ABI } from "../abi";

const POOL_EVENTS = ["Staked", "Unstaked", "RewardPaid", "EmergencyWithdraw", "RewardRateSet"];

// Real-time updates: watch pool events on the connected chain and invalidate
// every query when one shows up, so TanStack Query refetches the affected
// reads. Any state change in the pool emits one of these events, so a broad
// invalidation is correct and cheap (a handful of view calls).
export function usePoolEvents({ chainId, enabled }) {
  const queryClient = useQueryClient();

  useEffect(() => {
    if (!enabled || !POOL_ADDRESS || chainId === undefined) return undefined;

    const unwatch = POOL_EVENTS.map((eventName) =>
      watchContractEvent(wagmiConfig, {
        address: POOL_ADDRESS,
        abi: STAKING_POOL_ABI,
        eventName,
        chainId,
        onLogs: () => queryClient.invalidateQueries(),
      }),
    );

    return () => unwatch.forEach((stop) => stop());
  }, [enabled, chainId, queryClient]);
}
