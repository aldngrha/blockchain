import { useState } from "react";
import {
  useWriteContract,
  useWaitForTransactionReceipt,
  useReadContract,
  useAccount,
} from "wagmi";
import { parseEther, formatEther, formatUnits, parseUnits } from "viem";
import { useToast, ToastContainer } from "./Toast";

/*
 * WRITE CONTRACT — ubah state blockchain (bayar gas)
 *
 * May 28: useSendTransaction → kirim ETH aja (transfer biasa)
 * May 30: useWriteContract → panggil FUNCTION di smart contract
 *
 * Contoh write yang BEDA dari transfer biasa:
 *   → deposit() di WETH: konversi ETH → WETH
 *   → transfer() di ERC-20: kirim token (bukan ETH)
 *   → approve() di ERC-20: izinkan spender
 *   → store() di SimpleStorage: simpan angka
 */

// WETH ABI untuk write operations
const WETH_WRITE_ABI = [
  {
    type: "function",
    name: "deposit",
    inputs: [],
    outputs: [],
    stateMutability: "payable",
  },
  {
    type: "function",
    name: "withdraw",
    inputs: [{ name: "wad", type: "uint256" }],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "transfer",
    inputs: [
      { name: "dst", type: "address" },
      { name: "wad", type: "uint256" },
    ],
    outputs: [{ type: "bool" }],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "balanceOf",
    inputs: [{ name: "account", type: "address" }],
    outputs: [{ type: "uint256" }],
    stateMutability: "view",
  },
];

const WETH_SEPOLIA = "0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9";

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

