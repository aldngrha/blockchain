import { useState } from "react";
import { gql } from "@apollo/client";
import { useQuery } from "@apollo/client/react";

// ═══════════════════════════════════════════════
// QUERIES — GraphQL buat ambil data dari subgraph
// ═══════════════════════════════════════════════

const GET_TRANSFERS = gql`
  query GetTransfers($first: Int!, $skip: Int!) {
    transfers(
      first: $first
      skip: $skip
      orderBy: blockNumber
      orderDirection: desc
    ) {
      id
      from
      to
      value
      blockNumber
      timestamp
      txHash
    }
  }
`;

const GET_TOP_HOLDERS = gql`
  query GetTopHolders($first: Int!) {
    tokenHolders(first: $first, orderBy: balance, orderDirection: desc) {
      id
      address
      balance
      transferCount
    }
  }
`;

const GET_STATS = gql`
  query GetStats {
    transfers(orderBy: blockNumber, orderDirection: desc, first: 1) {
      blockNumber
    }
    tokenHolders {
      id
    }
  }
`;

const GET_TRANSFERS_BY_ADDRESS = gql`
  query GetTransfersByAddress($address: String!, $first: Int!) {
    transfers(
      where: { from: $address }
      first: $first
      orderBy: blockNumber
      orderDirection: desc
    ) {
      from
      to
      value
      blockNumber
      timestamp
    }
  }
`;

// ═══════════════════════════════════════════════
// HELPER FUNCTIONS
// ═══════════════════════════════════════════════

function truncateAddress(addr) {
  if (!addr) return "???";
  return `${addr.slice(0, 6)}...${addr.slice(-4)}`;
}

function formatTimestamp(ts) {
  if (!ts) return "???";
  const date = new Date(Number(ts) * 1000);
  return date.toLocaleString("id-ID");
}

function formatEth(value) {
  if (!value) return "0";
  const num = parseFloat(value);
  if (num >= 1) return `${num.toFixed(4)} WETH`;
  if (num >= 0.001) return `${num.toFixed(6)} WETH`;
  return `${num.toFixed(10)} WETH`;
}

// ═══════════════════════════════════════════════
// MAIN COMPONENT
// ═══════════════════════════════════════════════

const SUBGRAPH_URL =
  "https://api.studio.thegraph.com/query/1758382/weth-sepolia-events/v0.0.1";

