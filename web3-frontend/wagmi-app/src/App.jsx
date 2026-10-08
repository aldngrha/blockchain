import { ConnectButton } from "@rainbow-me/rainbowkit";
import { useAccount, useBalance, useChainId, useSwitchChain } from "wagmi";
import ErrorBoundary from "./components/ErrorBoundary";
import TransactionDemo from "./components/TransactionDemo";
import ContractReader from "./components/ContractReader";
import WriteContractDemo from "./components/WriteContractDemo";
import SimpleStorageDemo from "./components/SimpleStorageDemo";
import GraphQLDashboard from "./components/GraphQLDashboard";
import IPFSDemo from "./components/IPFSDemo";
import "./App.css";

function App() {
  const { address, isConnected } = useAccount();
  const { data: balance } = useBalance({ address });
  const chainId = useChainId();
  const { switchChain } = useSwitchChain();

  return (
    <ErrorBoundary>
      <div className="app">
        <h1>🔗 Web3 Frontend</h1>
        <p className="subtitle">May 31 — Full Stack Complete</p>

        {/* === CONNECT === */}
        <section className="card">
          <h2>1. Connect Wallet</h2>
          <div className="connect-btn-wrapper">
            <ConnectButton />
          </div>
          {isConnected && (
            <div className="account-info">
              <p className="connected">✅ Wallet Connected</p>
              <p>
                <strong>Address:</strong>{" "}
                <code>{`${address.slice(0, 6)}...${address.slice(-4)}`}</code>
              </p>
              <p>
                <strong>Balance:</strong>{" "}
                {balance
                  ? `${parseFloat(balance.formatted).toFixed(4)} ${balance.symbol}`
                  : "Loading..."}
              </p>
            </div>
          )}
        </section>

        {/* === WRITE CONTRACT (WETH) === */}
        <WriteContractDemo />

        {/* === CUSTOM CONTRACT (SimpleStorage) === */}
        <SimpleStorageDemo />

        {/* === READ + EVENTS === */}
        <ContractReader />

        {/* === THE GRAPH === */}
        <GraphQLDashboard />

        {/* === IPFS === */}
        <IPFSDemo />

        {/* === SEND ETH === */}
        <TransactionDemo />

        {/* === CHAIN === */}
        <section className="card">
          <h2>6. Chain Info</h2>
          <p>
            <strong>Current Chain:</strong>{" "}
            {chainId === 1
              ? "Ethereum Mainnet"
              : chainId === 11155111
              ? "Sepolia Testnet"
              : `Chain #${chainId}`}
          </p>
          <div className="chain-buttons">
            <button
              onClick={() => switchChain({ chainId: 1 })}
              className="btn btn-secondary"
              disabled={chainId === 1}
            >
              Switch to Mainnet
            </button>
            <button
              onClick={() => switchChain({ chainId: 11155111 })}
              className="btn btn-secondary"
              disabled={chainId === 11155111}
            >
              Switch to Sepolia
            </button>
          </div>
        </section>
      </div>
    </ErrorBoundary>
  );
}

export default App;
