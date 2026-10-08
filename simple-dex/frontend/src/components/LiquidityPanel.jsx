import { useState } from "react";
import { addLiquidityOutcome, removeLiquidityOutcome } from "../lib/amm";
import {
  formatBps,
  formatExact,
  formatRatio,
  formatToken,
  validateAmount,
} from "../lib/format";

function PoolStats({ reads }) {
  const { token0, token1, reserve0, reserve1, lpTotalSupply, lpSymbol } = reads;
  return (
    <section className="card" aria-labelledby="pool-stats-title">
      <h2 id="pool-stats-title">Pool</h2>
      <div className="stat-grid">
        <div className="stat-item">
          <span className="stat-label">Reserve {token0?.symbol ?? "token0"}</span>
          <span className="stat-value stat-small">{formatToken(reserve0, token0?.decimals) ?? "..."}</span>
        </div>
        <div className="stat-item">
          <span className="stat-label">Reserve {token1?.symbol ?? "token1"}</span>
          <span className="stat-value stat-small">{formatToken(reserve1, token1?.decimals) ?? "..."}</span>
        </div>
        <div className="stat-item">
          <span className="stat-label">{lpSymbol} total supply</span>
          <span className="stat-value stat-small">{formatToken(lpTotalSupply, 18) ?? "..."}</span>
        </div>
      </div>
      {token0 && token1 ? (
        <p className="stat-hint">
          Canonical order read from the pair: token0 = {token0.symbol}, token1 = {token1.symbol}.
          The pair sorts tokens by address, which does not have to match the deploy labels.
        </p>
      ) : null}
    </section>
  );
}

function PositionCard({ reads }) {
  const { token0, token1, reserve0, reserve1, lpTotalSupply, lpBalance, shareBps, lpSymbol } = reads;
  const hasPosition = lpBalance !== undefined && lpBalance > 0n;
  // Estimated underlying holdings: the exact payout removeLiquidity would pay
  // (floor division against total supply), shown per token.
  const est0 =
    lpBalance !== undefined && lpTotalSupply !== undefined && lpTotalSupply > 0n
      ? (lpBalance * reserve0) / lpTotalSupply
      : undefined;
  const est1 =
    lpBalance !== undefined && lpTotalSupply !== undefined && lpTotalSupply > 0n
      ? (lpBalance * reserve1) / lpTotalSupply
      : undefined;

  return (
    <section className="card" aria-labelledby="position-title">
      <h2 id="position-title">Your position</h2>
      {lpBalance === undefined || lpTotalSupply === undefined ? (
        <p className="form-hint">Loading your LP position...</p>
      ) : !hasPosition ? (
        <p className="form-hint">
          You hold no {lpSymbol} tokens. Add liquidity below to open a position; it is minted
          to your wallet and represents your share of both reserves.
        </p>
      ) : (
        <div className="stat-grid">
          <div className="stat-item">
            <span className="stat-label">{lpSymbol} tokens</span>
            <span className="stat-value">{formatToken(lpBalance, 18) ?? "..."}</span>
          </div>
          <div className="stat-item">
            <span className="stat-label">Pool share</span>
            <span className="stat-value">{formatBps(shareBps)}%</span>
          </div>
          <div className="stat-item">
            <span className="stat-label">Estimated holdings (if withdrawn now)</span>
            <span className="stat-value stat-small">
              {formatToken(est0, token0?.decimals) ?? "..."} {token0?.symbol} +{" "}
              {formatToken(est1, token1?.decimals) ?? "..."} {token1?.symbol}
            </span>
          </div>
        </div>
      )}
    </section>
  );
}

