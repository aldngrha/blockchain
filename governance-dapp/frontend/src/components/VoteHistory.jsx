import { formatToken, shortenAddress } from "../lib/format";

const SUPPORT_LABELS = ["Against", "For", "Abstain"];
const SUPPORT_CLASSES = ["vote-against", "vote-for", "vote-abstain"];

// Vote history for one proposal, from VoteCast logs. Same trade-off as the
// proposal list: this comes from an event scan, not a view call.
export function VoteHistory({ history, chain }) {
  const { votes, loading, error } = history;

  return (
    <section className="card" aria-labelledby="vote-history-title">
      <h2 id="vote-history-title">Vote history</h2>
      {loading ? (
        <p className="stat-hint" aria-busy="true">
          Loading VoteCast events for this proposal...
        </p>
      ) : error ? (
        <div className="banner banner-error" role="alert">
          <p>Could not load the vote history: {error?.shortMessage ?? error?.message}</p>
        </div>
      ) : votes.length === 0 ? (
        <p className="stat-hint">
          No votes recorded yet. Each vote lands here as soon as its VoteCast event exists on
          chain{chain ? ` (${chain})` : ""}.
        </p>
      ) : (
        <ul className="vote-history">
          {votes.map((vote, index) => (
            <li key={`${vote.transactionHash}-${index}`} className="vote-history-row">
              <span className="vote-history-voter">
                <code>{shortenAddress(vote.voter)}</code>
              </span>
              <span className={`vote-history-support ${SUPPORT_CLASSES[vote.support] ?? ""}`}>
                {SUPPORT_LABELS[vote.support] ?? `support ${vote.support}`}
              </span>
              <span className="vote-history-weight">{formatToken(vote.weight)} GT</span>
              <span className="vote-history-block block-ref">block {vote.blockNumber.toLocaleString()}</span>
              {vote.reason ? <span className="vote-history-reason">"{vote.reason}"</span> : null}
            </li>
          ))}
        </ul>
      )}
    </section>
  );
}
