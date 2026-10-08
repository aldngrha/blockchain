import { formatToken } from "../lib/format";

// Progress toward quorum. Semantics follow OZ 5.4 GovernorCountingSimple:
// _quorumReached compares quorum(snapshot) against forVotes + abstainVotes
// (Against votes do NOT count toward quorum in v5.4), so that is what the bar
// measures. Success still additionally needs forVotes > againstVotes.
export function QuorumBar({ votes, quorum, symbol }) {
  if (!votes || quorum === undefined || quorum === null) {
    return (
      <p className="quorum-note">
        Quorum: not measurable yet (it is read at the snapshot block, which for Pending proposals
        is still in the future).
      </p>
    );
  }

  const forVotes = votes.forVotes ?? 0n;
  const abstainVotes = votes.abstainVotes ?? 0n;
  const counted = forVotes + abstainVotes;
  const reached = counted >= quorum;
  const percent = quorum === 0n ? 100 : Number((counted * 10000n) / quorum) / 100;
  const width = Math.min(100, percent);

  return (
    <div className="quorum">
      <div
        className="quorum-bar"
        role="meter"
        aria-valuemin={0}
        aria-valuemax={100}
        aria-valuenow={Math.min(100, Math.round(percent))}
        aria-label={`Quorum progress: ${reached ? "reached" : "not reached"}`}
      >
        <div
          className={`quorum-fill ${reached ? "quorum-fill-reached" : ""}`}
          style={{ width: `${width}%` }}
        />
      </div>
      <p className="quorum-note">
        Quorum {reached ? "reached" : "not reached"}: {formatToken(counted) ?? "0"} of{" "}
        {formatToken(quorum) ?? "0"} {symbol ?? "GT"} (for + abstain, {percent.toFixed(2)}%)
      </p>
    </div>
  );
}
