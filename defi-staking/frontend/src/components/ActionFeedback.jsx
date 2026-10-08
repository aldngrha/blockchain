const PHASE_LABELS = {
  approve: "Approve",
  stake: "Stake",
  unstake: "Unstake",
  claim: "Claim",
  emergency: "Emergency withdraw",
};

const RESULT_MESSAGES = {
  stake: "Stake confirmed. Pool numbers refresh as the chain data updates.",
  unstake: "Unstake confirmed. Tokens are back in your wallet.",
  claim: "Claim confirmed. Newly minted reward tokens are in your wallet.",
  emergency: "Emergency withdraw confirmed. Unclaimed rewards were forfeited.",
};

// One place for transaction state: what is running, what failed, what landed.
// aria-live so screen readers announce transitions without a page reload.
export function ActionFeedback({ actions }) {
  const { activePhase, awaiting, error, lastResult, dismissError, dismissResult } = actions;

  if (!activePhase && !error && !lastResult) return null;

  return (
    <section className="feedback" aria-live="polite">
      {activePhase ? (
        <div className="banner banner-info" role="status">
          {PHASE_LABELS[activePhase]}:{" "}
          {awaiting === "wallet" ? "confirm in your wallet" : "waiting for the block"}
        </div>
      ) : null}

      {error ? (
        <div className="banner banner-error">
          <p role="alert">{error}</p>
          <button type="button" className="btn-ghost" onClick={dismissError}>
            Dismiss
          </button>
        </div>
      ) : null}

      {lastResult ? (
        <div className="banner banner-success">
          <p>{RESULT_MESSAGES[lastResult.kind] ?? "Transaction confirmed."}</p>
          <button type="button" className="btn-ghost" onClick={dismissResult}>
            Dismiss
          </button>
        </div>
      ) : null}
    </section>
  );
}