function AddLiquidityForm({ reads, actions }) {
  const { token0, token1, reserve0, reserve1, lpTotalSupply } = reads;
  const [amount0, setAmount0] = useState("");
  const [amount1, setAmount1] = useState("");

  const validation0 = validateAmount(amount0, {
    max: token0?.balance,
    maxLabel: `your ${token0?.symbol ?? "token0"} balance`,
    decimals: token0?.decimals,
  });
  const validation1 = validateAmount(amount1, {
    max: token1?.balance,
    maxLabel: `your ${token1?.symbol ?? "token1"} balance`,
    decimals: token1?.decimals,
  });

  const firstProvision = lpTotalSupply !== undefined && lpTotalSupply === 0n;
  const poolSeeded = reserve0 !== undefined && reserve1 !== undefined && lpTotalSupply > 0n;

  // Suggested matching side at the current pool ratio (mirrors AMMLibrary.quote).
  const suggested1 = poolSeeded && validation0.value !== null
    ? (validation0.value * reserve1) / reserve0
    : null;
  const suggested0 = poolSeeded && validation1.value !== null
    ? (validation1.value * reserve0) / reserve1
    : null;

  // Full outcome mirror: amounts actually pulled, surplus left in the wallet,
  // LP minted. null means the contract would revert.
  const outcome =
    validation0.value !== null && validation1.value !== null
      ? addLiquidityOutcome(validation0.value, validation1.value, reserve0, reserve1, lpTotalSupply)
      : null;

  const ratioOff =
    outcome !== null && (outcome.surplus0 > 0n || outcome.surplus1 > 0n);

  const dataReady =
    token0 !== null && token1 !== null &&
    reserve0 !== undefined && reserve1 !== undefined && lpTotalSupply !== undefined &&
    token0.decimals !== undefined && token1.decimals !== undefined &&
    token0.balance !== undefined && token1.balance !== undefined &&
    token0.allowance !== undefined && token1.allowance !== undefined;

  const willRevert =
    reserve0 !== undefined && reserve1 !== undefined && lpTotalSupply !== undefined &&
    outcome === null &&
    validation0.value !== null && validation1.value !== null;

  const canSubmit =
    validation0.value !== null && validation1.value !== null &&
    validation0.error === null && validation1.error === null &&
    !willRevert && dataReady && !actions.busy;

  const onSubmit = (event) => {
    event.preventDefault();
    if (!canSubmit) return;
    actions.addLiquidity({
      amount0: validation0.value,
      amount1: validation1.value,
      token0,
      token1,
      allowance0Wei: token0.allowance,
      allowance1Wei: token1.allowance,
      onSuccess: () => {
        setAmount0("");
        setAmount1("");
      },
    });
  };

  return (
    <form className="card form" onSubmit={onSubmit}>
      <h2>Add liquidity</h2>
      {firstProvision ? (
        <p className="form-hint">
          First provision: the pair takes both amounts fully and mints the geometric mean
          (sqrt of the product), minus 1000 wei LP locked in the pair forever. Any ratio is
          accepted because the ratio is being defined now.
        </p>
      ) : (
        <p className="form-hint">
          Deposit both tokens. The pair only pulls the amounts that match its current ratio
          and leaves any surplus in your wallet, so an off-ratio deposit cannot lose funds,
          it just mints less LP than the headline numbers suggest.
        </p>
      )}

      <div className="field">
        <div className="field-label-row">
          <label htmlFor="add-amount0">{token0?.symbol ?? "token0"} amount</label>
          <span className="stat-hint">
            Balance: {formatToken(token0?.balance, token0?.decimals) ?? "..."}
          </span>
        </div>
        <div className="input-row">
          <input
            id="add-amount0"
            className="input"
            inputMode="decimal"
            autoComplete="off"
            placeholder="0.0"
            value={amount0}
            onChange={(event) => setAmount0(event.target.value)}
            disabled={actions.busy}
            aria-invalid={Boolean(amount0.trim()) && Boolean(validation0.error)}
          />
          <button
            type="button"
            className="btn-ghost"
            onClick={() => setAmount0(formatExact(token0?.balance, token0?.decimals))}
            disabled={actions.busy || token0?.balance === undefined}
          >
            Max
          </button>
        </div>
        {amount0.trim() && validation0.error ? (
          <p className="field-error" role="alert">{validation0.error}</p>
        ) : null}
        {suggested1 !== null ? (
          <p className="field-hint">
            Pool ratio suggests {formatToken(suggested1, token1?.decimals) ?? "..."}{" "}
            {token1?.symbol}.
            {formatToken(suggested1, token1?.decimals) !== null ? (
              <>
                {" "}
                <button
                  type="button"
                  className="btn-ghost"
                  onClick={() => setAmount1(formatExact(suggested1, token1.decimals))}
                  disabled={actions.busy}
                >
                  Use suggested
                </button>
              </>
            ) : null}
          </p>
        ) : null}
      </div>

      <div className="field">
        <div className="field-label-row">
          <label htmlFor="add-amount1">{token1?.symbol ?? "token1"} amount</label>
          <span className="stat-hint">
            Balance: {formatToken(token1?.balance, token1?.decimals) ?? "..."}
          </span>
        </div>
        <div className="input-row">
          <input
            id="add-amount1"
            className="input"
            inputMode="decimal"
            autoComplete="off"
            placeholder="0.0"
            value={amount1}
            onChange={(event) => setAmount1(event.target.value)}
            disabled={actions.busy}
            aria-invalid={Boolean(amount1.trim()) && Boolean(validation1.error)}
          />
          <button
            type="button"
            className="btn-ghost"
            onClick={() => setAmount1(formatExact(token1?.balance, token1?.decimals))}
            disabled={actions.busy || token1?.balance === undefined}
          >
            Max
          </button>
        </div>
        {amount1.trim() && validation1.error ? (
          <p className="field-error" role="alert">{validation1.error}</p>
        ) : null}
        {suggested0 !== null ? (
          <p className="field-hint">
            Pool ratio suggests {formatToken(suggested0, token0?.decimals) ?? "..."}{" "}
            {token0?.symbol}.
            {" "}
            <button
              type="button"
              className="btn-ghost"
              onClick={() => setAmount0(formatExact(suggested0, token0.decimals))}
              disabled={actions.busy}
            >
              Use suggested
            </button>
          </p>
        ) : null}
      </div>

      {ratioOff && outcome !== null ? (
        <div className="banner banner-info" role="status">
          <p>
            Ratio off-pool: the pair will pull {formatToken(outcome.amount0, token0?.decimals)}{" "}
            {token0?.symbol} and {formatToken(outcome.amount1, token1?.decimals)}{" "}
            {token1?.symbol}. The surplus ({formatToken(outcome.surplus0, token0?.decimals)}{" "}
            {token0?.symbol} / {formatToken(outcome.surplus1, token1?.decimals)}{" "}
            {token1?.symbol}) stays in your wallet, it is never transferred.
          </p>
        </div>
      ) : null}

      {outcome !== null && outcome.liquidity > 0n ? (
        <p className="field-hint">
          Expected LP mint: {formatToken(outcome.liquidity, 18)} {reads.lpSymbol}
        </p>
      ) : null}

      {willRevert ? (
        <p className="field-error" role="alert">
          {firstProvision
            ? "Too small: a first provision this size would mint at most 1000 wei LP, which the pair locks anyway. Deposit more."
            : "The pair would mint zero LP for this deposit. Increase at least one side."}
        </p>
      ) : null}

      <button type="submit" className="btn btn-primary" disabled={!canSubmit}>
        {actions.busy
          ? `${actions.activeStep.label}...`
          : "Add liquidity"}
      </button>
    </form>
  );
}

