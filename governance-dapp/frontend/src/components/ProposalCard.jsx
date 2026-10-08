import { formatDate, formatRelative, formatToken, shortenAddress, shortenProposalId } from "../lib/format";
import { StatusBadge } from "./StatusBadge";
import { QuorumBar } from "./QuorumBar";

// One proposal in the list. The whole card links to the detail page, so
// keyboard focus and activation come from the anchor element.
export function ProposalCard({ meta, live, estimateBlockDate, symbol }) {
  const state = live?.state;
  const votes = live?.votes;
  const deadlineDate = estimateBlockDate?.(meta.voteEnd) ?? null;

  return (
    <a className="proposal-card" href={`#/proposal/${meta.proposalId}`}>
      <div className="proposal-card-head">
        <StatusBadge state={state} />
        <span className="proposal-id block-ref">#{shortenProposalId(meta.proposalId)}</span>
      </div>

      <p className="proposal-description">
        {meta.description
          ? meta.description
          : "Description not available in the local cache. It only exists in the ProposalCreated event log."}
      </p>

      <dl className="proposal-meta">
        <div>
          <dt>Proposer</dt>
          <dd>
            <code>{shortenAddress(meta.proposer)}</code>
          </dd>
        </div>
        <div>
          <dt>Voting ends</dt>
          <dd>
            <span className="block-ref">block {meta.voteEnd.toLocaleString()}</span>{" "}
            {deadlineDate ? (
              <span className="meta-estimate">
                {formatDate(deadlineDate)} ({formatRelative(deadlineDate)}, est.)
              </span>
            ) : null}
          </dd>
        </div>
      </dl>

      <div className="vote-counts">
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

      <QuorumBar votes={votes} quorum={live?.quorum} symbol={symbol} />
    </a>
  );
}
