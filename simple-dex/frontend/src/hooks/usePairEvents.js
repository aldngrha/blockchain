import { useEffect } from "react";
import { useQueryClient } from "@tanstack/react-query";
import { watchContractEvent } from "wagmi/actions";
import { DEX_PAIR_ABI, PAIR_ADDRESS, wagmiConfig } from "../config";

const PAIR_EVENTS = ["Mint", "Burn", "Swap", "Sync"];

// Real-time updates: watch pair events on the connected chain and invalidate
// every query when one shows up, so TanStack Query refetches the affected
// reads. Every state change in the pair emits Sync (and one of Mint/Burn/Swap),
// so a broad invalidation is correct and cheap (a handful of view calls).
//
// wagmi/viem 2.5x note: getLogs silently ignores abi + eventName combinations
// that are not exact event ABI items, so events go through watchContractEvent
// with an explicit eventName per call (the pattern proven in defi-staking).
export function usePairEvents({ chainId, enabled }) {
  const queryClient = useQueryClient();

  useEffect(() => {
    if (!enabled || !PAIR_ADDRESS || chainId === undefined) return undefined;

    const unwatch = PAIR_EVENTS.map((eventName) =>
      watchContractEvent(wagmiConfig, {
        address: PAIR_ADDRESS,
        abi: DEX_PAIR_ABI,
        eventName,
        chainId,
        onLogs: () => queryClient.invalidateQueries(),
      }),
    );

    return () => unwatch.forEach((stop) => stop());
  }, [enabled, chainId, queryClient]);
}
