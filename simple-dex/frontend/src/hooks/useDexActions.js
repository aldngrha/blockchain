import { useCallback, useState } from "react";
import { useAccount, usePublicClient, useWriteContract } from "wagmi";
import { useQueryClient } from "@tanstack/react-query";
import { DEX_PAIR_ABI, ERC20_ABI, PAIR_ADDRESS } from "../config";
import { parseTxError } from "../lib/errors";

// Sequential transaction runner built on writeContractAsync: await the wallet,
// then await the receipt, then move to the next step. Every flow here can be
// multiple steps (approve, then action) and this keeps that ordering explicit
// instead of chaining React effects on transaction hashes.
//
// removeLiquidity is the exception on purpose: the pair burns the caller's LP
// directly via _burn, and _burn takes no allowance, so there is no approve
// step for the LP token (verified against src/DexPair.sol).
export function useDexActions() {
  const { address } = useAccount();
  const publicClient = usePublicClient();
  const { writeContractAsync } = useWriteContract();
  const queryClient = useQueryClient();

  const [activeStep, setActiveStep] = useState(null); // { label, index, total }
  const [awaiting, setAwaiting] = useState(null); // 'wallet' | 'block'
  const [error, setError] = useState(null);
  const [lastResult, setLastResult] = useState(null);

  const busy = activeStep !== null;

  const dismissError = useCallback(() => setError(null), []);
  const dismissResult = useCallback(() => setLastResult(null), []);

  const run = useCallback(
    async (steps, resultKind, onSuccess) => {
      if (!address || !publicClient) return;
      setError(null);
      setLastResult(null);
      try {
        for (let i = 0; i < steps.length; i += 1) {
          const step = steps[i];
          setActiveStep({ label: step.label, index: i + 1, total: steps.length });
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
        setActiveStep(null);
        setAwaiting(null);
      }
    },
    [address, publicClient, writeContractAsync, queryClient],
  );

  const approveStep = (label, tokenAddress, amountWei) => ({
    label,
    call: {
      address: tokenAddress,
      abi: ERC20_ABI,
      functionName: "approve",
      args: [PAIR_ADDRESS, amountWei],
    },
  });

  const swap = useCallback(
    ({ amountIn, amountOutMin, deadlineMinutes, zeroForOne, tokenIn, allowanceWei, onSuccess }) => {
      // Deadline is anchored to submission time, so it is computed here in the
      // action layer, not during render.
      const deadline = BigInt(Math.floor(Date.now() / 1000) + deadlineMinutes * 60);
      const needsApprove = allowanceWei === undefined || allowanceWei < amountIn;
      const steps = [];
      if (needsApprove) {
        steps.push(
          approveStep(`Approving ${tokenIn.symbol ?? "token"} (1/2)`, tokenIn.address, amountIn),
        );
      }
      steps.push({
        label: needsApprove ? "Swapping (2/2)" : "Swapping",
        call: {
          address: PAIR_ADDRESS,
          abi: DEX_PAIR_ABI,
          functionName: "swapExactTokensForTokens",
          args: [amountIn, amountOutMin, deadline, zeroForOne],
        },
      });
      return run(steps, "swap", onSuccess);
    },
    [run],
  );

  const addLiquidity = useCallback(
    ({ amount0, amount1, token0, token1, allowance0Wei, allowance1Wei, onSuccess }) => {
      const steps = [];
      let n = 1;
      const total = (allowance0Wei === undefined || allowance0Wei < amount0 ? 1 : 0) +
        (allowance1Wei === undefined || allowance1Wei < amount1 ? 1 : 0) + 1;
      if (allowance0Wei === undefined || allowance0Wei < amount0) {
        steps.push(approveStep(`Approving ${token0.symbol ?? "token0"} (${n}/${total})`, token0.address, amount0));
        n += 1;
      }
      if (allowance1Wei === undefined || allowance1Wei < amount1) {
        steps.push(approveStep(`Approving ${token1.symbol ?? "token1"} (${n}/${total})`, token1.address, amount1));
        n += 1;
      }
      steps.push({
        label: `Adding liquidity (${n}/${total})`,
        call: {
          address: PAIR_ADDRESS,
          abi: DEX_PAIR_ABI,
          functionName: "addLiquidity",
          args: [amount0, amount1],
        },
      });
      return run(steps, "add", onSuccess);
    },
    [run],
  );

  const removeLiquidity = useCallback(
    (lpAmount, { onSuccess } = {}) =>
      run(
        [
          {
            label: "Removing liquidity",
            call: {
              address: PAIR_ADDRESS,
              abi: DEX_PAIR_ABI,
              functionName: "removeLiquidity",
              args: [lpAmount],
            },
          },
        ],
        "remove",
        onSuccess,
      ),
    [run],
  );

  return {
    swap,
    addLiquidity,
    removeLiquidity,
    activeStep,
    awaiting,
    busy,
    error,
    lastResult,
    dismissError,
    dismissResult,
  };
}