export default function GraphQLDashboard() {
  const [page, setPage] = useState(0);
  const [searchAddress, setSearchAddress] = useState("");
  const [activeTab, setActiveTab] = useState("transfers");
  const PAGE_SIZE = 10;

  // ─── QUERIES ───────────────────────────────

  const {
    data: transfersData,
    loading: transfersLoading,
    error: transfersError,
  } = useQuery(GET_TRANSFERS, {
    variables: { first: PAGE_SIZE, skip: page * PAGE_SIZE },

  });


  const { data: holdersData, loading: holdersLoading } = useQuery(GET_TOP_HOLDERS, {
    variables: { first: 20 },
  });

  const { data: statsData } = useQuery(GET_STATS);

  const {
    data: searchData,
    loading: searchLoading,
    refetch: refetchSearch,
  } = useQuery(GET_TRANSFERS_BY_ADDRESS, {
    variables: {
      address: searchAddress.toLowerCase(),
      first: 20,
    },
    skip: !searchAddress || searchAddress.length < 42,
  });

  // ─── DERIVED DATA ─────────────────────────

  const transfers = transfersData?.transfers || [];
  const holders = holdersData?.tokenHolders || [];
  const latestBlock = statsData?.transfers?.[0]?.blockNumber || "???";
  const totalHolders = statsData?.tokenHolders?.length || 0;
  const searchResults = searchData?.transfers || [];



  // ─── RENDER ───────────────────────────────

  return (
    <section className="card graphql-dashboard">
      <h2>5. The Graph — Indexed Data</h2>
      <p className="graphql-subtitle">
        Real-time data dari subgraph WETH Sepolia
      </p>

      {/* STATS BAR */}
      <div className="graphql-stats">
        <div className="stat-item">
          <span className="stat-label">Latest Block</span>
          <span className="stat-value">#{latestBlock}</span>
        </div>
        <div className="stat-item">
          <span className="stat-label">Unique Holders</span>
          <span className="stat-value">{totalHolders}</span>
        </div>
        <div className="stat-item">
          <span className="stat-label">Polling</span>
          <span className="stat-value stat-live">⚡ 12s</span>
        </div>
      </div>

      {/* TABS */}
      <div className="graphql-tabs">
        <button
          className={`tab-btn ${activeTab === "transfers" ? "active" : ""}`}
          onClick={() => setActiveTab("transfers")}
        >
          📤 Transfers
        </button>
        <button
          className={`tab-btn ${activeTab === "holders" ? "active" : ""}`}
          onClick={() => setActiveTab("holders")}
        >
          👥 Top Holders
        </button>
        <button
          className={`tab-btn ${activeTab === "search" ? "active" : ""}`}
          onClick={() => setActiveTab("search")}
        >
          🔍 Search
        </button>
      </div>

      {/* TAB: TRANSFERS */}
      {activeTab === "transfers" && (
        <div className="graphql-content">
          {transfersLoading && <p className="loading">Loading...</p>}
          {!transfersLoading && transfers.length === 0 && (
            <p className="empty">Belum ada data. Tunggu indexing selesai.</p>
          )}
          {transfers.length > 0 && (
            <>
              <table className="graphql-table">
                <thead>
                  <tr>
                    <th>From</th>
                    <th>To</th>
                    <th>Value</th>
                    <th>Block</th>
                    <th>Time</th>
                    <th>Tx</th>
                  </tr>
                </thead>
                <tbody>
                  {transfers.map((tx, i) => (
                    <tr key={tx.id || i}>
                      <td><code>{truncateAddress(tx.from)}</code></td>
                      <td><code>{truncateAddress(tx.to)}</code></td>
                      <td className="value-cell">{formatEth(tx.value)}</td>
                      <td>
                        <a href={`https://sepolia.etherscan.io/block/${tx.blockNumber}`} target="_blank" rel="noopener noreferrer">
                          #{tx.blockNumber}
                        </a>
                      </td>
                      <td>{formatTimestamp(tx.timestamp)}</td>
                      <td>
                        <a href={`https://sepolia.etherscan.io/tx/${tx.txHash}`} target="_blank" rel="noopener noreferrer">
                          🔗
                        </a>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
              <div className="pagination">
                <button className="btn btn-secondary" disabled={page === 0} onClick={() => setPage(page - 1)}>
                  ← Prev
                </button>
                <span>Page {page + 1}</span>
                <button className="btn btn-secondary" disabled={transfers.length < PAGE_SIZE} onClick={() => setPage(page + 1)}>
                  Next →
                </button>
              </div>
            </>
          )}
        </div>
      )}

      {/* TAB: TOP HOLDERS */}
      {activeTab === "holders" && (
        <div className="graphql-content">
          {holdersLoading && <p className="loading">Loading...</p>}
          {!holdersLoading && holders.length === 0 && (
            <p className="empty">Belum ada holders ter-index.</p>
          )}
          {holders.length > 0 && (
            <table className="graphql-table">
              <thead>
                <tr>
                  <th>#</th>
                  <th>Address</th>
                  <th>Balance</th>
                  <th>Transfers</th>
                </tr>
              </thead>
              <tbody>
                {holders.map((h, i) => (
                  <tr key={h.id}>
                    <td>{i + 1}</td>
                    <td>
                      <code>
                        <a href={`https://sepolia.etherscan.io/address/${h.address}`} target="_blank" rel="noopener noreferrer">
                          {truncateAddress(h.address)}
                        </a>
                      </code>
                    </td>
                    <td className="value-cell">{formatEth(h.balance)}</td>
                    <td>{h.transferCount}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>
      )}

      {/* TAB: SEARCH */}
      {activeTab === "search" && (
        <div className="graphql-content">
          <div className="search-bar">
            <input
              type="text"
              placeholder="Paste Ethereum address (0x...)"
              value={searchAddress}
              onChange={(e) => setSearchAddress(e.target.value)}
              className="search-input"
            />
            {searchAddress && searchAddress.length >= 42 && (
              <button className="btn btn-primary" onClick={() => refetchSearch()}>
                🔍 Search
              </button>
            )}
          </div>
          {searchLoading && <p className="loading">Searching...</p>}
          {!searchLoading && searchAddress.length >= 42 && searchResults.length === 0 && (
            <p className="empty">Tidak ada transfer dari address ini.</p>
          )}
          {searchResults.length > 0 && (
            <table className="graphql-table">
              <thead>
                <tr>
                  <th>From</th>
                  <th>To</th>
                  <th>Value</th>
                  <th>Block</th>
                  <th>Time</th>
                </tr>
              </thead>
              <tbody>
                {searchResults.map((tx, i) => (
                  <tr key={i}>
                    <td><code>{truncateAddress(tx.from)}</code></td>
                    <td><code>{truncateAddress(tx.to)}</code></td>
                    <td className="value-cell">{formatEth(tx.value)}</td>
                    <td>#{tx.blockNumber}</td>
                    <td>{formatTimestamp(tx.timestamp)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>
      )}

      {/* QUERY URL */}
      <div className="graphql-url-box">
        <p><strong>Subgraph URL:</strong></p>
        <code className="graphql-url">{SUBGRAPH_URL}</code>
      </div>
    </section>
  );
}
