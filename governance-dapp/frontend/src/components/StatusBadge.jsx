import { PROPOSAL_STATES } from "../abi";

// One badge style per real on-chain state. Badges here are functional (they
// carry the Governor state enum), so every color maps to a meaning:
// amber = waiting, blue = actionable (active), green = passed the vote,
// red = failed, neutral = terminal or not applicable.
const STATE_CLASSES = [
  "badge-pending", // 0 Pending
  "badge-active", // 1 Active
  "badge-neutral", // 2 Canceled
  "badge-defeated", // 3 Defeated
  "badge-passed", // 4 Succeeded
  "badge-passed", // 5 Queued
  "badge-neutral", // 6 Expired
  "badge-passed", // 7 Executed
];

export function StatusBadge({ state }) {
  if (state === undefined || state === null) {
    return <span className="badge badge-neutral">checking state</span>;
  }
  const label = PROPOSAL_STATES[state] ?? `state ${state}`;
  return (
    <span className={`badge ${STATE_CLASSES[state] ?? "badge-neutral"}`} data-state={state}>
      {label}
    </span>
  );
}
