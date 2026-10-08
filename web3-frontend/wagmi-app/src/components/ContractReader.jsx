import { useState } from "react";
import {
  useReadContract,
  useWatchContractEvent,
  useBlockNumber,
} from "wagmi";
import { formatEther, formatUnits } from "viem";

/*
 * READ CONTRACT vs WRITE CONTRACT:
 *
 * READ (gratis, tanpa gas):
 *   → Panggil view/pure function di smart contract
 *   → Tidak ubah state blockchain
 *   → Tidak butuh signature
 *   → Contoh: balanceOf(), name(), totalSupply(), getBalance()
 *
 * WRITE (bayar gas):
 *   → Panggil function yang ubah state
 *   → Butuh signature dari wallet
 *   → Contoh: transfer(), mint(), store()
 *   → Ini di-May 30
 */

// Simple ABI untuk demo — cuma function yang mau di-read
const COUNTER_ABI = [
  {
    type: "function",
    name: "number",
    inputs: [],
    outputs: [{ type: "uint256" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "sender",
    inputs: [],
    outputs: [{ type: "address" }],
    stateMutability: "view",
  },
];

// WETH ABI — baca balance dari well-known contract
const WETH_ABI = [
  {
    type: "function",
    name: "balanceOf",
    inputs: [{ name: "account", type: "address" }],
    outputs: [{ type: "uint256" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "name",
    inputs: [],
    outputs: [{ type: "string" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "symbol",
    inputs: [],
    outputs: [{ type: "string" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "totalSupply",
    inputs: [],
    outputs: [{ type: "uint256" }],
    stateMutability: "view",
  },
  {
    type: "event",
    name: "Transfer",
    inputs: [
      { name: "from", type: "address", indexed: true },
      { name: "to", type: "address", indexed: true },
      { name: "value", type: "uint256", indexed: false },
    ],
  },
];

// Sepolia WETH address
const WETH_SEPOLIA = "0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9";

export default function ContractReader() {
  const [contractAddress, setContractAddress] = useState(WETH_SEPOLIA);
  const [targetAddress, setTargetAddress] = useState("");
  const [events, setEvents] = useState([]);
  const [watchEnabled, setWatchEnabled] = useState(false);

  // === READ HOOKS ===

  // 1. Read WETH name
  const { data: tokenName, isLoading: nameLoading } = useReadContract({
    address: contractAddress,
    abi: WETH_ABI,
    functionName: "name",
  });

  // 2. Read WETH symbol
  const { data: tokenSymbol } = useReadContract({
    address: contractAddress,
    abi: WETH_ABI,
    functionName: "symbol",
  });

  // 3. Read totalSupply
  const { data: totalSupply } = useReadContract({
    address: contractAddress,
    abi: WETH_ABI,
    functionName: "totalSupply",
  });

  // 4. Read balanceOf (conditional — only if targetAddress is set)
  const {
    data: tokenBalance,
    isLoading: balanceLoading,
    error: balanceError,
  } = useReadContract({
    address: contractAddress,
    abi: WETH_ABI,
    functionName: "balanceOf",
    args: targetAddress ? [targetAddress] : undefined,
    query: { enabled: !!targetAddress },
  });

  // 5. Current block number (real-time)
  const { data: blockNumber } = useBlockNumber({ watch: true });

  // === EVENT LISTENER ===

  // Watch Transfer events — real-time
  useWatchContractEvent({
    address: contractAddress,
    abi: WETH_ABI,
    eventName: "Transfer",
    onLogs(logs) {
      const newEvents = logs.map((log) => ({
        from: log.args.from,
        to: log.args.to,
        value: formatUnits(log.args.value, 18),
        block: log.blockNumber,
        txHash: log.transactionHash,
        timestamp: Date.now(),
      }));
      setEvents((prev) => [...newEvents, ...prev].slice(0, 20)); // max 20
    },
    enabled: watchEnabled,
  });

  return (
    <div className="contract-reader">
      {/* === SECTION 1: READ CONTRACT === */}
      <section className="card">
        <h2>1. Read Contract (Free — No Gas)</h2>

        {/* Contract Address Input */}
        <div className="input-group">
          <label>Contract Address:</label>
          <input
            type="text"
            value={contractAddress}
            onChange={(e) => setContractAddress(e.target.value)}
            className="input"
            placeholder="0x..."
          />
        </div>

        {/* Token Info */}
        <div className="token-info">
          <div className="token-info-row">
            <span className="label">Name:</span>
            <span className="value">
              {nameLoading ? "Loading..." : tokenName || "—"}
            </span>
          </div>
          <div className="token-info-row">
            <span className="label">Symbol:</span>
            <span className="value">{tokenSymbol || "—"}</span>
          </div>
          <div className="token-info-row">
            <span className="label">Total Supply:</span>
            <span className="value">
              {totalSupply ? formatUnits(totalSupply, 18) : "—"}
            </span>
          </div>
          <div className="token-info-row">
            <span className="label">Current Block:</span>
            <span className="value">
              #{blockNumber?.toString() || "—"}
            </span>
          </div>
        </div>

        {/* Balance Reader */}
        <div className="balance-reader">
          <h3>Balance Checker</h3>
          <div className="input-group">
            <label>Check balance of address:</label>
            <input
              type="text"
              value={targetAddress}
              onChange={(e) => setTargetAddress(e.target.value)}
              className="input"
              placeholder="0x... (leave empty to skip)"
            />
          </div>
          {targetAddress && (
            <div className="balance-result">
              {balanceLoading ? (
                <span className="loading">Fetching balance...</span>
              ) : balanceError ? (
                <span className="error">
                  Error: {balanceError.message?.slice(0, 80)}
                </span>
              ) : tokenBalance !== undefined ? (
                <span className="balance-value">
                  💰 {formatUnits(tokenBalance, 18)} {tokenSymbol}
                </span>
              ) : null}
            </div>
          )}
        </div>
      </section>

      {/* === SECTION 2: EVENT LISTENER === */}
      <section className="card">
        <h2>2. Event Listener (Real-time)</h2>

        <div className="event-controls">
          <button
            onClick={() => setWatchEnabled(!watchEnabled)}
            className={`btn ${watchEnabled ? "btn-danger" : "btn-primary"}`}
          >
            {watchEnabled ? "⏹ Stop Watching" : "▶ Watch Transfer Events"}
          </button>
          {watchEnabled && (
            <span className="watching-indicator">
              <span className="pulse-dot" /> Listening for Transfer events...
            </span>
          )}
        </div>

        {events.length > 0 ? (
          <div className="event-list">
            <h3>Recent Transfers ({events.length})</h3>
            {events.map((event, i) => (
              <div key={event.txHash + i} className="event-item">
                <div className="event-header">
                  <span className="event-badge">Transfer</span>
                  <span className="event-block">Block #{event.block.toString()}</span>
                </div>
                <div className="event-details">
                  <p>
                    <strong>From:</strong>{" "}
                    <code>{event.from.slice(0, 8)}...{event.from.slice(-6)}</code>
                  </p>
                  <p>
                    <strong>To:</strong>{" "}
                    <code>{event.to.slice(0, 8)}...{event.to.slice(-6)}</code>
                  </p>
                  <p>
                    <strong>Value:</strong>{" "}
                    <span className="event-value">{event.value} ETH</span>
                  </p>
                  <a
                    href={`https://sepolia.etherscan.io/tx/${event.txHash}`}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="link"
                  >
                    View Tx →
                  </a>
                </div>
              </div>
            ))}
          </div>
        ) : (
          watchEnabled && (
            <p className="no-events">
              Waiting for Transfer events... (send WETH on Sepolia to see them)
            </p>
          )
        )}
      </section>

      {/* === SECTION 3: HOOKS REFERENCE === */}
      <section className="card">
        <h3>Read Hooks Cheat Sheet</h3>
        <table>
          <thead>
            <tr>
              <th>Hook</th>
              <th>Fungsi</th>
              <th>Gas</th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <td><code>useReadContract()</code></td>
              <td>Baca view/pure function</td>
              <td>Free</td>
            </tr>
            <tr>
              <td><code>useBlockNumber()</code></td>
              <td>Block number terkini</td>
              <td>Free</td>
            </tr>
            <tr>
              <td><code>useWatchContractEvent()</code></td>
              <td>Listen events real-time</td>
              <td>Free</td>
            </tr>
            <tr>
              <td><code>useBalance()</code></td>
              <td>ETH balance</td>
              <td>Free</td>
            </tr>
          </tbody>
        </table>
      </section>
    </div>
  );
}
