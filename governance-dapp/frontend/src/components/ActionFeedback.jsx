const PHASE_LABELS = {
  vote: "Vote",
  queue: "Queue",
  execute: "Execute",
  cancel: "Cancel",
  delegate: "Delegate",
  propose: "Create proposal",
};

const RESULT_MESSAGES = {
  vote: "Vote confirmed. The tally updates as the chain data refreshes.",
  queue: "Proposal queued. The timelock delay is now running.",
  execute: "Proposal executed on chain.",
  cancel: "Proposal canceled.",
  delegate: "Delegation confirmed. Checkpoints are updated from this block onward.",
  propose: "Proposal created. It appears in the list as soon as the scan picks it up.",
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
