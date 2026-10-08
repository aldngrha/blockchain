import { ProposalCard } from "./ProposalCard";

// Proposal list with all four data states: loading (first scan), error (scan
// failed), empty (no ProposalCreated events yet), and the list itself.
export function ProposalList({ metas, liveStates, scan, blockTime, symbol }) {
  const { scanStatus, scanError, refetchScan } = scan;
  const firstScan = scanStatus === "pending" && metas.length === 0;

  if (firstScan) {
    return (
      <section className="card" aria-busy="true">
        <h2>Proposals</h2>
        <p className="stat-hint">
          Scanning ProposalCreated events from the governor to build the list. On a fresh anvil
          chain this takes a moment; on Sepolia the first full-range scan can take longer.
        </p>
      </section>
    );
  }

  if (scanError && metas.length === 0) {
    return (
      <section className="card">
        <h2>Proposals</h2>
        <div className="banner banner-error" role="alert">
          <p>
            The event scan failed: {scanError?.shortMessage ?? scanError?.message ?? "unknown error"}
          </p>
        </div>
        <button type="button" className="btn btn-secondary" onClick={() => refetchScan()}>
          Retry scan
        </button>
      </section>
    );
  }

  if (metas.length === 0) {
    return (
      <section className="card">
        <h2>Proposals</h2>
        <p className="stat-hint">
          No proposals yet. This list is built from ProposalCreated events, so it stays empty until
          someone creates the first proposal with the form below.
        </p>
      </section>
    );
  }

  return (
    <section className="proposal-list" aria-label="Proposals">
      <div className="proposal-list-head">
        <h2>Proposals</h2>
        <p className="stat-hint">
          {metas.length} proposal{metas.length === 1 ? "" : "s"} found by the event scan
          {scan.scanResult
            ? ` (up to block ${scan.scanResult.scannedTo.toLocaleString()})`
            : " (from the local cache)"}
          .
        </p>
      </div>
      {metas.map((meta) => (
        <ProposalCard
          key={meta.proposalId}
          meta={meta}
          live={liveStates?.[meta.proposalId]}
          estimateBlockDate={blockTime?.estimateBlockDate}
          symbol={symbol}
        />
      ))}
      {scanError ? (
        <div className="banner banner-error" role="alert">
          <p>
            The latest scan failed (showing cached data):{" "}
            {scanError?.shortMessage ?? scanError?.message ?? "unknown error"}
          </p>
          <button type="button" className="btn-ghost" onClick={() => refetchScan()}>
            Retry
          </button>
        </div>
      ) : null}
    </section>
  );
}