export default function WriteContractDemo() {
  const { address, isConnected } = useAccount();
  const { toasts, addToast, removeToast } = useToast();

  // Form states
  const [depositAmount, setDepositAmount] = useState("");
  const [withdrawAmount, setWithdrawAmount] = useState("");
  const [transferTo, setTransferTo] = useState("");
  const [transferAmount, setTransferAmount] = useState("");

  // Active action tracking
  const [activeAction, setActiveAction] = useState(null);

  // === WRITE HOOK ===
  const {
    writeContract,
    data: txHash,
    isPending: isSigning,
    isSuccess: isSent,
    isError: isWriteError,
    error: writeError,
    reset: resetWrite,
  } = useWriteContract();

  // === WAIT FOR CONFIRMATION ===
  const {
    data: receipt,
    isLoading: isConfirming,
    isSuccess: isConfirmed,
    isError: isConfirmError,
    error: confirmError,
  } = useWaitForTransactionReceipt({
    hash: txHash,
  });

  // === READ WETH BALANCE (auto-refresh after write) ===
  const { data: wethBalance, refetch: refetchBalance } = useReadContract({
    address: WETH_SEPOLIA,
    abi: WETH_WRITE_ABI,
    functionName: "balanceOf",
    args: address ? [address] : undefined,
    query: { enabled: !!address },
  });

  // === STATE MACHINE ===
  const getStatus = () => {
    if (isWriteError || isConfirmError) return "error";
    if (isConfirmed) return "confirmed";
    if (isConfirming) return "confirming";
    if (isSigning || isSent) return "pending";
    return "idle";
  };

  const status = getStatus();

  // === HANDLERS ===

  // 1. Deposit ETH → WETH
  const handleDeposit = () => {
    if (!depositAmount) return;
    setActiveAction("deposit");
    addToast("Opening wallet to deposit ETH → WETH...", "pending");

    writeContract(
      {
        address: WETH_SEPOLIA,
        abi: WETH_WRITE_ABI,
        functionName: "deposit",
        value: parseEther(depositAmount),
      },
      {
        onSuccess: (hash) => {
          addToast(`Tx broadcast: ${hash.slice(0, 10)}...`, "info");
        },
        onError: (error) => {
          if (error.message.includes("User rejected")) {
            addToast("Transaction rejected", "error");
          } else {
            addToast(`Failed: ${error.message.slice(0, 60)}`, "error");
          }
          setActiveAction(null);
        },
      }
    );
  };

  // 2. Withdraw WETH → ETH
  const handleWithdraw = () => {
    if (!withdrawAmount) return;
    setActiveAction("withdraw");
    addToast("Opening wallet to withdraw WETH → ETH...", "pending");

    writeContract(
      {
        address: WETH_SEPOLIA,
        abi: WETH_WRITE_ABI,
        functionName: "withdraw",
        args: [parseEther(withdrawAmount)],
      },
      {
        onSuccess: (hash) => {
          addToast(`Tx broadcast: ${hash.slice(0, 10)}...`, "info");
        },
        onError: (error) => {
          if (error.message.includes("User rejected")) {
            addToast("Transaction rejected", "error");
          } else {
            addToast(`Failed: ${error.message.slice(0, 60)}`, "error");
          }
          setActiveAction(null);
        },
      }
    );
  };

  // 3. Transfer WETH to another address
  const handleTransfer = () => {
    if (!transferTo || !transferAmount) return;
    setActiveAction("transfer");
    addToast("Opening wallet to transfer WETH...", "pending");

    writeContract(
      {
        address: WETH_SEPOLIA,
        abi: WETH_WRITE_ABI,
        functionName: "transfer",
        args: [transferTo, parseEther(transferAmount)],
      },
      {
        onSuccess: (hash) => {
          addToast(`Tx broadcast: ${hash.slice(0, 10)}...`, "info");
        },
        onError: (error) => {
          if (error.message.includes("User rejected")) {
            addToast("Transaction rejected", "error");
          } else {
            addToast(`Failed: ${error.message.slice(0, 60)}`, "error");
          }
          setActiveAction(null);
        },
      }
    );
  };

  // After confirmed, reset and refetch
  if (isConfirmed && activeAction) {
    setTimeout(() => {
      refetchBalance();
      setActiveAction(null);
      resetWrite();
    }, 100);
  }

  if (!isConnected) {
    return (
      <section className="card">
        <h2>Write Contract Demo</h2>
        <p style={{ color: "#888" }}>Connect wallet terlebih dahulu</p>
      </section>
    );
  }

  return (
    <section className="card">
      <h2>2. Write Contract (Gas Required)</h2>

      {/* Status Display */}
      <div className="tx-status">
        <StatusBadge status={status} />
        {txHash && (
          <span className="tx-hash">
            Tx: <code>{txHash.slice(0, 10)}...{txHash.slice(-8)}</code>
          </span>
        )}
      </div>

      {/* WETH Balance */}
      <div className="weth-balance">
        <span>Your WETH Balance: </span>
        <strong>
          {wethBalance ? formatUnits(wethBalance, 18) : "0"} WETH
        </strong>
      </div>

      {/* Error Display */}
      {(isWriteError || isConfirmError) && (
        <div className="tx-error">
          <p>❌ <strong>Transaction Failed</strong></p>
          <p>{(writeError || confirmError)?.message?.slice(0, 120)}</p>
          <button onClick={() => { resetWrite(); setActiveAction(null); }} className="btn btn-secondary">
            🔄 Try Again
          </button>
        </div>
      )}

      {/* Success Display */}
      {isConfirmed && receipt && (
        <div className="tx-success">
          <p>✅ <strong>{activeAction?.charAt(0).toUpperCase() + activeAction?.slice(1)} Confirmed!</strong></p>
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

      {/* === ACTION 1: DEPOSIT ETH → WETH === */}
      <div className="write-action">
        <h3>🔄 Deposit ETH → WETH</h3>
        <p className="action-desc">
          Konversi ETH ke WETH (Wrapped Ether). ETH dikirim ke contract, WETH dikembalikan ke wallet.
        </p>
        <div className="action-form">
          <input
            type="number"
            placeholder="Amount (ETH)"
            value={depositAmount}
            onChange={(e) => setDepositAmount(e.target.value)}
            className="input"
            step="0.001"
            min="0"
            disabled={status !== "idle"}
          />
          <button
            onClick={handleDeposit}
            className="btn btn-primary"
            disabled={status !== "idle" || !depositAmount}
          >
            {activeAction === "deposit" && isSigning ? "⏳ Signing..." :
             activeAction === "deposit" && isConfirming ? "🔄 Confirming..." :
             "Deposit"}
          </button>
        </div>
      </div>

      {/* === ACTION 2: WITHDRAW WETH → ETH === */}
      <div className="write-action">
        <h3>💰 Withdraw WETH → ETH</h3>
        <p className="action-desc">
          Konversi WETH kembali ke ETH. WETH di-burn, ETH dikembalikan ke wallet.
        </p>
        <div className="action-form">
          <input
            type="number"
            placeholder="Amount (WETH)"
            value={withdrawAmount}
            onChange={(e) => setWithdrawAmount(e.target.value)}
            className="input"
            step="0.001"
            min="0"
            disabled={status !== "idle"}
          />
          <button
            onClick={handleWithdraw}
            className="btn btn-primary"
            disabled={status !== "idle" || !withdrawAmount}
          >
            {activeAction === "withdraw" && isSigning ? "⏳ Signing..." :
             activeAction === "withdraw" && isConfirming ? "🔄 Confirming..." :
             "Withdraw"}
          </button>
        </div>
      </div>

      {/* === ACTION 3: TRANSFER WETH === */}
      <div className="write-action">
        <h3>📤 Transfer WETH</h3>
        <p className="action-desc">
          Kirim WETH ke address lain (bukan ETH, tapi WETH token).
        </p>
        <div className="action-form">
          <input
            type="text"
            placeholder="To address (0x...)"
            value={transferTo}
            onChange={(e) => setTransferTo(e.target.value)}
            className="input"
            disabled={status !== "idle"}
          />
          <input
            type="number"
            placeholder="Amount (WETH)"
            value={transferAmount}
            onChange={(e) => setTransferAmount(e.target.value)}
            className="input"
            step="0.001"
            min="0"
            disabled={status !== "idle"}
          />
          <button
            onClick={handleTransfer}
            className="btn btn-primary"
            disabled={status !== "idle" || !transferTo || !transferAmount}
          >
            {activeAction === "transfer" && isSigning ? "⏳ Signing..." :
             activeAction === "transfer" && isConfirming ? "🔄 Confirming..." :
             "Transfer"}
          </button>
        </div>
      </div>

      {/* === COMPARISON TABLE === */}
      <div className="write-comparison">
        <h3>Read vs Write — Perbedaan</h3>
        <table>
          <thead>
            <tr>
              <th></th>
              <th>Read Contract</th>
              <th>Write Contract</th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <td><strong>Hook</strong></td>
              <td><code>useReadContract()</code></td>
              <td><code>useWriteContract()</code></td>
            </tr>
            <tr>
              <td><strong>Gas</strong></td>
              <td>Free ✅</td>
              <td>Bayar 💰</td>
            </tr>
            <tr>
              <td><strong>Signature</strong></td>
              <td>Tidak perlu</td>
              <td>MetaMask popup</td>
            </tr>
            <tr>
              <td><strong>Speed</strong></td>
              <td>Instant (~200ms)</td>
              <td>~12-60 detik</td>
            </tr>
            <tr>
              <td><strong>State change</strong></td>
              <td>Tidak</td>
              <td>Ya</td>
            </tr>
            <tr>
              <td><strong>Contoh</strong></td>
              <td>balanceOf(), name()</td>
              <td>deposit(), transfer(), withdraw()</td>
            </tr>
          </tbody>
        </table>
      </div>

      <ToastContainer toasts={toasts} onRemove={removeToast} />
    </section>
  );
}
