import { useQuery } from "@tanstack/react-query";
import { getAbiItem } from "viem";
import { useBlockNumber, usePublicClient, useReadContract } from "wagmi";
import { GOVERNANCE_TOKEN_ABI, GOVERNOR_ABI, GOVERNOR_ADDRESS, SUPPORTED_CHAIN_IDS, TOKEN_ADDRESS } from "../config";

// Same viem rule as the proposal scan: getLogs wants the ABI item, not
// abi+eventName (which it silently ignores and returns everything).
const VOTE_CAST_EVENT = getAbiItem({ abi: GOVERNOR_ABI, name: "VoteCast" });

// Everything the proposal detail page shows, in one hook: on-chain proposal
// state, the user's position for THIS proposal, and helpers for the vote UI.
//
// The voting power that counts is read from token.getPastVotes(user, snapshot),
// NOT token.getVotes(user): ERC20Votes keeps checkpoints, and the governor
// counts the balance as of the snapshot block (GovernorVotes._getVotes calls
// getPastVotes(account, timepoint) with no offset, verified in OZ 5.4.0).
// Delegating after the snapshot does not change it.
export function useProposalDetail({ chainId, address, proposalId, enabled }) {
  const readChain = SUPPORTED_CHAIN_IDS.includes(chainId) ? chainId : undefined;

  const id = (() => {
    try {
      return BigInt(proposalId);
    } catch {
      return null;
    }
  })();

  const state = useReadContract({
    address: GOVERNOR_ADDRESS,
    abi: GOVERNOR_ABI,
    functionName: "state",
    args: [id],
    chainId: readChain,
    query: { enabled: enabled && id !== null, refetchInterval: 5000 },
  });

  const snapshot = useReadContract({
    address: GOVERNOR_ADDRESS,
    abi: GOVERNOR_ABI,
    functionName: "proposalSnapshot",
    args: [id],
    chainId: readChain,
    query: { enabled: enabled && id !== null },
  });

  const deadline = useReadContract({
    address: GOVERNOR_ADDRESS,
    abi: GOVERNOR_ABI,
    functionName: "proposalDeadline",
    args: [id],
    chainId: readChain,
    query: { enabled: enabled && id !== null },
  });

  // Only meaningful once queued; zero otherwise.
  const eta = useReadContract({
    address: GOVERNOR_ADDRESS,
    abi: GOVERNOR_ABI,
    functionName: "proposalEta",
    args: [id],
    chainId: readChain,
    query: { enabled: enabled && id !== null },
  });

  const votes = useReadContract({
    address: GOVERNOR_ADDRESS,
    abi: GOVERNOR_ABI,
    functionName: "proposalVotes",
    args: [id],
    chainId: readChain,
    query: { enabled: enabled && id !== null, refetchInterval: 5000 },
  });

  const hasVoted = useReadContract({
    address: GOVERNOR_ADDRESS,
    abi: GOVERNOR_ABI,
    functionName: "hasVoted",
    args: [id, address],
    chainId: readChain,
    query: { enabled: enabled && id !== null && Boolean(address) },
  });

  // The current block number gates the snapshot reads: getPastVotes and
  // quorum revert with ERC5805FutureLookup while the snapshot lies in the
  // future (proposal still Pending), so both wait until snapshot < head.
  const blockNumber = useBlockNumber({ chainId: readChain, query: { enabled: enabled && id !== null } });
  const snapshotNumber = snapshot.data !== undefined ? Number(snapshot.data) : undefined;
  const headNumber = blockNumber.data !== undefined ? Number(blockNumber.data) : undefined;
  const snapshotReached =
    snapshotNumber !== undefined && headNumber !== undefined && snapshotNumber < headNumber;

  const quorum = useReadContract({
    address: GOVERNOR_ADDRESS,
    abi: GOVERNOR_ABI,
    functionName: "quorum",
    args: [snapshot.data],
    chainId: readChain,
    query: {
      enabled: enabled && id !== null && snapshotReached,
      refetchInterval: 10000,
    },
  });

  const pastVotes = useReadContract({
    address: TOKEN_ADDRESS,
    abi: GOVERNANCE_TOKEN_ABI,
    functionName: "getPastVotes",
    args: [address, snapshot.data],
    chainId: readChain,
    query: {
      enabled: enabled && id !== null && Boolean(address) && snapshotReached,
      refetchInterval: 10000,
    },
  });

  return {
    state: state.data,
    snapshotBlock: snapshotNumber,
    deadlineBlock: deadline.data !== undefined ? Number(deadline.data) : undefined,
    etaSeconds: eta.data !== undefined ? Number(eta.data) : undefined,
    votes: votes.data,
    hasVoted: hasVoted.data,
    quorum: quorum.data,
    votingPowerAtSnapshot: pastVotes.data,
    snapshotReached,
    headBlock: headNumber,
    loading: state.isLoading || snapshot.isLoading || deadline.isLoading || votes.isLoading,
    error: [state, snapshot, deadline, votes, quorum, pastVotes].find((r) => r.isError)?.error ?? null,
  };
}

// VoteCast history for one proposal, straight from logs. OZ has no vote
// registry view call either, so the same event-scan trade-off as the proposal
// list applies (the subgraph replaces this).
export function useProposalVoteHistory({ chainId, proposalId, enabled }) {
  const client = usePublicClient({ chainId });

  const query = useQuery({
    queryKey: ["vote-history", chainId, GOVERNOR_ADDRESS, proposalId],
    enabled: enabled && Boolean(client && GOVERNOR_ADDRESS && proposalId),
    refetchInterval: 8000,
    retry: 1,
    queryFn: async () => {
      const logs = await client.getLogs({
        address: GOVERNOR_ADDRESS,
        event: VOTE_CAST_EVENT,
        args: { proposalId: BigInt(proposalId) },
        fromBlock: 0n,
        toBlock: "latest",
      });
      return logs.map((log) => ({
        voter: log.args.voter,
        support: log.args.support,
        weight: log.args.weight,
        reason: log.args.reason ?? "",
        transactionHash: log.transactionHash,
        blockNumber: Number(log.blockNumber),
      }));
    },
  });

  return {
    votes: query.data,
    loading: query.isPending && enabled,
    error: query.isError ? query.error : null,
  };
}
