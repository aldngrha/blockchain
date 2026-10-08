import { useState } from "react";
import {
  useReadContract,
  useWriteContract,
  useWaitForTransactionReceipt,
  useAccount,
} from "wagmi";
import { useToast, ToastContainer } from "./Toast";

/*
 * CUSTOM CONTRACT INTERACTION
 *
 * Selama ini kita pake WETH (contract orang lain)
 * Sekarang: deploy contract SENDIRI, connect ke frontend
 *
 * Flow:
 *   1. Deploy SimpleStorage ke Sepolia (pakai Foundry)
 *   2. Copy address → paste di .env
 *   3. Frontend read/write ke contract itu
 */

// SimpleStorage ABI (dari Foundry: forge inspect SimpleStorage abi)
const SIMPLE_STORAGE_ABI = [
  {
    type: "function",
    name: "store",
    inputs: [{ name: "_favoriteNumber", type: "uint256" }],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "retrieve",
    inputs: [],
    outputs: [{ type: "uint256" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "addPerson",
    inputs: [
      { name: "_name", type: "string" },
      { name: "_favoriteNumber", type: "uint256" },
    ],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "getPersonCount",
    inputs: [],
    outputs: [{ type: "uint256" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "getPerson",
    inputs: [{ name: "_index", type: "uint256" }],
    outputs: [
      { type: "string" },
      { type: "uint256" },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "s_favoriteNumber",
    inputs: [],
    outputs: [{ type: "uint256" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "s_numberCount",
    inputs: [],
    outputs: [{ type: "uint256" }],
    stateMutability: "view",
  },
  {
    type: "event",
    name: "NumberStored",
    inputs: [
      { name: "user", type: "address", indexed: true },
      { name: "number", type: "uint256", indexed: false },
    ],
  },
  {
    type: "event",
    name: "NumberChanged",
    inputs: [
      { name: "user", type: "address", indexed: true },
      { name: "newNumber", type: "uint256", indexed: false },
    ],
  },
];

// Contract address dari .env (deploy dulu baru isi)
const CONTRACT_ADDRESS = import.meta.env.VITE_SIMPLE_STORAGE_ADDRESS;

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
    <span className="status-badge" style={{ background: color }}>{label}</span>
  );
}

export default function SimpleStorageDemo() {
  const { address, isConnected } = useAccount();
  const { toasts, addToast, removeToast } = useToast();

  const [storeNumber, setStoreNumber] = useState("");
  const [personName, setPersonName] = useState("");
  const [personNumber, setPersonNumber] = useState("");
  const [personIndex, setPersonIndex] = useState("");
  const [activeAction, setActiveAction] = useState(null);

  // === WRITE ===
  const {
    writeContract,
    data: txHash,
    isPending: isSigning,
    isSuccess: isSent,
    isError: isWriteError,
    error: writeError,
    reset: resetWrite,
  } = useWriteContract();

  // === WAIT ===
  const {
    data: receipt,
    isLoading: isConfirming,
    isSuccess: isConfirmed,
    isError: isConfirmError,
    error: confirmError,
  } = useWaitForTransactionReceipt({ hash: txHash });

  // === READS ===
  const { data: favoriteNumber, refetch: refetchNumber } = useReadContract({
    address: CONTRACT_ADDRESS,
    abi: SIMPLE_STORAGE_ABI,
    functionName: "retrieve",
    query: { enabled: !!CONTRACT_ADDRESS },
  });

  const { data: numberCount } = useReadContract({
    address: CONTRACT_ADDRESS,
    abi: SIMPLE_STORAGE_ABI,
    functionName: "s_numberCount",
    query: { enabled: !!CONTRACT_ADDRESS },
  });

  const { data: personCount } = useReadContract({
    address: CONTRACT_ADDRESS,
    abi: SIMPLE_STORAGE_ABI,
    functionName: "getPersonCount",
    query: { enabled: !!CONTRACT_ADDRESS },
  });

  const { data: person, refetch: refetchPerson } = useReadContract({
    address: CONTRACT_ADDRESS,
    abi: SIMPLE_STORAGE_ABI,
    functionName: "getPerson",
    args: personIndex !== "" ? [BigInt(personIndex)] : undefined,
    query: { enabled: !!CONTRACT_ADDRESS && personIndex !== "" },
  });

  const getStatus = () => {
    if (isWriteError || isConfirmError) return "error";
    if (isConfirmed) return "confirmed";
    if (isConfirming) return "confirming";
    if (isSigning || isSent) return "pending";
    return "idle";
  };
  const status = getStatus();

  // === HANDLERS ===
  const handleStore = () => {
    if (!storeNumber) return;
    setActiveAction("store");
    addToast("Opening wallet to store number...", "pending");
    writeContract(
      {
        address: CONTRACT_ADDRESS,
        abi: SIMPLE_STORAGE_ABI,
        functionName: "store",
        args: [BigInt(storeNumber)],
      },
      {
        onSuccess: (hash) => addToast(`Tx: ${hash.slice(0, 10)}...`, "info"),
        onError: (err) => {
          addToast(`Failed: ${err.message?.slice(0, 60)}`, "error");
          setActiveAction(null);
        },
      }
    );
  };

  const handleAddPerson = () => {
    if (!personName || !personNumber) return;
    setActiveAction("addPerson");
    addToast("Opening wallet to add person...", "pending");
    writeContract(
      {
        address: CONTRACT_ADDRESS,
        abi: SIMPLE_STORAGE_ABI,
        functionName: "addPerson",
        args: [personName, BigInt(personNumber)],
      },
      {
        onSuccess: (hash) => addToast(`Tx: ${hash.slice(0, 10)}...`, "info"),
        onError: (err) => {
          addToast(`Failed: ${err.message?.slice(0, 60)}`, "error");
          setActiveAction(null);
        },
      }
    );
  };

  if (isConfirmed) {
    setTimeout(() => {
      refetchNumber();
      refetchPerson();
      setActiveAction(null);
      resetWrite();
    }, 100);
  }

  if (!CONTRACT_ADDRESS) {
    return (
      <section className="card">
        <h2>3. Custom Contract (SimpleStorage)</h2>
        <div className="tx-error">
          <p>⚠️ Contract belum di-deploy</p>
          <p style={{ fontSize: "0.85rem", marginTop: "0.5rem" }}>
            Deploy dulu ke Sepolia:<br/>
            <code>cd web3-frontend/simple-storage</code><br/>
            <code>forge script script/DeploySimpleStorage.s.sol --rpc-url sepolia --private-key $PRIVATE_KEY --broadcast</code><br/>
            Lalu isi <code>VITE_SIMPLE_STORAGE_ADDRESS</code> di .env
          </p>
        </div>
      </section>
    );
  }

  return (
    <section className="card">
      <h2>3. Custom Contract (SimpleStorage)</h2>

      <div className="tx-status">
        <StatusBadge status={status} />
        {txHash && (
          <span className="tx-hash">
            Tx: <code>{txHash.slice(0, 10)}...{txHash.slice(-8)}</code>
          </span>
        )}
      </div>

      {/* Contract Info */}
      <div className="token-info">
        <div className="token-info-row">
          <span className="label">Contract:</span>
          <span className="value"><code>{CONTRACT_ADDRESS?.slice(0, 10)}...</code></span>
        </div>
        <div className="token-info-row">
          <span className="label">Favorite Number:</span>
          <span className="value">{favoriteNumber?.toString() ?? "—"}</span>
        </div>
        <div className="token-info-row">
          <span className="label">Times Stored:</span>
          <span className="value">{numberCount?.toString() ?? "0"}</span>
        </div>
        <div className="token-info-row">
          <span className="label">People Count:</span>
          <span className="value">{personCount?.toString() ?? "0"}</span>
        </div>
      </div>

      {/* Error */}
      {(isWriteError || isConfirmError) && (
        <div className="tx-error">
          <p>❌ Failed: {(writeError || confirmError)?.message?.slice(0, 100)}</p>
          <button onClick={() => { resetWrite(); setActiveAction(null); }} className="btn btn-secondary">🔄 Try Again</button>
        </div>
      )}

      {/* Success */}
      {isConfirmed && receipt && (
        <div className="tx-success">
          <p>✅ Confirmed in block #{receipt.blockNumber.toString()}</p>
          <a href={`https://sepolia.etherscan.io/tx/${txHash}`} target="_blank" rel="noopener noreferrer" className="link">View on Etherscan →</a>
        </div>
      )}

      {/* Store Number */}
      <div className="write-action">
        <h3>📝 Store Your Favorite Number</h3>
        <div className="action-form">
          <input
            type="number"
            placeholder="Number"
            value={storeNumber}
            onChange={(e) => setStoreNumber(e.target.value)}
            className="input"
            disabled={status !== "idle"}
          />
          <button onClick={handleStore} className="btn btn-primary" disabled={status !== "idle" || !storeNumber}>
            {isSigning ? "⏳ Signing..." : isConfirming ? "🔄 Confirming..." : "Store"}
          </button>
        </div>
      </div>

      {/* Add Person */}
      <div className="write-action">
        <h3>👤 Add Person</h3>
        <div className="action-form">
          <input
            type="text"
            placeholder="Name"
            value={personName}
            onChange={(e) => setPersonName(e.target.value)}
            className="input"
            disabled={status !== "idle"}
          />
          <input
            type="number"
            placeholder="Favorite #"
            value={personNumber}
            onChange={(e) => setPersonNumber(e.target.value)}
            className="input"
            disabled={status !== "idle"}
          />
          <button onClick={handleAddPerson} className="btn btn-primary" disabled={status !== "idle" || !personName || !personNumber}>
            {isSigning ? "⏳ Signing..." : isConfirming ? "🔄 Confirming..." : "Add"}
          </button>
        </div>
      </div>

      {/* Get Person */}
      <div className="write-action">
        <h3>🔍 Lookup Person</h3>
        <div className="action-form">
          <input
            type="number"
            placeholder="Index (0, 1, 2...)"
            value={personIndex}
            onChange={(e) => setPersonIndex(e.target.value)}
            className="input"
            min="0"
          />
          {person && (
            <div className="balance-result">
              <strong>{person[0]}</strong> — Favorite #{person[1].toString()}
            </div>
          )}
        </div>
      </div>
    </section>
  );
}
