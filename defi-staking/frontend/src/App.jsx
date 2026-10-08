import { ConnectButton } from "@rainbow-me/rainbowkit";
import { useAccount, useSwitchChain } from "wagmi";
import {
  ADDRESSES_CONFIGURED,
  anvilChain,
  POOL_ADDRESS,
  sepoliaChain,
  SUPPORTED_CHAIN_IDS,
  TOKEN_ADDRESS,
} from "./config";
import { usePoolReads } from "./hooks/usePoolReads";
import { useStakingActions } from "./hooks/useStakingActions";
import { usePoolEvents } from "./hooks/usePoolEvents";
import { ActionFeedback } from "./components/ActionFeedback";
import { EmergencyZone } from "./components/EmergencyZone";
import { PositionCard } from "./components/PositionCard";
import { PoolStats } from "./components/PoolStats";
import { StakeForm } from "./components/StakeForm";
import { UnstakeForm } from "./components/UnstakeForm";
import { shortenAddress } from "./lib/format";

function chainLabel(chainId) {
  if (chainId === anvilChain.id) return "Anvil";
  if (chainId === sepoliaChain.id) return "Sepolia";
  return `chain ${chainId ?? "unknown"}`;
}

function SetupNotice() {
  return (
    <section className="card notice" aria-labelledby="setup-title">
      <h2 id="setup-title">Contract addresses not configured</h2>
      <p>The dashboard reads addresses from a .env file or from the deploy script output.</p>
      <ol>
        <li>
          Start a local chain: <code>anvil</code>
        </li>
        <li>
          Run the deploy script from the repo root. It writes{" "}
          <code>deployments/31337.json</code> next to the contracts.
        </li>
        <li>
          Restart this dev server. The addresses are picked up automatically, or set{" "}
          <code>VITE_STAKING_POOL_ADDRESS</code> and <code>VITE_REWARD_TOKEN_ADDRESS</code> in{" "}
          <code>frontend/.env</code> (see <code>.env.example</code>).
        </li>
      </ol>
    </section>
  );
}

function WrongChainNotice({ chainId }) {
  const { switchChain, chains } = useSwitchChain();
  return (
    <div className="banner banner-error" role="alert">
      <p>
        Your wallet is on {chainLabel(chainId)}. This dashboard only talks to Anvil (31337) and
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

function ReadErrorNotice({ error, chainId }) {
  return (
    <div className="banner banner-error" role="alert">
      <p>
        Could not read the contracts on {chainLabel(chainId)}. Is the deployed address pointing at
        this network? Raw error: {error?.shortMessage ?? error?.message ?? "unknown read failure"}
      </p>
    </div>
  );
}

export default function App() {
  const { address, isConnected, chainId } = useAccount();
  const chainSupported = SUPPORTED_CHAIN_IDS.includes(chainId);
  const dashboardEnabled = ADDRESSES_CONFIGURED && isConnected && chainSupported;

  const reads = usePoolReads({ address, enabled: dashboardEnabled });
  const actions = useStakingActions();
  usePoolEvents({ chainId, enabled: dashboardEnabled });

  return (
    <div className="app">
      <header className="header">
        <div>
          <h1>DeFi Staking</h1>
          <p className="header-sub">Stake tokens, earn rewards per second, claim anytime.</p>
        </div>
        <ConnectButton />
      </header>

      <main className="main">
        {!ADDRESSES_CONFIGURED ? (
          <SetupNotice />
        ) : isConnected && !chainSupported ? (
          <WrongChainNotice chainId={chainId} />
        ) : !isConnected ? (
          <section className="card notice" aria-labelledby="connect-title">
            <h2 id="connect-title">Connect your wallet</h2>
            <p>
              Connect a wallet to see your staked position, claimable reward, and the pool numbers.
              On a local chain you can import one of the funded anvil accounts into your wallet.
            </p>
          </section>
        ) : (
          <>
            {reads.readsError ? (
              <ReadErrorNotice error={reads.readsError} chainId={chainId} />
            ) : null}

            <PositionCard reads={reads} busy={actions.busy} actions={actions} />
            <PoolStats reads={reads} />

            <div className="forms">
              <StakeForm reads={reads} busy={actions.busy} actions={actions} />
              <UnstakeForm reads={reads} busy={actions.busy} actions={actions} />
            </div>

            <ActionFeedback actions={actions} />

            <EmergencyZone
              busy={actions.busy}
              phase={actions.activePhase}
              stakedBalance={reads.stakedBalance}
              actions={actions}
            />
          </>
        )}
      </main>

      <footer className="footer">
        <p>
          RewardToken <code>{shortenAddress(TOKEN_ADDRESS) || "not set"}</code> / StakingPool{" "}
          <code>{shortenAddress(POOL_ADDRESS) || "not set"}</code>
        </p>
        <p>Learning project from the 9-month blockchain roadmap. Contracts are unaudited.</p>
      </footer>
    </div>
  );
}
