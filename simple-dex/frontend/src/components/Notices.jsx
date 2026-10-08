import { useSwitchChain } from "wagmi";
import { anvilChain, sepoliaChain } from "../config";
import { shortenAddress } from "../lib/format";

function chainLabel(chainId) {
  if (chainId === anvilChain.id) return "Anvil";
  if (chainId === sepoliaChain.id) return "Sepolia";
  return `chain ${chainId ?? "unknown"}`;
}

// Shown when the deployment file is missing or .env overrides are absent, so
// the app has no addresses to talk to.
export function SetupNotice() {
  return (
    <section className="card notice" aria-labelledby="setup-title">
      <h2 id="setup-title">Contract addresses not configured</h2>
      <p>
        The app reads addresses from a .env file or from the deploy script output.
      </p>
      <ol>
        <li>
          Start a local chain on this repo&apos;s port: <code>anvil -p 8548</code>
        </li>
        <li>
          Run the deploy script from the repo root. It writes{" "}
          <code>deployments/31337.json</code> with TokenA, TokenB, and DexPair.
        </li>
        <li>
          Restart this dev server. The addresses are picked up automatically, or set{" "}
          <code>VITE_TOKEN_A_ADDRESS</code>, <code>VITE_TOKEN_B_ADDRESS</code>, and{" "}
          <code>VITE_DEX_PAIR_ADDRESS</code> in <code>frontend/.env</code> (see{" "}
          <code>.env.example</code>).
        </li>
      </ol>
    </section>
  );
}

export function ConnectNotice() {
  return (
    <section className="card notice" aria-labelledby="connect-title">
      <h2 id="connect-title">Connect your wallet</h2>
      <p>
        Connect a wallet to see pool reserves, your LP position, and to trade. On a local
        chain you can import one of the funded anvil accounts into your wallet.
      </p>
    </section>
  );
}

export function WrongChainNotice({ chainId }) {
  const { switchChain, chains } = useSwitchChain();
  return (
    <div className="banner banner-error" role="alert">
      <p>
        Your wallet is on {chainLabel(chainId)}. This app only talks to Anvil (31337) and
        Sepolia (11155111).
      </p>
      <div className="banner-actions">
        {chains.map((chain) => (
          <button
            key={chain.id}
            type="button"
            className="btn btn-secondary"
            onClick={() => switchChain({ chainId: chain.id })}
          >
            Switch to {chain.name}
          </button>
        ))}
      </div>
    </div>
  );
}

export function ReadErrorNotice({ error, chainId }) {
  return (
    <div className="banner banner-error" role="alert">
      <p>
        Could not read the contracts on {chainLabel(chainId)}. Is the node on port 8548 up
        and is the deployed address pointing at this network? Raw error:{" "}
        {error?.shortMessage ?? error?.message ?? "unknown read failure"}
      </p>
    </div>
  );
}

// The pair exists but holds no reserves: nothing to quote against yet.
export function EmptyPoolNotice() {
  return (
    <div className="banner banner-info" role="status">
      <p>
        This pool holds no reserves yet, so there is nothing to quote against. Seed it from
        the repo root: <code>forge script script/DeploySimpleDex.s.sol:DeploySimpleDex --rpc-url
        http://127.0.0.1:8548 --broadcast</code> (seeds 1000 of each token).
      </p>
    </div>
  );
}

export function AddressFooter({ tokenAAddress, tokenBAddress, pairAddress }) {
  return (
    <footer className="footer">
      <p>
        TokenA <code>{shortenAddress(tokenAAddress) || "not set"}</code> / TokenB{" "}
        <code>{shortenAddress(tokenBAddress) || "not set"}</code> / DexPair{" "}
        <code>{shortenAddress(pairAddress) || "not set"}</code>
      </p>
      <p>Learning project from the 9-month blockchain roadmap. Contracts are unaudited.</p>
    </footer>
  );
}
