import { useReadContract, useReadContracts } from "wagmi";
import {
  GOVERNANCE_TOKEN_ABI,
  GOVERNOR_ABI,
  GOVERNOR_ADDRESS,
  SUPPORTED_CHAIN_IDS,
  TOKEN_ADDRESS,
  TREASURY_ABI,
  TREASURY_ADDRESS,
} from "../config";
import { listCachedProposals } from "../lib/proposalStore";

// Reads shared by every page: treasury balance, token identity, and the
// connected user's token position. `chainId` is passed explicitly so reads go
// to the wallet's chain (the caller only renders this when it is supported).
export function useGovernanceReads({ chainId, address, enabled }) {
  const readChain = SUPPORTED_CHAIN_IDS.includes(chainId) ? chainId : undefined;

  const treasuryBalance = useReadContract({
    address: TREASURY_ADDRESS,
    abi: TREASURY_ABI,
    functionName: "getBalance",
    chainId: readChain,
    query: { enabled: enabled && Boolean(TREASURY_ADDRESS), refetchInterval: 10000 },
  });

  const symbol = useReadContract({
    address: TOKEN_ADDRESS,
    abi: GOVERNANCE_TOKEN_ABI,
    functionName: "symbol",
    chainId: readChain,
    query: { enabled: enabled && Boolean(TOKEN_ADDRESS) },
  });

  const tokenBalance = useReadContract({
    address: TOKEN_ADDRESS,
    abi: GOVERNANCE_TOKEN_ABI,
    functionName: "balanceOf",
    args: [address],
    chainId: readChain,
    query: { enabled: enabled && Boolean(address && TOKEN_ADDRESS), refetchInterval: 10000 },
  });

  // Voting power delegated to this account RIGHT NOW. This is not the number
  // that counts on a running proposal: that one is fixed at the snapshot
  // (see useProposalDetail).
  const currentVotes = useReadContract({
    address: TOKEN_ADDRESS,
    abi: GOVERNANCE_TOKEN_ABI,
    functionName: "getVotes",
    args: [address],
    chainId: readChain,
    query: { enabled: enabled && Boolean(address && TOKEN_ADDRESS), refetchInterval: 10000 },
  });

  // Who the user delegated to (zero address = never delegated).
  const delegatee = useReadContract({
    address: TOKEN_ADDRESS,
    abi: GOVERNANCE_TOKEN_ABI,
    functionName: "delegates",
    args: [address],
    chainId: readChain,
    query: { enabled: enabled && Boolean(address && TOKEN_ADDRESS) },
  });

  const reads = [treasuryBalance, symbol, tokenBalance, currentVotes, delegatee];

  return {
    treasuryBalance: treasuryBalance.data,
    symbol: symbol.data,
    tokenBalance: tokenBalance.data,
    currentVotes: currentVotes.data,
    delegatee: delegatee.data,
    readsError: reads.find((r) => r.isError)?.error ?? null,
  };
}

// Per-proposal live values for the list: state, vote tally, and the quorum
// requirement measured at each proposal's snapshot. Batched through one
// multicall so the list costs three calls per proposal, not three requests.
// quorum(snapshot) reverts for Pending proposals (future lookup on
// getPastTotalSupply), so those entries come back as errors and render as
// "not measurable yet" instead of a number.
export function useProposalLiveStates({ chainId, metas, enabled }) {
  const readChain = SUPPORTED_CHAIN_IDS.includes(chainId) ? chainId : undefined;

  const contracts = [];
  for (const meta of metas) {
    const id = BigInt(meta.proposalId);
    contracts.push(
      { address: GOVERNOR_ADDRESS, abi: GOVERNOR_ABI, functionName: "state", args: [id], chainId: readChain },
      { address: GOVERNOR_ADDRESS, abi: GOVERNOR_ABI, functionName: "proposalVotes", args: [id], chainId: readChain },
      { address: GOVERNOR_ADDRESS, abi: GOVERNOR_ABI, functionName: "quorum", args: [BigInt(meta.voteStart)], chainId: readChain },
    );
  }

  const results = useReadContracts({
    contracts,
    query: { enabled: enabled && metas.length > 0 && Boolean(GOVERNOR_ADDRESS), refetchInterval: 8000 },
  });

  const live = {};
  for (let i = 0; i < metas.length; i += 1) {
    const [stateRes, votesRes, quorumRes] = [
      results.data?.[i * 3],
      results.data?.[i * 3 + 1],
      results.data?.[i * 3 + 2],
    ];
    live[metas[i].proposalId] = {
      state: stateRes?.status === "success" ? stateRes.result : undefined,
      votes: votesRes?.status === "success" ? votesRes.result : undefined,
      quorum: quorumRes?.status === "success" ? quorumRes.result : undefined,
    };
  }

  return {
    live,
    loading: results.isLoading && metas.length > 0,
    error: results.isError ? results.error : null,
  };
}

// Convenience: the cached meta list, newest first.
export function cachedProposalMetas(chainId, governorAddress) {
  return listCachedProposals(chainId, governorAddress);
}
