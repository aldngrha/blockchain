import { useQuery } from "@tanstack/react-query";
import { usePublicClient } from "wagmi";

// Sample two blocks to estimate the chain's average block time, then convert
// any target block number into an estimated wall-clock date. Vote windows are
// measured in blocks, so a proposal "deadline" is a block number: the date is
// always an estimate and the UI labels it as one.
const SAMPLE_SPAN = 1000n;

export function useBlockTime({ chainId, enabled }) {
  const client = usePublicClient({ chainId });

  const query = useQuery({
    queryKey: ["block-time", chainId],
    enabled: enabled && Boolean(client),
    staleTime: 20000,
    refetchInterval: 30000,
    queryFn: async () => {
      const blockNumber = await client.getBlockNumber();
      const latest = await client.getBlock({ blockNumber });
      const olderNumber = blockNumber > SAMPLE_SPAN ? blockNumber - SAMPLE_SPAN : 0n;
      const older = olderNumber === blockNumber ? latest : await client.getBlock({ blockNumber: olderNumber });
      const blockDiff = Number(blockNumber - olderNumber);
      const avgSeconds = blockDiff > 0 ? Number(latest.timestamp - older.timestamp) / blockDiff : 0;
      return { blockNumber: Number(blockNumber), avgSeconds };
    },
  });

  const blockNumber = query.data?.blockNumber;
  const avgSeconds = query.data?.avgSeconds;

  // Pure estimate from the sampled average. Past blocks get the same math:
  // honest enough for a dashboard, and always shown with an "est." label.
  function estimateBlockDate(targetBlock) {
    if (blockNumber === undefined || avgSeconds === undefined || avgSeconds <= 0) return null;
    if (typeof targetBlock !== "number" || Number.isNaN(targetBlock)) return null;
    const deltaBlocks = targetBlock - blockNumber;
    return new Date(Date.now() + deltaBlocks * avgSeconds * 1000);
  }

  return {
    blockNumber,
    avgSeconds,
    estimateBlockDate,
    blockTimeLoading: query.isPending,
    blockTimeError: query.isError ? query.error : null,
  };
}
