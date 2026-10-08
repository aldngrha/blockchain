import { useState } from "react";
import { useSendTransaction, useWaitForTransactionReceipt, useAccount } from "wagmi";
import { parseEther } from "viem";
import { useToast, ToastContainer } from "./Toast";

/*
 * TRANSACTION LIFECYCLE — 5 STATES
 *
 * ┌──────┐    ┌──────────┐    ┌───────────┐    ┌──────────┐    ┌─────────┐
 * │ IDLE │───►│ SIGNING  │───►│PENDING     │───►│CONFIRMING│───►│ CONFIRMED│
 * │      │    │(wallet   │    │(broadcast  │    │(waiting  │    │(success) │
 * │      │    │ popup)   │    │ to network)│    │ for block)│    │         │
 * └──────┘    └──────────┘    └───────────┘    └──────────┘    └─────────┘
 *     │                           │                                 │
 *     │         ┌─────────┐       │                                 │
 *     └────────►│  ERROR  │◄──────┘                                 │
 *               │(revert, │                                         │
 *               │ reject) │                                         │
 *               └─────────┘                                         │
 *                                                                    │
 *               ┌──────────┐                                         │
 *               │ TIMEOUT  │◄────────────────────────────────────────┘
 *               │(too slow)│   (if tx not mined in X blocks)
 *               └──────────┘
 */

// Status badge component
function StatusBadge({ status }) {
  const config = {
    idle: { color: "#888", label: "Idle" },
    signing: { color: "#f39c12", label: "⏳ Signing..." },
    pending: { color: "#f39c12", label: "⏳ Pending" },
    confirming: { color: "#3498db", label: "🔄 Confirming" },
    confirmed: { color: "#2ecc71", label: "✅ Confirmed" },
    error: { color: "#e74c3c", label: "❌ Error" },
  };

  const { color, label } = config[status] || config.idle;

  return (
    <span className="status-badge" style={{ background: color }}>
      {label}
    </span>
  );
}

