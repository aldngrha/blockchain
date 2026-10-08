import { ConnectButton } from "@rainbow-me/rainbowkit";
import { useAccount, useSwitchChain } from "wagmi";
import {
  ADDRESSES_CONFIGURED,
  anvilChain,
  GOVERNOR_ADDRESS,
  sepoliaChain,
  SUPPORTED_CHAIN_IDS,
  TOKEN_ADDRESS,
  TREASURY_ADDRESS,
} from "./config";
import { useProposals } from "./hooks/useProposals";
import { useBlockTime } from "./hooks/useBlockTime";
import { useGovernanceReads, useProposalLiveStates } from "./hooks/useGovernanceReads";
import { useProposalDetail, useProposalVoteHistory } from "./hooks/useProposalDetail";
import { useGovernanceActions } from "./hooks/useGovernanceActions";
import { useHashRoute, navigateToList } from "./lib/router";
import { formatEth, shortenAddress } from "./lib/format";
import { ActionFeedback } from "./components/ActionFeedback";
import { ProposalList } from "./components/ProposalList";
import { ProposalDetail } from "./components/ProposalDetail";
import { DelegateForm } from "./components/DelegateForm";
import { CreateProposalForm } from "./components/CreateProposalForm";

function chainLabel(chainId) {
  if (chainId === anvilChain.id) return "Anvil";
  if (chainId === sepoliaChain.id) return "Sepolia";
  return `chain ${chainId ?? "unknown"}`;
}

function SetupNotice() {
  return (
    <section className="card notice" aria-labelledby="setup-title">
      <h2 id="setup-title">Contract addresses not configured</h2>
      <p>The app reads the governor, token, and treasury addresses from a .env file or the deploy script output.</p>
      <ol>
        <li>
          Start a local chain: <code>anvil</code>
        </li>
        <li>
          Run the deploy script from the repo root (<code>forge script DeployGovernance</code>). It
          writes <code>deployments/31337.json</code> next to the contracts.
        </li>
        <li>
          Restart this dev server. The addresses are picked up automatically, or set{" "}
          <code>VITE_GOVERNOR_ADDRESS</code>, <code>VITE_GOVERNANCE_TOKEN_ADDRESS</code>, and{" "}
          <code>VITE_TREASURY_ADDRESS</code> in <code>frontend/.env</code> (see{" "}
          <code>.env.example</code>).
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
        Your wallet is on {chainLabel(chainId)}. This app only talks to Anvil (31337) and Sepolia
        (11155111).
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

export default function App() {
  const route = useHashRoute();
  const { address, isConnected, chainId } = useAccount();
  const chainSupported = SUPPORTED_CHAIN_IDS.includes(chainId);
  const appEnabled = ADDRESSES_CONFIGURED && isConnected && chainSupported;

  const actions = useGovernanceActions({ chainId });
  const reads = useGovernanceReads({ chainId, address, enabled: appEnabled });

  // The scan builds the proposal list; everything below renders from its cache.
  const scan = useProposals({ chainId, enabled: appEnabled });
  const blockTime = useBlockTime({ chainId, enabled: appEnabled });
  const metas = scan.metas;
  const liveStates = useProposalLiveStates({ chainId, metas, enabled: appEnabled });

  const detailMeta = useMemo(
    () =>
      route.name === "proposal-detail" && route.proposalId
        ? metas.find((m) => m.proposalId === route.proposalId) ?? null
        : null,
    [route, metas],
  );
  const detail = useProposalDetail({
    chainId,
    address,
    proposalId: route.proposalId,
    enabled: appEnabled && route.name === "proposal-detail" && route.proposalId !== null,
  });
  const history = useProposalVoteHistory({
    chainId,
    proposalId: route.proposalId,
    enabled: appEnabled && route.name === "proposal-detail" && route.proposalId !== null,
  });

  const page =
    route.name === "proposal-detail" ? (
      <ProposalDetail
        meta={detailMeta}
        proposalId={route.proposalId}
        detail={detail}
        history={history}
        actions={actions}
        busy={actions.busy}
        address={address}
        delegatee={reads.delegatee}
        tokenBalance={reads.tokenBalance}
        symbol={reads.symbol}
        estimateBlockDate={blockTime.estimateBlockDate}
        chainLabel={chainLabel(chainId)}
        onBackToList={navigateToList}
      />
    ) : (
      <>
        <ProposalList
          metas={metas}
          liveStates={liveStates.live}
          scan={scan}
          blockTime={blockTime}
          symbol={reads.symbol}
        />
        <DelegateForm
          address={address}
          reads={reads}
          busy={actions.busy}
          actions={actions}
        />
        <CreateProposalForm reads={reads} busy={actions.busy} actions={actions} />
      </>
    );

  return (
    <div className="app">
      <header className="header">
        <div>
          <h1>Governance DApp</h1>
          <p className="header-sub">
            Propose treasury payouts, vote with GT voting power, queue, and execute via the timelock.
          </p>
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
              Connect a wallet to see proposals, your voting power, and the treasury balance. On a
              local chain you can import one of the funded anvil accounts into your wallet.
            </p>
          </section>
        ) : (
          <>
            {reads.readsError ? (
              <div className="banner banner-error" role="alert">
                <p>
                  Could not read the contracts on {chainLabel(chainId)}. Is the deployed address
                  pointing at this network? Raw error:{" "}
                  {reads.readsError?.shortMessage ?? reads.readsError?.message ?? "unknown read failure"}
                </p>
              </div>
            ) : null}

            <section className="treasury-strip" aria-label="Protocol stats">
              <div className="position-item">
                <span className="stat-label">Treasury balance</span>
                <span className="stat-value">
                  {reads.treasuryBalance === undefined ? "-" : `${formatEth(reads.treasuryBalance)} ETH`}
                </span>
              </div>
              <div className="position-item">
                <span className="stat-label">Your {reads.symbol ?? "GT"} voting power</span>
                <span className="stat-value">
                  {reads.currentVotes === undefined ? "-" : formatEth(reads.currentVotes)}
                </span>
              </div>
              <div className="position-item">
                <span className="stat-label">Network</span>
                <span className="stat-value">{chainLabel(chainId)}</span>
              </div>
            </section>

            {page}
            <ActionFeedback actions={actions} />
          </>
        )}
      </main>

      <footer className="footer">
        <p>
          Governor <code>{shortenAddress(GOVERNOR_ADDRESS) || "not set"}</code> / GT{" "}
          <code>{shortenAddress(TOKEN_ADDRESS) || "not set"}</code> / Treasury{" "}
          <code>{shortenAddress(TREASURY_ADDRESS) || "not set"}</code>
        </p>
        <p>Learning project from the 9-month blockchain roadmap. Contracts are unaudited.</p>
      </footer>
    </div>
  );
}
