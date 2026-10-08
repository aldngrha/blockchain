import { useEffect } from "react";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { getAbiItem } from "viem";
import { usePublicClient } from "wagmi";
import { watchContractEvent } from "wagmi/actions";
import { GOVERNOR_ABI, GOVERNOR_ADDRESS, wagmiConfig } from "../config";
import {
  listCachedProposals,
  loadProposalCache,
  proposalMetaFromEvent,
  storeScanResults,
} from "../lib/proposalStore";

// viem 2.x getLogs takes the ABI ITEM (`event`), not abi+eventName: passing
// abi+eventName is silently ignored and returns every log in the range. The
// eventName sugar only exists on wagmi's watchContractEvent.
const PROPOSAL_CREATED_EVENT = getAbiItem({ abi: GOVERNOR_ABI, name: "ProposalCreated" });

// Reorg safety margin: when resuming an incremental scan, re-read the last few
// blocks again in case a recent reorg moved events around. Cheap on a tiny
// window, and it keeps lastScannedBlock monotonic.
const RESCAN_MARGIN_BLOCKS = 20;
// Full scans (first visit) are repeated only if the incremental scan fails.
const SCAN_REFETCH_MS = 15000;

// The proposal list. OZ Governor has no on-chain proposal registry: the only
// way to discover proposals is scanning ProposalCreated event logs (or asking
// an indexer, which is what the subgraph task is for). This hook
//   1. renders immediately from the localStorage cache (initialData),
//   2. scans logs incrementally from lastScannedBlock (+ reorg margin),
//   3. merges results back into the cache and returns them sorted newest first.
export function useProposals({ chainId, enabled }) {
  const client = usePublicClient({ chainId });
  const queryClient = useQueryClient();

  const query = useQuery({
    queryKey: ["proposals", chainId, GOVERNOR_ADDRESS],
    enabled: enabled && Boolean(client && GOVERNOR_ADDRESS),
    refetchInterval: SCAN_REFETCH_MS,
    retry: 1,
    // Render what the cache already has while the scan is in flight.
    initialData: () => ({
      metas: listCachedProposals(chainId, GOVERNOR_ADDRESS),
      scannedFrom: null,
      scannedTo: null,
      foundInRange: null,
      total: null,
    }),
    queryFn: async () => {
      const cache = loadProposalCache(chainId, GOVERNOR_ADDRESS);
      const currentBlock = Number(await client.getBlockNumber());
      // Resume shortly before the last scanned block; from 0 on first visit.
      const fromBlock = Math.max(0, cache.lastScannedBlock - RESCAN_MARGIN_BLOCKS);
      const found = await client.getLogs({
        address: GOVERNOR_ADDRESS,
        event: PROPOSAL_CREATED_EVENT,
        fromBlock: BigInt(fromBlock),
        toBlock: BigInt(currentBlock),
      });
      const metas = found.map((log) => proposalMetaFromEvent(log));
      const { total } = storeScanResults(chainId, GOVERNOR_ADDRESS, metas, currentBlock);
      return {
        metas: listCachedProposals(chainId, GOVERNOR_ADDRESS),
        scannedFrom: fromBlock,
        scannedTo: currentBlock,
        foundInRange: metas.length,
        total,
      };
    },
  });

  // Live updates: any governance activity invalidates every query (all reads
  // are cheap view calls), so the list, badges, and vote counts stay current
  // without waiting for the polling interval.
  useEffect(() => {
    if (!enabled || !GOVERNOR_ADDRESS || chainId === undefined) return undefined;
    const events = [
      "ProposalCreated",
      "VoteCast",
      "ProposalQueued",
      "ProposalExecuted",
      "ProposalCanceled",
    ];
    const unwatch = events.map((eventName) =>
      watchContractEvent(wagmiConfig, {
        address: GOVERNOR_ADDRESS,
        abi: GOVERNOR_ABI,
        eventName,
        chainId,
        onLogs: () => queryClient.invalidateQueries(),
      }),
    );
    return () => unwatch.forEach((stop) => stop());
  }, [enabled, chainId, queryClient]);

  return {
    metas: query.data?.metas ?? [],
    scanStatus: query.status, // 'pending' while the (first) scan runs
    scanError: query.isError ? query.error : null,
    refetchScan: query.refetch,
    scanResult: query.data ?? null,
  };
}