function RemoveLiquidityForm({ reads, actions }) {
  const { token0, token1, reserve0, reserve1, lpTotalSupply, lpBalance, lpSymbol } = reads;
  const [lpAmount, setLpAmount] = useState("");

  const validation = validateAmount(lpAmount, {
    max: lpBalance,
    maxLabel: `your ${lpSymbol} balance`,
    decimals: 18,
  });

  // Exact payout preview with the mirrored contract math. null (with a parsed
  // amount) is the dust case: one side would pay out zero and the pair reverts.
  const outcome =
    validation.value !== null
      ? removeLiquidityOutcome(validation.value, reserve0, reserve1, lpTotalSupply)
      : null;
  const willRevert =
    reserve0 !== undefined && reserve1 !== undefined && lpTotalSupply !== undefined &&
    validation.value !== null && outcome === null;

  const canSubmit =
    validation.value !== null && validation.error === null && !willRevert && !actions.busy;

  const onSubmit = (event) => {
    event.preventDefault();
    if (!canSubmit) return;
    actions.removeLiquidity(validation.value, {
      onSuccess: () => setLpAmount(""),
    });
  };

  return (
    <form className="card form" onSubmit={onSubmit}>
      <h2>Remove liquidity</h2>
      <p className="form-hint">
        Burn {lpSymbol} tokens and receive the proportional share of both reserves,
        computed against the total supply before the burn, rounded down. No approval is
        needed: the pair burns LP from your balance directly.
      </p>

      <div className="field">
        <div className="field-label-row">
          <label htmlFor="remove-lp">{lpSymbol} amount to burn</label>
          <span className="stat-hint">
            Balance: {formatToken(lpBalance, 18) ?? "..."}
          </span>
        </div>
        <div className="input-row">
          <input
            id="remove-lp"
            className="input"
            inputMode="decimal"
            autoComplete="off"
            placeholder="0.0"
            value={lpAmount}
            onChange={(event) => setLpAmount(event.target.value)}
            disabled={actions.busy}
            aria-invalid={Boolean(lpAmount.trim()) && Boolean(validation.error)}
          />
          <button
            type="button"
            className="btn-ghost"
            onClick={() => setLpAmount(formatExact(lpBalance, 18))}
            disabled={actions.busy || lpBalance === undefined}
          >
            Max
          </button>
        </div>
        {lpAmount.trim() && validation.error ? (
          <p className="field-error" role="alert">{validation.error}</p>
        ) : null}
      </div>

      {outcome !== null ? (
        <div className="quote-box">
          <p className="quote-line">
            Estimated payout:{" "}
            <strong>
              {formatToken(outcome.amount0, token0?.decimals)} {token0?.symbol} +{" "}
              {formatToken(outcome.amount1, token1?.decimals)} {token1?.symbol}
            </strong>
          </p>
          <p className="quote-line quote-secondary">
            At the current ratio that is {formatRatio(reserve1, reserve0) ?? "..."}{" "}
            {token1?.symbol} per {token0?.symbol}, before any swap that happens between now
            and confirmation.
          </p>
        </div>
      ) : null}

      {willRevert ? (
        <p className="field-error" role="alert">
          The pair would revert (InsufficientLiquidityBurned): this LP amount pays out zero
          on one side. Enter a larger amount.
        </p>
      ) : null}

      <button type="submit" className="btn btn-danger" disabled={!canSubmit}>
        {actions.busy ? `${actions.activeStep.label}...` : "Remove liquidity"}
      </button>
    </form>
  );
}

export function LiquidityPanel({ reads, actions, poolEmpty }) {
  return (
    <div className="liquidity-grid">
      {poolEmpty ? (
        <div className="banner banner-info" role="status">
          <p>
            The pool is empty, so ratio quotes and LP estimates are unavailable. Seed it
            first (see the notice above), then these forms come alive.
          </p>
        </div>
      ) : null}
      <PoolStats reads={reads} />
      <PositionCard reads={reads} />
      <div className="forms">
        <AddLiquidityForm reads={reads} actions={actions} />
        <RemoveLiquidityForm reads={reads} actions={actions} />
      </div>
    </div>
  );
}
