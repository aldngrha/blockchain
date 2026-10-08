import { useCallback, useState } from "react";
import { useAccount, usePublicClient, useWriteContract } from "wagmi";
import { useQueryClient } from "@tanstack/react-query";
import { encodeFunctionData, keccak256, parseEventLogs, toBytes } from "viem";
import {
  GOVERNANCE_TOKEN_ABI,
  GOVERNOR_ABI,
  GOVERNOR_ADDRESS,
  TOKEN_ADDRESS,
  TREASURY_ABI,
  TREASURY_ADDRESS,
} from "../config";
import { parseTxError } from "../lib/errors";
import { proposalMetaFromEvent, storeCreatedProposal } from "../lib/proposalStore";

// Sequential transaction runner built on writeContractAsync: await the wallet,
// then await the receipt, then move to the next step. Every governance flow is
// a single transaction here, but the runner keeps wallet/block phases, error
// parsing, and cache invalidation in one place (same pattern as defi-staking).
export function useGovernanceActions({ chainId }) {
  const { address } = useAccount();
  const publicClient = usePublicClient({ chainId });
  const { writeContractAsync } = useWriteContract();
  const queryClient = useQueryClient();

  const [activePhase, setActivePhase] = useState(null); // 'vote' | 'queue' | ...
  const [awaiting, setAwaiting] = useState(null); // 'wallet' | 'block'
  const [error, setError] = useState(null);
  const [lastResult, setLastResult] = useState(null);

  const busy = activePhase !== null;

  const dismissError = useCallback(() => setError(null), []);
  const dismissResult = useCallback(() => setLastResult(null), []);

  const run = useCallback(
    async (steps, resultKind, onSuccess) => {
      if (!address || !publicClient) return;
      setError(null);
      setLastResult(null);
      try {
        let receipt = null;
        for (const step of steps) {
          setActivePhase(step.phase);
          setAwaiting("wallet");
          const hash = await writeContractAsync(step.call);
          setAwaiting("block");
          receipt = await publicClient.waitForTransactionReceipt({ hash });
          if (receipt.status !== "success") {
            throw new Error("The transaction was included in a block but reverted on chain.");
          }
          step.onReceipt?.(receipt);
        }
        setLastResult({ kind: resultKind });
        await queryClient.invalidateQueries();
        onSuccess?.(receipt);
      } catch (e) {
        setError(parseTxError(e));
      } finally {
        setActivePhase(null);
        setAwaiting(null);
      }
    },
    [address, publicClient, writeContractAsync, queryClient],
  );

  // support: 0 Against / 1 For / 2 Abstain (GovernorCountingSimple ordering).
  const vote = useCallback(
    (proposalId, support, reason = "") =>
      run(
        [
          {
            phase: "vote",
            call: {
              address: GOVERNOR_ADDRESS,
              abi: GOVERNOR_ABI,
              functionName: "castVoteWithReason",
              args: [BigInt(proposalId), support, reason],
            },
          },
        ],
        "vote",
      ),
    [run],
  );

  // queue/execute/cancel need the full proposal payload (targets, values,
  // calldatas, description hash) because the governor derives the proposal id
  // from it. The payload lives in the scanned ProposalCreated metadata.
  function proposalPayload(meta) {
    return {
      targets: meta.targets,
      values: meta.values.map((v) => BigInt(v)),
      calldatas: meta.calldatas,
      descriptionHash: keccak256(toBytes(meta.description)),
    };
  }

  const queue = useCallback(
    (meta) => {
      const payload = proposalPayload(meta);
      return run(
        [
          {
            phase: "queue",
            call: {
              address: GOVERNOR_ADDRESS,
              abi: GOVERNOR_ABI,
              functionName: "queue",
              args: [payload.targets, payload.values, payload.calldatas, payload.descriptionHash],
            },
          },
        ],
        "queue",
      );
    },
    [run],
  );

  const execute = useCallback(
    (meta) => {
      const payload = proposalPayload(meta);
      return run(
        [
          {
            phase: "execute",
            call: {
              address: GOVERNOR_ADDRESS,
              abi: GOVERNOR_ABI,
              functionName: "execute",
              args: [payload.targets, payload.values, payload.calldatas, payload.descriptionHash],
            },
          },
        ],
        "execute",
      );
    },
    [run],
  );

  const cancel = useCallback(
    (meta) => {
      const payload = proposalPayload(meta);
      return run(
        [
          {
            phase: "cancel",
            call: {
              address: GOVERNOR_ADDRESS,
              abi: GOVERNOR_ABI,
              functionName: "cancel",
              args: [payload.targets, payload.values, payload.calldatas, payload.descriptionHash],
            },
          },
        ],
        "cancel",
      );
    },
    [run],
  );

  const delegate = useCallback(
    (delegatee, onSuccess) =>
      run(
        [
          {
            phase: "delegate",
            call: {
              address: TOKEN_ADDRESS,
              abi: GOVERNANCE_TOKEN_ABI,
              functionName: "delegate",
              args: [delegatee],
            },
          },
        ],
        "delegate",
        onSuccess,
      ),
    [run],
  );

  // Create a payout proposal: Treasury.execute(recipient, amountWei) called by
  // the timelock, wrapped in a governor propose(). After the receipt, parse
  // the ProposalCreated event (the event carries the computed proposal id),
  // store the metadata so the list can render the description immediately,
  // and hand the id to the caller for navigation.
  const proposePayout = useCallback(
    ({ recipient, amountWei, description }, onSuccess) =>
      run(
        [
          {
            phase: "propose",
            call: {
              address: GOVERNOR_ADDRESS,
              abi: GOVERNOR_ABI,
              functionName: "propose",
              args: [
                [TREASURY_ADDRESS],
                [0n],
                [
                  // The payload the timelock will execute once the proposal
                  // passes: a plain Treasury.execute(recipient, amount) call.
                  encodeFunctionData({
                    abi: TREASURY_ABI,
                    functionName: "execute",
                    args: [recipient, amountWei],
                  }),
                ],
                description,
              ],
            },
            onReceipt: (receipt) => {
              const events = parseEventLogs({
                abi: GOVERNOR_ABI,
                logs: receipt.logs,
                eventName: "ProposalCreated",
              });
              const created = events[events.length - 1];
              if (created) {
                storeCreatedProposal(chainId, GOVERNOR_ADDRESS, {
                  ...proposalMetaFromEvent({ args: created.args, blockNumber: receipt.blockNumber }),
                  proposer: address,
                });
              }
            },
          },
        ],
        "propose",
        (receipt) => {
          const events = parseEventLogs({
            abi: GOVERNOR_ABI,
            logs: receipt.logs,
            eventName: "ProposalCreated",
          });
          const created = events[events.length - 1];
          onSuccess?.(created?.args?.proposalId);
        },
      ),
    [run, chainId, address],
  );

  return {
    vote,
    queue,
    execute,
    cancel,
    delegate,
    proposePayout,
    activePhase,
    awaiting,
    busy,
    error,
    lastResult,
    dismissError,
    dismissResult,
  };
}
