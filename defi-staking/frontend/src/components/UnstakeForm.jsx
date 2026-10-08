import { useState } from "react";
import { formatExact, validateAmount } from "../lib/format";

export function UnstakeForm({ reads, busy, actions }) {
  const { stakedBalance, tokenDecimals, tokenSymbol } = reads;
  const [amount, setAmount] = useState("");

  const validation = validateAmount(amount, {
    max: stakedBalance,
    maxLabel: `your staked balance`,
    decimals: tokenDecimals,
  });

  const dataReady = stakedBalance !== undefined && tokenDecimals !== undefined;
  const canSubmit = validation.value !== null && dataReady && !busy;

  const onSubmit = (event) => {
    event.preventDefault();
    if (!canSubmit) return;
    actions.unstake(validation.value, { onSuccess: () => setAmount("") });
  };

  return (
    <form className="card form" onSubmit={onSubmit}>
      <h2>Unstake</h2>
      <p className="form-hint">
        Return {tokenSymbol ?? "tokens"} from the pool to your wallet. Unclaimed rewards stay in the
        pool and remain claimable separately.
      </p>

      <div className="field">
        <div className="field-label-row">
          <label htmlFor="unstake-amount">Amount ({tokenSymbol ?? "tokens"})</label>
          <button
            type="button"
            className="btn-ghost"
            onClick={() => setAmount(formatExact(stakedBalance, tokenDecimals))}
            disabled={busy || !stakedBalance}
          >
            Max
          </button>
        </div>
        <input
          id="unstake-amount"
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

      <button type="submit" className="btn btn-secondary" disabled={!canSubmit}>
        {busy && actions.activePhase === "unstake" ? "Unstaking..." : "Unstake"}
      </button>
    </form>
  );
}
