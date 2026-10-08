import { formatApy, formatToken } from "../lib/format";

// Secondary pool numbers: smaller than the position card on purpose, they are
// context, not the action surface. Every value comes from a live contract
// read, no derived marketing numbers.
export function PoolStats({ reads }) {
  const { totalStaked, rewardRate, tokenBalance, tokenSymbol, tokenDecimals } = reads;
  const apy = formatApy(rewardRate, totalStaked);
  const symbol = tokenSymbol ?? "";

  return (
    <section className="pool-stats" aria-label="Pool overview">
      <div className="pool-stat">
        <span className="stat-label">Pool TVL (total staked)</span>
        <span className="stat-value stat-small">
          {totalStaked === undefined
            ? "Loading..."
            : `${formatToken(totalStaked, tokenDecimals)} ${symbol}`}
        </span>
      </div>
      <div className="pool-stat">
        <span className="stat-label">APY estimate</span>
        <span className="stat-value stat-small">
          {apy === null ? "Loading..." : apy === "n/a" ? "n/a" : `${apy}%`}
        </span>
        <span className="stat-hint">
          rewardRate per second annualized over 365 days, against current total staked. Moves
          whenever either value changes; not a forward-looking promise.
        </span>
      </div>
      <div className="pool-stat">
        <span className="stat-label">Your wallet balance</span>
        <span className="stat-value stat-small">
          {tokenBalance === undefined
            ? "Loading..."
            : `${formatToken(tokenBalance, tokenDecimals)} ${symbol}`}
        </span>
      </div>
    </section>
  );
}
