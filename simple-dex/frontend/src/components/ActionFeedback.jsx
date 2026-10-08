// Transaction feedback area, shared by both panels. Error and success are
// dismissable, the busy line reflects the current step of the active flow.
export function ActionFeedback({ actions }) {
  const { error, lastResult, activeStep, awaiting, busy, dismissError, dismissResult } = actions;
  if (!error && !lastResult && !busy) return null;

  const resultMessages = {
    swap: "Swap confirmed. Balances and reserves refetched.",
    add: "Liquidity added. Your LP position is updated below the forms.",
    remove: "Liquidity removed. The burned LP paid out both tokens.",
  };

  return (
    <div className="feedback" aria-live="polite">
      {error ? (
        <div className="banner banner-error" role="alert">
          <p>{error}</p>
          <button type="button" className="btn-ghost" onClick={dismissError}>
            Dismiss
          </button>
        </div>
      ) : null}

      {busy ? (
        <div className="banner banner-info" role="status">
          <p>
            {activeStep.label}...{" "}
            {awaiting === "wallet"
              ? "Confirm in your wallet."
              : awaiting === "block"
                ? "Waiting for the transaction block."
                : ""}
          </p>
        </div>
      ) : null}

      {lastResult ? (
        <div className="banner banner-success" role="status">
          <p>{resultMessages[lastResult.kind] ?? "Transaction confirmed."}</p>
          <button type="button" className="btn-ghost" onClick={dismissResult}>
            Dismiss
          </button>
        </div>
      ) : null}
    </div>
  );
}
