import { useCallback, useState } from "react";
import { useAccount, usePublicClient, useWriteContract } from "wagmi";
import { useQueryClient } from "@tanstack/react-query";
import { POOL_ADDRESS, REWARD_TOKEN_ABI, STAKING_POOL_ABI, TOKEN_ADDRESS } from "../config";
import { parseTxError } from "../lib/errors";

// Sequential transaction runner built on writeContractAsync: await the wallet,
// then await the receipt, then move to the next step. The stake flow can be
// two steps (approve, then stake) and this keeps that ordering explicit
// instead of chaining React effects on transaction hashes.
export function useStakingActions() {
  const { address } = useAccount();
  const publicClient = usePublicClient();
  const { writeContractAsync } = useWriteContract();
  const queryClient = useQueryClient();

  const [activePhase, setActivePhase] = useState(null); // 'approve' | 'stake' | ...
  const [awaiting, setAwaiting] = useState(null); // 'wallet' | 'block'
  const [error, setError] = useState(null);
  const [lastResult, setLastResult] = useState(null);

  const busy = activePhase !== null;

  const dismissError = useCallback(() => setError(null), []);
  const dismissResult = useCallback(() => setLastResult(null), []);

  // onSuccess runs when the whole step chain confirmed, so callers can reset
  // form state from the confirming event instead of from a render effect.
  const run = useCallback(
    async (steps, resultKind, onSuccess) => {
      if (!address || !publicClient) return;
      setError(null);
      setLastResult(null);
      try {
        for (const step of steps) {
          setActivePhase(step.phase);
          setAwaiting("wallet");
          const hash = await writeContractAsync(step.call);
          setAwaiting("block");
          const receipt = await publicClient.waitForTransactionReceipt({ hash });
          if (receipt.status !== "success") {
            throw new Error("The transaction was included in a block but reverted on chain.");
          }
        }
        setLastResult({ kind: resultKind });
        await queryClient.invalidateQueries();
        onSuccess?.();
      } catch (e) {
        setError(parseTxError(e));
      } finally {
        setActivePhase(null);
        setAwaiting(null);
      }
    },
    [address, publicClient, writeContractAsync, queryClient],
  );

  const stake = useCallback(
    (amountWei, allowanceWei, onSuccess) => {
      const steps = [];
      if (allowanceWei === undefined || allowanceWei < amountWei) {
        steps.push({
          phase: "approve",
          call: {
            address: TOKEN_ADDRESS,
            abi: REWARD_TOKEN_ABI,
            functionName: "approve",
            args: [POOL_ADDRESS, amountWei],
          },
        });
      }
      steps.push({
        phase: "stake",
        call: {
          address: POOL_ADDRESS,
          abi: STAKING_POOL_ABI,
          functionName: "stake",
          args: [amountWei],
        },
      });
      return run(steps, "stake", onSuccess);
    },
    [run],
  );

  const unstake = useCallback(
    (amountWei, onSuccess) =>
      run(
        [
          {
            phase: "unstake",
            call: {
              address: POOL_ADDRESS,
              abi: STAKING_POOL_ABI,
              functionName: "unstake",
              args: [amountWei],
            },
          },
        ],
        "unstake",
        onSuccess,
      ),
    [run],
  );

  const claim = useCallback(
    () =>
      run(
        [
          {
            phase: "claim",
            call: { address: POOL_ADDRESS, abi: STAKING_POOL_ABI, functionName: "claimReward" },
          },
        ],
        "claim",
      ),
    [run],
  );

  const emergencyWithdraw = useCallback(
    () =>
      run(
        [
          {
            phase: "emergency",
            call: {
              address: POOL_ADDRESS,
              abi: STAKING_POOL_ABI,
              functionName: "emergencyWithdraw",
            },
          },
        ],
        "emergency",
      ),
    [run],
  );

  return {
    stake,
    unstake,
    claim,
    emergencyWithdraw,
    activePhase,
    awaiting,
    busy,
    error,
    lastResult,
    dismissError,
    dismissResult,
  };
}
