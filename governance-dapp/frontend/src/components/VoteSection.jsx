import { useState } from "react";
import { SUPPORT } from "../abi";
import { formatToken, shortenAddress } from "../lib/format";

// Vote UI for an Active proposal: three explicit buttons (For / Against /
// Abstain), an optional reason, and every disable reason spelled out.
//
// The voting power that matters is the snapshot value (getPastVotes at the
// snapshot block), not the current delegated balance: delegating after the
// snapshot does not help for this proposal, only for later ones.
export function VoteSection({ detail, address, delegatee, tokenBalance, symbol, busy, actions }) {
  const [reason, setReason] = useState("");
  const { votingPowerAtSnapshot, hasVoted, snapshotBlock } = detail;

  // Disable reasons, checked in priority order. The first match wins and is
  // shown to the user; empty means the vote buttons are enabled.
  let disableReason = null;
  if (busy) {
    disableReason = "A transaction is already running.";
  } else if (hasVoted) {
    disableReason = "You already voted on this proposal (hasVoted is true on chain).";
  } else if (votingPowerAtSnapshot === undefined) {
    disableReason = "Checking your voting power at the snapshot block...";
  } else if (votingPowerAtSnapshot === 0n) {
    if (tokenBalance !== undefined && tokenBalance === 0n) {
      disableReason = `You hold no ${symbol ?? "GT"}, so you have no voting power.`;
    } else if (delegatee !== undefined && delegatee !== "0x0000000000000000000000000000000000000000") {
      disableReason = `Your voting power at snapshot block ${snapshotBlock?.toLocaleString()} is 0 because your delegation happened after the snapshot. Delegating now only applies to proposals created later.`;
    } else {
      disableReason = `Your voting power is 0: you hold ${symbol ?? "GT"} but never called delegate(). Use the delegate form on the list page. Delegation counts from your delegation block onward, so it applies to proposals created after that.`;
    }
  }

  const disabled = disableReason !== null;

  const castVote = (support) => actions.vote(String(detail.proposalId), support, reason.trim());

  return (
    <section className="card vote-section" aria-labelledby="vote-title">
      <h2 id="vote-title">Cast your vote</h2>
      <p className="form-hint">
        Your voting power for this proposal is{" "}
        <strong>
          {votingPowerAtSnapshot === undefined
            ? "checking..."
            : `${formatToken(votingPowerAtSnapshot) ?? "0"} ${symbol ?? "GT"}`}
        </strong>
        , read at the snapshot block{" "}
        {snapshotBlock !== undefined ? (
          <span className="block-ref">{snapshotBlock.toLocaleString()}</span>
        ) : null}
        . That is the number the governor counts, regardless of what you delegate afterwards.
      </p>

      {address ? (
        <p className="stat-hint">Voting as <code>{shortenAddress(address)}</code>.</p>
      ) : null}

      <div className="vote-buttons">
        <button
          type="button"
          className="btn btn-vote-for"
          disabled={disabled}
          onClick={() => castVote(SUPPORT.FOR)}
        >
          Vote For
        </button>
        <button
          type="button"
          className="btn btn-vote-against"
          disabled={disabled}
          onClick={() => castVote(SUPPORT.AGAINST)}
        >
          Vote Against
        </button>
        <button
          type="button"
          className="btn btn-secondary"
          disabled={disabled}
          onClick={() => castVote(SUPPORT.ABSTAIN)}
        >
          Abstain
        </button>
      </div>

      {disableReason ? (
        <p className="vote-disable-reason" role="note">
          {disableReason}
        </p>
      ) : null}

      <div className="field">
        <label htmlFor="vote-reason">Reason (optional, stored on chain in the VoteCast event)</label>
        <input
          id="vote-reason"
          className="input"
          type="text"
          maxLength={120}
          value={reason}
          onChange={(event) => setReason(event.target.value)}
          disabled={busy}
          placeholder="Why you vote this way"
        />
      </div>
    </section>
  );
}
