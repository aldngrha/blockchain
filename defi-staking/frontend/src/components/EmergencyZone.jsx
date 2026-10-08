import { useEffect, useRef, useState } from "react";

// Minimal accessible confirm dialog: Escape closes, focus is trapped inside,
// focus returns to the opener, backdrop click closes. Native <dialog> would
// do part of this; a plain component keeps the behavior explicit.
function ConfirmDialog({ open, title, children, confirmLabel, busy, onConfirm, onCancel }) {
  const dialogRef = useRef(null);
  const openerRef = useRef(null);

  useEffect(() => {
    if (!open) return undefined;
    openerRef.current = document.activeElement;
    dialogRef.current?.focus();

    const onKeyDown = (event) => {
      if (event.key === "Escape") {
        event.preventDefault();
        onCancel();
        return;
      }
      if (event.key !== "Tab") return;
      const focusables = dialogRef.current?.querySelectorAll(
        "button, [href], input, select, textarea, [tabindex]:not([tabindex='-1'])",
      );
      if (!focusables || focusables.length === 0) return;
      const first = focusables[0];
      const last = focusables[focusables.length - 1];
      if (event.shiftKey && document.activeElement === first) {
        event.preventDefault();
        last.focus();
      } else if (!event.shiftKey && document.activeElement === last) {
        event.preventDefault();
        first.focus();
      }
    };

    document.addEventListener("keydown", onKeyDown);
    return () => {
      document.removeEventListener("keydown", onKeyDown);
      openerRef.current?.focus?.();
    };
  }, [open, onCancel]);

  if (!open) return null;

  return (
    <div
      className="dialog-backdrop"
      onMouseDown={(event) => {
        if (event.target === event.currentTarget) onCancel();
      }}
    >
      <div
        ref={dialogRef}
        className="dialog"
        role="dialog"
        aria-modal="true"
        aria-labelledby="confirm-dialog-title"
        tabIndex={-1}
      >
        <h3 id="confirm-dialog-title">{title}</h3>
        {children}
        <div className="dialog-actions">
          <button type="button" className="btn btn-secondary" onClick={onCancel} disabled={busy}>
            Cancel
          </button>
          <button type="button" className="btn btn-danger" onClick={onConfirm} disabled={busy}>
            {confirmLabel}
          </button>
        </div>
      </div>
    </div>
  );
}

export function EmergencyZone({ busy, phase, stakedBalance, actions }) {
  const [open, setOpen] = useState(false);
  const hasStake = stakedBalance !== undefined && stakedBalance > 0n;

  return (
    <section className="card danger-zone">
      <h2>Emergency exit</h2>
      <p className="form-hint">
        Returns your entire staked balance in one transaction and{" "}
        <strong>forfeits every unclaimed reward</strong>. This is the escape hatch for a broken
        reward calculation, not a routine exit: use Unstake plus Claim to keep your rewards.
      </p>
      <button
        type="button"
        className="btn btn-danger"
        onClick={() => setOpen(true)}
        disabled={busy || !hasStake}
      >
        Emergency withdraw
      </button>

      <ConfirmDialog
        open={open}
        busy={busy}
        title="Emergency withdraw"
        confirmLabel={phase === "emergency" ? "Withdrawing..." : "Withdraw and forfeit rewards"}
        onCancel={() => setOpen(false)}
        onConfirm={() => {
          setOpen(false);
          actions.emergencyWithdraw();
        }}
      >
        <p>
          You will get your full staked balance back, and every unclaimed reward on it is gone for
          good. The contract resets your reward checkpoint, so restaking afterwards earns from
          zero. This cannot be undone.
        </p>
      </ConfirmDialog>
    </section>
  );
}
