import { useState } from "react";
import { isAddress } from "viem";
import { formatToken } from "../lib/format";

const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";

export function DelegateForm({ address, reads, busy, actions }) {
  const { symbol, tokenBalance, currentVotes, delegatee } = reads;
  const [delegateTo, setDelegateTo] = useState("");

  const target = delegateTo.trim() === "" ? address : delegateTo.trim();
  const validTarget = isAddress(target ?? "", { strict: false }) && target !== ZERO_ADDRESS;

  const alreadyDelegatedTo = delegatee !== undefined && delegatee.toLowerCase() === target?.toLowerCase();
  // Delegate is idempotent on chain but pointless to repeat: gate it on a
  // real change so the button never fires a no-op transaction.
  const canSubmit = validTarget && !busy && !alreadyDelegatedTo;

  const onSubmit = (event) => {
    event.preventDefault();
    if (!canSubmit) return;
    actions.delegate(target, () => setDelegateTo(""));
  };

  return (
    <form className="card form" onSubmit={onSubmit} aria-labelledby="delegate-title">
      <h2 id="delegate-title">Delegate voting power</h2>
      <p className="form-hint">
        GT balance is not voting power. Votes only count after delegate() creates a checkpoint, and
        they apply to proposals created from that block onward. Delegating to yourself is the
        normal case.
      </p>

      <div className="position-grid">
        <div className="position-item">
          <span className="stat-label">Your balance</span>
          <span className="stat-small">
            {tokenBalance === undefined ? "-" : `${formatToken(tokenBalance)} ${symbol ?? "GT"}`}
          </span>
        </div>
        <div className="position-item">
          <span className="stat-label">Voting power now (delegated to you)</span>
          <span className="stat-small">
            {currentVotes === undefined ? "-" : `${formatToken(currentVotes)} ${symbol ?? "GT"}`}
          </span>
        </div>
        <div className="position-item">
          <span className="stat-label">You delegate to</span>
          <span className="stat-small">
            {delegatee === undefined
              ? "-"
              : delegatee === ZERO_ADDRESS
                ? "nobody (not delegated)"
                : delegatee.toLowerCase() === address?.toLowerCase()
                  ? "yourself"
                  : <code>{delegatee}</code>}
          </span>
        </div>
      </div>

      <div className="field">
        <div className="field-label-row">
          <label htmlFor="delegate-address">Delegate to</label>
          <button
            type="button"
            className="btn-ghost"
            onClick={() => setDelegateTo(address ?? "")}
            disabled={busy || !address}
          >
            Self
          </button>
        </div>
        <input
          id="delegate-address"
          className="input"
          type="text"
          autoComplete="off"
          spellCheck="false"
          placeholder={address ?? "0x..."}
          value={delegateTo}
          onChange={(event) => setDelegateTo(event.target.value)}
          disabled={busy}
          aria-invalid={delegateTo.trim() !== "" && !validTarget}
        />
        {delegateTo.trim() !== "" && !validTarget ? (
          <p className="field-error" role="alert">
            Enter a valid address (not the zero address).
          </p>
        ) : null}
        {delegateTo.trim() === "" ? (
          <p className="stat-hint">Empty means yourself ({address ? <code>{address}</code> : "connect a wallet"}).</p>
        ) : null}
      </div>

      <button type="submit" className="btn btn-primary" disabled={!canSubmit}>
        {busy && actions.activePhase === "delegate" ? "Delegating..." : alreadyDelegatedTo ? "Already delegated here" : "Delegate"}
      </button>

      {alreadyDelegatedTo ? (
        <p className="stat-hint">
          Your delegation already points at this address. New token transfers re-checkpoint
          automatically, so delegate again only after receiving more GT.
        </p>
      ) : null}
    </form>
  );
}
