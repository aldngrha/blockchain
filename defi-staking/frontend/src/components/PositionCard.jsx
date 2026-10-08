import { formatToken } from "../lib/format";

// The focal panel: the two numbers the user acts on, staked balance and
// claimable reward, with the claim action attached to the reward.
export function PositionCard({ reads, busy, actions }) {
  const { stakedBalance, earned, tokenSymbol, tokenDecimals } = reads;
  const loading = stakedBalance === undefined || earned === undefined;
  const symbol = tokenSymbol ?? "";

  return (
    <section className="card position" aria-label="Your position">
      <div className="position-grid">
        <div className="position-item">
          <span className="stat-label">Your staked balance</span>
          <span className="stat-value">
            {loading ? "Loading..." : `${formatToken(stakedBalance, tokenDecimals)} ${symbol}`}
          </span>
          {!loading && stakedBalance === 0n ? (
            <span className="stat-hint">
              Nothing staked yet. Use the stake form below to start earning.
            </span>
          ) : null}
        </div>

        <div className="position-item">
          <span className="stat-label">Claimable reward</span>
          <span className="stat-value">
            {loading ? "Loading..." : `${formatToken(earned, tokenDecimals)} ${symbol}`}
          </span>
          <button
            type="button"
            className="btn btn-primary"
            onClick={actions.claim}
            disabled={busy || loading || earned === 0n}
          >
            {actions.activePhase === "claim" ? "Claiming..." : "Claim reward"}
          </button>
          {!loading && earned === 0n ? (
            <span className="stat-hint">
              Rewards accrue every second while you have an active stake.
            </span>
          ) : null}
        </div>
      </div>
    </section>
  );
}
