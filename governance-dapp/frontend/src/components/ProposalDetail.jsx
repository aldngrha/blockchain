import { formatDate, formatRelative, formatToken, shortenAddress, shortenProposalId } from "../lib/format";
import { useNow } from "../hooks/useNow";
import { StatusBadge } from "./StatusBadge";
import { QuorumBar } from "./QuorumBar";
import { VoteSection } from "./VoteSection";
import { VoteHistory } from "./VoteHistory";

// Explanation per Governor state, next to the actions that state allows.
const STATE_EXPLANATIONS = {
  0: "Voting has not opened yet. It starts at the snapshot block.",
  1: "Voting is open. Cast For, Against, or Abstain with your snapshot voting power.",
  2: "This proposal was canceled by its proposer.",
  3: "Voting ended with more Against than For votes, so the proposal failed.",
  4: "The vote passed. Queue the proposal to start the timelock delay.",
  5: "Queued in the timelock. Execution unlocks when the delay has passed.",
  6: "The proposal sat in the timelock past its deadline and expired unexecuted.",
  7: "The proposal was executed on chain.",
};

// Detail page for one proposal: identity, live state, tally, the vote UI,
// state-appropriate actions, and the VoteCast history.
export function ProposalDetail({
  meta,
  proposalId,
  detail,
  history,
  actions,
  busy,
  address,
  delegatee,
  tokenBalance,
  symbol,
  estimateBlockDate,
  chainLabel,
  onBackToList,
}) {
  const { state, votes, quorum, snapshotBlock, deadlineBlock, etaSeconds } = detail;
  const now = useNow();
  const snapshotDate = estimateBlockDate?.(snapshotBlock) ?? null;
  const deadlineDate = estimateBlockDate?.(deadlineBlock) ?? null;
  const etaDate = etaSeconds ? new Date(etaSeconds * 1000) : null; // timelock eta is real seconds, exact
  const etaReached = etaDate ? now >= etaDate.getTime() : false;

  const isProposer =
    address !== undefined &&
    meta?.proposer !== undefined &&
    address.toLowerCase() === meta.proposer.toLowerCase();
  const hasPayload = Boolean(meta);

  return (
    <section className="proposal-detail">
      <button type="button" className="btn-back" onClick={onBackToList}>
        All proposals
      </button>

      {detail.error ? (
        <div className="banner banner-error" role="alert">
          <p>
            Could not read this proposal on chain ({" "}
            {detail.error?.shortMessage ?? detail.error?.message ?? "unknown error"} ). If the id is
            wrong the governor will not recognize it; if the id is right, check the network.
          </p>
        </div>
      ) : null}

      <div className="card detail-head">
        <div className="proposal-card-head">
          <StatusBadge state={state} />
          <span className="proposal-id block-ref">#{shortenProposalId(proposalId)}</span>
        </div>
        <p className="proposal-description detail-description">
          {meta?.description
            ? meta.description
            : "Description not available in the local cache. It only exists in the ProposalCreated event log; rescan or use the subgraph to recover it."}
        </p>
        <dl className="proposal-meta detail-meta">
          <div>
            <dt>Proposal id</dt>
            <dd>
              <code>{proposalId}</code>
            </dd>
          </div>
          <div>
            <dt>Proposer</dt>
            <dd>
              <code>{meta?.proposer ? shortenAddress(meta.proposer) : "unknown (not in cache)"}</code>
            </dd>
          </div>
          <div>
            <dt>Snapshot (voting power measured here)</dt>
            <dd>
              {snapshotBlock !== undefined ? (
                <>
                  <span className="block-ref">block {snapshotBlock.toLocaleString()}</span>{" "}
                  {snapshotDate ? (
                    <span className="meta-estimate">{formatDate(snapshotDate)} (est.)</span>
                  ) : null}
                </>
              ) : (
                "-"
              )}
            </dd>
          </div>
          <div>
            <dt>Voting deadline</dt>
            <dd>
              {deadlineBlock !== undefined ? (
                <>
                  <span className="block-ref">block {deadlineBlock.toLocaleString()}</span>{" "}
                  {deadlineDate ? (
                    <span className="meta-estimate">
                      {formatDate(deadlineDate)} ({formatRelative(deadlineDate)}, est.)
                    </span>
                  ) : null}
                </>
              ) : (
                "-"
              )}
            </dd>
          </div>
        </dl>
      </div>

      <section className="card detail-tally" aria-labelledby="tally-title">
        <h2 id="tally-title">Vote tally</h2>
        <div className="vote-counts vote-counts-big">
          <span className="vote-count vote-for">
            <span className="vote-count-label">For</span>
            <span className="vote-count-value">{formatToken(votes?.forVotes) ?? "-"}</span>
          </span>
          <span className="vote-count vote-against">
            <span className="vote-count-label">Against</span>
            <span className="vote-count-value">{formatToken(votes?.againstVotes) ?? "-"}</span>
          </span>
          <span className="vote-count vote-abstain">
            <span className="vote-count-label">Abstain</span>
            <span className="vote-count-value">{formatToken(votes?.abstainVotes) ?? "-"}</span>
          </span>
        </div>
        <QuorumBar votes={votes} quorum={quorum} symbol={symbol} />
      </section>

      {state === 1 ? (
        <VoteSection
          detail={{ ...detail, proposalId }}
          address={address}
          delegatee={delegatee}
          tokenBalance={tokenBalance}
          symbol={symbol}
          busy={busy}
          actions={actions}
        />
      ) : (
        <section className="card" aria-labelledby="state-title">
          <h2 id="state-title">What you can do</h2>
          <p className="stat-hint">{STATE_EXPLANATIONS[state ?? -1] ?? "Reading the proposal state..."}</p>

          <div className="action-buttons">
            {state === 4 ? (
              hasPayload ? (
                <button type="button" className="btn btn-primary" disabled={busy} onClick={() => actions.queue(meta)}>
                  {busy && actions.activePhase === "queue" ? "Queueing..." : "Queue for execution"}
                </button>
              ) : (
                <p className="vote-disable-reason" role="note">
                  This proposal's payload (targets, values, calldatas) is not in the local cache, so
                  the UI cannot build the queue transaction. Trigger a fresh scan or use the
                  subgraph.
                </p>
              )
            ) : null}

            {state === 5 ? (
              hasPayload ? (
                <>
                  <button
                    type="button"
                    className="btn btn-primary"
                    disabled={busy || !etaReached}
                    onClick={() => actions.execute(meta)}
                  >
                    {busy && actions.activePhase === "execute" ? "Executing..." : "Execute proposal"}
                  </button>
                  {etaDate && !etaReached ? (
                    <p className="vote-disable-reason" role="note">
                      Disabled: the timelock delay runs until {formatDate(etaDate)} ({formatRelative(etaDate)}).
                      The execute transaction would revert before that.
                    </p>
                  ) : null}
                </>
              ) : (
                <p className="vote-disable-reason" role="note">
                  This proposal's payload is not in the local cache, so the UI cannot build the
                  execute transaction.
                </p>
              )
            ) : null}

            {state === 0 && isProposer ? (
              hasPayload ? (
                <>
                  <button type="button" className="btn btn-danger" disabled={busy} onClick={() => actions.cancel(meta)}>
                    {busy && actions.activePhase === "cancel" ? "Canceling..." : "Cancel proposal"}
                  </button>
                  <p className="vote-disable-reason" role="note">
                    You proposed this. In OZ v5.4 the proposer may cancel only while the proposal is
                    Pending, before voting opens.
                  </p>
                </>
              ) : (
                <p className="vote-disable-reason" role="note">
                  You proposed this, but the payload is not in the local cache, so the UI cannot
                  build the cancel transaction.
                </p>
              )
            ) : null}
          </div>
        </section>
      )}

      <VoteHistory history={history} chain={chainLabel} />
    </section>
  );
}
