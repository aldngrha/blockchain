import { useState } from "react";
import {
  executionImpactBps,
  getAmountOut,
  marginalImpactBps,
  minOutputForSlippage,
} from "../lib/amm";
import { formatBps, formatExact, formatRatio, formatToken, parsePercentToBps, validateAmount } from "../lib/format";

const SLIPPAGE_PRESETS = [
  { label: "0.1%", bps: 10n },
  { label: "0.5%", bps: 50n },
  { label: "1%", bps: 100n },
];
const SLIPPAGE_MAX_BPS = 5000n; // 50%: above this the "protection" protects nothing.
const DEADLINE_MAX_MINUTES = 10080; // one week

export function SwapPanel({ reads, actions }) {
  const { token0, token1, reserve0, reserve1 } = reads;
  const [amountIn, setAmountIn] = useState("");
  const [zeroForOne, setZeroForOne] = useState(true);
  const [slippageBps, setSlippageBps] = useState(50n);
  const [customPct, setCustomPct] = useState("");
  const [deadlineMin, setDeadlineMin] = useState("20");

  const tokenIn = zeroForOne ? token0 : token1;
  const tokenOut = zeroForOne ? token1 : token0;
  const reserveIn = zeroForOne ? reserve0 : reserve1;
  const reserveOut = zeroForOne ? reserve1 : reserve0;

  const inValidation = validateAmount(amountIn, {
    max: tokenIn?.balance,
    maxLabel: `your ${tokenIn?.symbol ?? "token"} balance`,
    decimals: tokenIn?.decimals,
  });

  // Deadline: integer minutes, 1..10080.
  const deadlineNum = Number(deadlineMin);
  const deadlineValid =
    deadlineMin.trim() !== "" &&
    Number.isInteger(deadlineNum) &&
    deadlineNum >= 1 &&
    deadlineNum <= DEADLINE_MAX_MINUTES;

  // Client-side quote with the mirrored contract math.
  const amountOutWei = getAmountOut(inValidation.value, reserveIn, reserveOut);
  const outMinWei = minOutputForSlippage(amountOutWei, slippageBps);

  const dataReady =
    tokenIn !== null &&
    tokenOut !== null &&
    reserveIn !== undefined &&
    reserveOut !== undefined &&
    tokenIn.decimals !== undefined &&
    tokenIn.balance !== undefined &&
    tokenIn.allowance !== undefined;

  const poolEmpty =
    reserveIn !== undefined && reserveOut !== undefined &&
    (reserveIn === 0n || reserveOut === 0n);

  const dustOutput = amountOutWei !== null && amountOutWei === 0n;

  const needsApprove =
    inValidation.value !== null &&
    (tokenIn?.allowance === undefined || tokenIn.allowance < inValidation.value);

  const canSubmit =
    inValidation.value !== null &&
    inValidation.error === null &&
    deadlineValid &&
    !dustOutput &&
    !poolEmpty &&
    dataReady &&
    !actions.busy;

  // Display strings for the quote block.
  const spotLabel = formatRatio(reserveOut, reserveIn);
  const outLabel = formatToken(amountOutWei, tokenOut?.decimals);
  const spotAfter = formatRatio(
    amountOutWei !== null ? reserveOut - amountOutWei : undefined,
    amountOutWei !== null ? reserveIn + inValidation.value : undefined,
  );
  const execImpact = executionImpactBps(inValidation.value, reserveIn, reserveOut, amountOutWei);
  const marginalImpact = marginalImpactBps(inValidation.value, reserveIn, reserveOut, amountOutWei);

  const onCustomPct = (raw) => {
    setCustomPct(raw);
    const bps = parsePercentToBps(raw);
    if (bps !== null && bps > 0n && bps <= SLIPPAGE_MAX_BPS) setSlippageBps(bps);
  };

  const onSubmit = (event) => {
    event.preventDefault();
    if (!canSubmit) return;
    actions.swap({
      amountIn: inValidation.value,
      amountOutMin: outMinWei,
      deadlineMinutes: deadlineNum,
      zeroForOne,
      tokenIn,
      allowanceWei: tokenIn.allowance,
      onSuccess: () => setAmountIn(""),
    });
  };

  if (tokenIn === null || tokenOut === null) {
    return (
      <section className="card" aria-labelledby="swap-title">
        <h2 id="swap-title">Swap</h2>
        <p className="form-hint">Loading pair data...</p>
      </section>
    );
  }

  return (
    <form className="card form" onSubmit={onSubmit}>
      <h2>Swap</h2>
      <p className="form-hint">
        The output is computed in your browser with the same formula the contract uses
        (0.3% fee on the input, floored integer division). The pair recomputes it on chain,
        so the executed amount can differ by rounding dust.
      </p>

      <div className="field">
        <div className="field-label-row">
          <label htmlFor="amount-in">You pay ({tokenIn.symbol ?? "token"})</label>
          <span className="stat-hint">
            Balance: {formatToken(tokenIn.balance, tokenIn.decimals) ?? "..."}
          </span>
        </div>
        <div className="input-row">
          <input
            id="amount-in"
            className="input"
            inputMode="decimal"
            autoComplete="off"
            placeholder="0.0"
            value={amountIn}
            onChange={(event) => setAmountIn(event.target.value)}
            disabled={actions.busy}
            aria-invalid={Boolean(amountIn.trim()) && Boolean(inValidation.error)}
          />
          <button
            type="button"
            className="btn-ghost"
            onClick={() => setAmountIn(formatExact(tokenIn.balance, tokenIn.decimals))}
            disabled={actions.busy || tokenIn.balance === undefined}
          >
            Max
          </button>
        </div>
        {amountIn.trim() && inValidation.error ? (
          <p className="field-error" role="alert">{inValidation.error}</p>
        ) : null}
      </div>

      <button
        type="button"
        className="btn-flip"
        onClick={() => setZeroForOne((v) => !v)}
        aria-label={`Reverse direction: currently selling ${tokenIn.symbol} for ${tokenOut.symbol}`}
      >
        Reverse direction
      </button>

      <div className="field">
        <div className="field-label-row">
          <span id="amount-out-label">You receive ({tokenOut.symbol ?? "token"})</span>
          <span className="stat-hint">
            Balance: {formatToken(tokenOut.balance, tokenOut.decimals) ?? "..."}
          </span>
        </div>
        <p className="out-value" aria-labelledby="amount-out-label">
          {amountOutWei === null ? "0.0" : outLabel ?? "0.0"}
        </p>
      </div>

      <div className="quote-box">
        <p className="quote-line">
          Pool price: 1 {tokenIn.symbol} = {spotLabel ?? "..."} {tokenOut.symbol}
        </p>
        {amountOutWei !== null && amountOutWei > 0n ? (
          <>
            <p className="quote-line">
              Price impact (execution): <strong>{formatBps(execImpact)}%</strong>
            </p>
            <p className="quote-line quote-secondary">
              Marginal price after: {spotAfter ?? "..."} {tokenOut.symbol} per{" "}
              {tokenIn.symbol} (impact {formatBps(marginalImpact)}%)
            </p>
            <p className="quote-line">
              Minimum received: {formatToken(outMinWei, tokenOut.decimals)}{" "}
              {tokenOut.symbol} (slippage {formatBps(slippageBps)}%)
            </p>
            <details className="impact-details">
              <summary>Two different impact numbers?</summary>
              <p>
                Execution impact compares the average price of your whole trade
                (amountOut / amountIn) with the pool price before it. Marginal impact
                compares the pool price after your trade with the price before it: what the
                next wei would cost. The average is always the better number of the two,
                because the pool moves along the curve while your trade executes. Both
                definitions are documented in docs/uniswap-v2-research.md, section 4.
              </p>
            </details>
          </>
        ) : null}
        {dustOutput ? (
          <p className="field-error" role="alert">
            Amount too small: the pool would pay out zero. Enter a larger amount.
          </p>
        ) : null}
      </div>

      <fieldset className="settings">
        <legend>Slippage tolerance</legend>
        <div className="preset-row" role="group" aria-label="Slippage presets">
          {SLIPPAGE_PRESETS.map((preset) => (
            <button
              key={preset.label}
              type="button"
              className="btn-preset"
              aria-pressed={customPct === "" && slippageBps === preset.bps}
              onClick={() => {
                setSlippageBps(preset.bps);
                setCustomPct("");
              }}
            >
              {preset.label}
            </button>
          ))}
          <label className="preset-custom" htmlFor="slippage-custom">
            Custom %
          </label>
          <input
            id="slippage-custom"
            className="input input-narrow"
            inputMode="decimal"
            autoComplete="off"
            placeholder="0.5"
            value={customPct}
            onChange={(event) => onCustomPct(event.target.value)}
            aria-describedby="slippage-hint"
          />
        </div>
        <p id="slippage-hint" className="field-hint">
          Between 0.01% and 50%. This sets the minimum received above; the pool reverts if
          it would pay less.
        </p>
        <div className="field">
          <label htmlFor="deadline-minutes">Deadline (minutes)</label>
          <input
            id="deadline-minutes"
            className="input input-narrow"
            inputMode="numeric"
            autoComplete="off"
            value={deadlineMin}
            onChange={(event) => setDeadlineMin(event.target.value)}
            aria-invalid={deadlineMin.trim() !== "" && !deadlineValid}
            aria-describedby="deadline-hint"
          />
          <p id="deadline-hint" className="field-hint">
            The swap reverts if it is mined after this many minutes from now (1 to 10080).
          </p>
          {deadlineMin.trim() !== "" && !deadlineValid ? (
            <p className="field-error" role="alert">
              Enter whole minutes between 1 and 10080.
            </p>
          ) : null}
        </div>
      </fieldset>

      <button type="submit" className="btn btn-primary" disabled={!canSubmit}>
        {actions.busy
          ? `${actions.activeStep.label}...`
          : needsApprove
            ? `Approve ${tokenIn.symbol}, then swap`
            : "Swap"}
      </button>
    </form>
  );
}
