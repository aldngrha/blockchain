import { useState } from "react";
import { ConnectButton } from "@rainbow-me/rainbowkit";
import {
  useAccount,
  useReadContract,
  useWriteContract,
  useWaitForTransactionReceipt,
} from "wagmi";
import { CONTRACT_ADDRESS, NFT_ABI } from "./config";
import "./App.css";

function App() {
  const { address, isConnected } = useAccount();
  const [uri, setUri] = useState("");
  const [lastMinted, setLastMinted] = useState(null);

  // Read contract state
  const { data: mintPrice } = useReadContract({
    address: CONTRACT_ADDRESS,
    abi: NFT_ABI,
    functionName: "mintPrice",
  });

  const { data: totalMinted } = useReadContract({
    address: CONTRACT_ADDRESS,
    abi: NFT_ABI,
    functionName: "totalMinted",
  });

  const { data: maxSupply } = useReadContract({
    address: CONTRACT_ADDRESS,
    abi: NFT_ABI,
    functionName: "maxSupply",
  });

  const { data: mintingActive } = useReadContract({
    address: CONTRACT_ADDRESS,
    abi: NFT_ABI,
    functionName: "mintingActive",
  });

  const { data: remaining } = useReadContract({
    address: CONTRACT_ADDRESS,
    abi: NFT_ABI,
    functionName: "remaining",
  });

  // Write: mint
  const {
    writeContract: mint,
    data: mintHash,
    isPending: isMintPending,
    error: mintError,
  } = useWriteContract();

  // Wait for mint tx
  const { isLoading: isConfirming, isSuccess: mintConfirmed } =
    useWaitForTransactionReceipt({ hash: mintHash });

  const handleMint = () => {
    if (!uri.trim()) return;
    mint({
      address: CONTRACT_ADDRESS,
      abi: NFT_ABI,
      functionName: "mint",
      args: [uri.trim()],
      value: mintPrice || 0n,
    });
  };

  // Format ETH
  const formatEth = (wei) => {
    if (!wei) return "0";
    return (Number(wei) / 1e18).toFixed(4);
  };

  return (
    <div className="app">
      <header>
        <h1>🎨 Freebuff NFT Mint</h1>
        <p>Mint your own NFT on Sepolia testnet</p>
        <ConnectButton />
      </header>

      <main>
        {/* STATS */}
        <section className="stats">
          <div className="stat">
            <span className="stat-label">Minted</span>
            <span className="stat-value">
              {totalMinted?.toString() ?? "—"}
            </span>
          </div>
          <div className="stat">
            <span className="stat-label">Remaining</span>
            <span className="stat-value">{remaining?.toString() ?? "—"}</span>
          </div>
          <div className="stat">
            <span className="stat-label">Price</span>
            <span className="stat-value">
              {formatEth(mintPrice)} ETH
            </span>
          </div>
          <div className="stat">
            <span className="stat-label">Status</span>
            <span className={`stat-value ${mintingActive ? "green" : "red"}`}>
              {mintingActive ? "Active" : "Paused"}
            </span>
          </div>
        </section>

        {/* MINT FORM */}
        {isConnected ? (
          <section className="mint-form">
            <h2>Mint an NFT</h2>
            <p className="hint">
              Upload your image to{" "}
              <a href="https://pinata.cloud" target="_blank" rel="noreferrer">
                Pinata
              </a>{" "}
              first, then paste the IPFS URI here.
            </p>

            <input
              type="text"
              placeholder="ipfs://QmYourMetadataHash"
              value={uri}
              onChange={(e) => setUri(e.target.value)}
              disabled={!mintingActive || isMintPending || isConfirming}
            />

            <button
              onClick={handleMint}
              disabled={
                !uri.trim() ||
                !mintingActive ||
                isMintPending ||
                isConfirming
              }
            >
              {isMintPending
                ? "⏳ Waiting for wallet..."
                : isConfirming
                ? "⏳ Confirming..."
                : `🔨 Mint NFT (${formatEth(mintPrice)} ETH)`}
            </button>

            {mintError && (
              <p className="error">
                ❌ {mintError.shortMessage || mintError.message}
              </p>
            )}

            {mintConfirmed && (
              <div className="success">
                <p>🎉 NFT minted successfully!</p>
                <a
                  href={`https://sepolia.etherscan.org/tx/${mintHash}`}
                  target="_blank"
                  rel="noreferrer"
                >
                  View on Etherscan →
                </a>
              </div>
            )}

            {lastMinted && (
              <div className="nft-preview">
                <h3>Your NFT</h3>
                <p>Token #{lastMinted.tokenId}</p>
                <a href={lastMinted.uri} target="_blank" rel="noreferrer">
                  View Metadata →
                </a>
              </div>
            )}
          </section>
        ) : (
          <section className="connect-prompt">
            <h2>Connect your wallet to mint</h2>
            <p>Connect MetaMask or any wallet to get started.</p>
          </section>
        )}

        {/* INFO */}
        <section className="info">
          <h3>How it works</h3>
          <ol>
            <li>
              Upload your image/metadata to{" "}
              <a href="https://pinata.cloud" target="_blank" rel="noreferrer">
                Pinata
              </a>{" "}
              (IPFS)
            </li>
            <li>Paste the IPFS URI (ipfs://Qm...)</li>
            <li>Click Mint and confirm in your wallet</li>
            <li>Your NFT appears in your wallet! 🎉</li>
          </ol>
        </section>
      </main>

      <footer>
        <p>
          Built with React + wagmi + RainbowKit + OpenZeppelin •{" "}
          <a href="https://sepolia.etherscan.org" target="_blank" rel="noreferrer">
            Sepolia Testnet
          </a>
        </p>
      </footer>
    </div>
  );
}

export default App;
