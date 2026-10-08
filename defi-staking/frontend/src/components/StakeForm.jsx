import { useState } from "react";
import { formatExact, validateAmount } from "../lib/format";

export function StakeForm({ reads, busy, actions }) {
  const { tokenBalance, allowance, tokenDecimals, tokenSymbol } = reads;
  const [amount, setAmount] = useState("");

  const validation = validateAmount(amount, {
    max: tokenBalance,
    maxLabel: `your ${tokenSymbol ?? "token"} balance`,
    decimals: tokenDecimals,
  });

  const dataReady =
    tokenBalance !== undefined && allowance !== undefined && tokenDecimals !== undefined;
  const canSubmit = validation.value !== null && dataReady && !busy;

  const needsApproval =
    validation.value !== null && (allowance === undefined || allowance < validation.value);

  const onSubmit = (event) => {
    event.preventDefault();
    if (!canSubmit) return;
    actions.stake(validation.value, allowance, { onSuccess: () => setAmount("") });
  };

  return (
    <form className="card form" onSubmit={onSubmit}>
      <h2>Stake</h2>
      <p className="form-hint">
        Lock {tokenSymbol ?? "tokens"} in the pool to earn rewards every second. If the pool has no
        allowance to spend from your wallet, an approve transaction runs first.
      </p>

      <div className="field">
        <div className="field-label-row">
          <label htmlFor="stake-amount">Amount ({tokenSymbol ?? "tokens"})</label>
          <button
            type="button"
            className="btn-ghost"
            onClick={() => setAmount(formatExact(tokenBalance, tokenDecimals))}
            disabled={busy || tokenBalance === undefined}
          >
            Max
          </button>
        </div>
        <input
          id="stake-amount"
          className="input"
          inputMode="decimal"
          autoComplete="off"
          placeholder="0.0"
          value={amount}
          onChange={(event) => setAmount(event.target.value)}
          disabled={busy || !dataReady}
          aria-invalid={Boolean(amount.trim()) && Boolean(validation.error)}
        />
        {amount.trim() && validation.error ? (
          <p className="field-error" role="alert">
            {validation.error}
          </p>
        ) : null}
      </div>

      <button type="submit" className="btn btn-primary" disabled={!canSubmit}>
        {busy && actions.activePhase === "approve"
          ? "Approving (1/2)..."
          : busy && actions.activePhase === "stake"
            ? "Staking (2/2)..."
            : needsApproval
              ? "Approve, then stake"
              : "Stake"}
      </button>
    </form>
  );
}