export default function TransactionDemo() {
  const { address, isConnected } = useAccount();
  const { toasts, addToast, removeToast } = useToast();

  // Form state
  const [toAddress, setToAddress] = useState("");
  const [amount, setAmount] = useState("");
  const [txHash, setTxHash] = useState(null);
  const [txHistory, setTxHistory] = useState([]);

  // === WAGMI HOOKS ===

  // 1. Send Transaction — kirim ETH ke address lain
  const {
    sendTransaction,
    data: sentHash,
    isPending: isSigning,       // true saat MetaMask popup muncul
    isSuccess: isSent,          // true setelah tx di-broadcast
    isError: isSendError,
    error: sendError,
    reset: resetSend,
  } = useSendTransaction();

  // 2. Wait for Confirmation — tunggu tx mined di block
  const {
    data: receipt,
    isLoading: isConfirming,    // true saat nunggu block
    isSuccess: isConfirmed,     // true setelah mined
    isError: isConfirmError,
    error: confirmError,
  } = useWaitForTransactionReceipt({
    hash: sentHash,
  });

  // === STATE MACHINE ===
  const getStatus = () => {
    if (isSendError || isConfirmError) return "error";
    if (isConfirmed) return "confirmed";
    if (isConfirming) return "confirming";
    if (isSigning || isSent) return "pending";
    return "idle";
  };

  const status = getStatus();

  // === HANDLERS ===

  const handleSend = () => {
    if (!toAddress || !amount) {
      addToast("Fill in all fields", "error");
      return;
    }

    addToast("Opening wallet to sign...", "pending");

    sendTransaction(
      { to: toAddress, value: parseEther(amount) },
      {
        onSuccess: (hash) => {
          setTxHash(hash);
          addToast(`Transaction broadcast! Hash: ${hash.slice(0, 10)}...`, "info");
          // Add to history
          setTxHistory((prev) => [
            { hash, to: toAddress, amount, status: "pending", timestamp: Date.now() },
            ...prev,
          ]);
        },
        onError: (error) => {
          if (error.message.includes("User rejected")) {
            addToast("Transaction rejected by user", "error");
          } else {
            addToast(`Transaction failed: ${error.message.slice(0, 60)}`, "error");
          }
        },
      }
    );
  };

  // Update history when confirmed
  if (isConfirmed && receipt && txHash) {
    const lastTx = txHistory[0];
    if (lastTx && lastTx.status === "pending" && lastTx.hash === txHash) {
      setTxHistory((prev) =>
        prev.map((tx) =>
          tx.hash === txHash
            ? { ...tx, status: "confirmed", blockNumber: receipt.blockNumber }
            : tx
        )
      );
      addToast(`Confirmed in block #${receipt.blockNumber}!`, "success");
    }
  }

  if (!isConnected) {
    return (
      <section className="card">
        <h2>Transaction UX Demo</h2>
        <p style={{ color: "#888" }}>Connect wallet terlebih dahulu</p>
      </section>
    );
  }

  return (
    <section className="card">
      <h2>1. Send ETH (Transaction Demo)</h2>

      {/* Status Display */}
      <div className="tx-status">
        <StatusBadge status={status} />
        {txHash && (
          <span className="tx-hash">
            Tx: <code>{txHash.slice(0, 10)}...{txHash.slice(-8)}</code>
          </span>
        )}
      </div>

      {/* Transaction States Explanation */}
      <div className="state-flow">
        {["idle", "signing", "pending", "confirming", "confirmed"].map((s) => (
          <div key={s} className={`state-step ${status === s ? "active" : ""}`}>
            <div className="state-dot" />
            <span>{s}</span>
          </div>
        ))}
      </div>

      {/* Send Form */}
      <div className="tx-form">
        <input
          type="text"
          placeholder="To address (0x...)"
          value={toAddress}
          onChange={(e) => setToAddress(e.target.value)}
          className="input"
          disabled={status !== "idle"}
        />
        <input
          type="number"
          placeholder="Amount (ETH)"
          value={amount}
          onChange={(e) => setAmount(e.target.value)}
          className="input"
          step="0.001"
          min="0"
          disabled={status !== "idle"}
        />
        <button
          onClick={handleSend}
          className="btn btn-primary"
          disabled={status !== "idle" || !toAddress || !amount}
        >
          {isSigning ? "⏳ Waiting for wallet..." : 
           isConfirming ? "🔄 Confirming..." :
           isConfirmed ? "✅ Done!" : "🚀 Send ETH"}
        </button>
      </div>

      {/* Error Display */}
      {(isSendError || isConfirmError) && (
        <div className="tx-error">
          <p>❌ <strong>Transaction Failed</strong></p>
          <p>{(sendError || confirmError)?.message?.slice(0, 120)}</p>
          <button onClick={resetSend} className="btn btn-secondary">
            🔄 Try Again
          </button>
        </div>
      )}

      {/* Success Display */}
      {isConfirmed && receipt && (
        <div className="tx-success">
          <p>✅ <strong>Transaction Confirmed!</strong></p>
          <p>Block: #{receipt.blockNumber.toString()}</p>
          <p>Gas used: {receipt.gasUsed.toString()}</p>
          <a
            href={`https://sepolia.etherscan.io/tx/${txHash}`}
            target="_blank"
            rel="noopener noreferrer"
            className="link"
          >
            View on Etherscan →
          </a>
        </div>
      )}

      {/* Transaction History */}
      {txHistory.length > 0 && (
        <div className="tx-history">
          <h3>Transaction History</h3>
          {txHistory.map((tx, i) => (
            <div key={tx.hash + i} className="tx-history-item">
              <StatusBadge status={tx.status} />
              <span>{tx.amount} ETH → {tx.to.slice(0, 8)}...</span>
              <code className="tx-history-hash">{tx.hash.slice(0, 12)}...</code>
            </div>
          ))}
        </div>
      )}

      {/* Toast Notifications */}
      <ToastContainer toasts={toasts} onRemove={removeToast} />
    </section>
  );
}
