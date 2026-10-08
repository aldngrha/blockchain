import { useState } from "react";
import { encodeFunctionData, isAddress } from "viem";
import { TREASURY_ABI, TREASURY_ADDRESS } from "../config";
import { formatEth, parseAmount } from "../lib/format";

// Create a payout proposal: a governor propose() whose single call is
// Treasury.execute(recipient, amount), which only the timelock will be able
// to run, and only after the proposal passes. The ETH comes from the treasury
// balance, never from the proposer (propose attaches value 0).
export function CreateProposalForm({ reads, busy, actions }) {
  const { treasuryBalance, symbol } = reads;
  const [recipient, setRecipient] = useState("");
  const [amount, setAmount] = useState("");
  const [description, setDescription] = useState("");

  const recipientValid = isAddress(recipient.trim(), { strict: false }) && recipient.trim() !== "0x0000000000000000000000000000000000000000";
  const amountValidation = parseAmount(amount);
  const descriptionValid = description.trim().length > 0;

  // Live calldata preview: shows exactly what the timelock will execute once
  // the proposal passes, so the user signs a proposal whose payload they can read.
  const calldata =
    recipientValid && amountValidation.value !== null
      ? encodeFunctionData({
          abi: TREASURY_ABI,
          functionName: "execute",
          args: [recipient.trim(), amountValidation.value],
        })
      : null;

  const canSubmit =
    recipientValid &&
    amountValidation.value !== null &&
    amountValidation.error === null &&
    descriptionValid &&
    !busy &&
    Boolean(TREASURY_ADDRESS);

  const onSubmit = (event) => {
    event.preventDefault();
    if (!canSubmit) return;
    actions.proposePayout(
      {
        recipient: recipient.trim(),
        amountWei: amountValidation.value,
        description: description.trim(),
      },
      (proposalId) => {
        setRecipient("");
        setAmount("");
        setDescription("");
        if (proposalId !== undefined) {
          window.location.hash = `#/proposal/${proposalId.toString()}`;
        }
      },
    );
  };

  return (
    <form className="card form" onSubmit={onSubmit} aria-labelledby="create-title">
      <h2 id="create-title">Create a payout proposal</h2>
      <p className="form-hint">
        Proposes one call: Treasury.execute(recipient, amount) on the treasury at{" "}
        <code>{TREASURY_ADDRESS || "not configured"}</code>. If the vote passes and the proposal is
        queued and executed, the timelock pays out from the treasury balance{" "}
        {treasuryBalance !== undefined ? `(currently ${formatEth(treasuryBalance)} ETH)` : ""}. The
        proposal itself costs no ETH.
      </p>

      <div className="field">
        <label htmlFor="recipient-address">Recipient</label>
        <input
          id="recipient-address"
          className="input"
          type="text"
          autoComplete="off"
          spellCheck="false"
          placeholder="0x... who receives the ETH"
          value={recipient}
          onChange={(event) => setRecipient(event.target.value)}
          disabled={busy}
          aria-invalid={recipient.trim() !== "" && !recipientValid}
        />
        {recipient.trim() !== "" && !recipientValid ? (
          <p className="field-error" role="alert">
            Enter a valid recipient address.
          </p>
        ) : null}
      </div>

      <div className="field">
        <label htmlFor="payout-amount">Amount (ETH)</label>
        <input
          id="payout-amount"
          className="input"
          inputMode="decimal"
          autoComplete="off"
          placeholder="0.1"
          value={amount}
          onChange={(event) => setAmount(event.target.value)}
          disabled={busy}
          aria-invalid={amount.trim() !== "" && Boolean(amountValidation.error)}
        />
        {amount.trim() && amountValidation.error ? (
          <p className="field-error" role="alert">
            {amountValidation.error}
          </p>
        ) : null}
        {treasuryBalance !== undefined && amountValidation.value !== null && amountValidation.value > treasuryBalance ? (
          <p className="stat-hint" role="note">
            Note: this is more ETH than the treasury holds. The proposal can still pass, but the
            execute transaction will fail until the treasury is funded.
          </p>
        ) : null}
      </div>

      <div className="field">
        <label htmlFor="proposal-description">Description</label>
        <textarea
          id="proposal-description"
          className="input input-area"
          rows={3}
          maxLength={1000}
          placeholder="What this payout is for. This text is stored in the ProposalCreated event."
          value={description}
          onChange={(event) => setDescription(event.target.value)}
          disabled={busy}
        />
        {!descriptionValid ? (
          <p className="stat-hint" role="note">
            A description is required: on chain it exists only in the ProposalCreated event, so this
            text is how voters (and the list page) know what they are voting on.
          </p>
        ) : null}
      </div>

      {calldata ? (
        <div className="field">
          <span className="stat-label">Calldata the timelock will execute</span>
          <code className="calldata-preview">{calldata}</code>
        </div>
      ) : null}

      <button type="submit" className="btn btn-primary" disabled={!canSubmit}>
        {busy && actions.activePhase === "propose" ? "Creating proposal..." : "Submit proposal"}
      </button>
      {symbol ? (
        <p className="stat-hint">
          Voting on it needs {symbol} voting power at the snapshot; any token holder may propose
          (threshold is 0).
        </p>
      ) : null}
    </form>
  );
}
