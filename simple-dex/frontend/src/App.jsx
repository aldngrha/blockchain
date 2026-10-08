import { useState } from "react";
import { ConnectButton } from "@rainbow-me/rainbowkit";
import { useAccount } from "wagmi";
import {
  ADDRESSES_CONFIGURED,
  SUPPORTED_CHAIN_IDS,
  TOKEN_A_ADDRESS,
  TOKEN_B_ADDRESS,
  PAIR_ADDRESS,
} from "./config";
import { usePairReads } from "./hooks/usePairReads";
import { useDexActions } from "./hooks/useDexActions";
import { usePairEvents } from "./hooks/usePairEvents";
import { ActionFeedback } from "./components/ActionFeedback";
import {
  AddressFooter,
  ConnectNotice,
  EmptyPoolNotice,
  ReadErrorNotice,
  SetupNotice,
  WrongChainNotice,
} from "./components/Notices";
import { SwapPanel } from "./components/SwapPanel";
import { LiquidityPanel } from "./components/LiquidityPanel";

const TABS = [
  { id: "swap", label: "Swap" },
  { id: "liquidity", label: "Liquidity" },
];

export default function App() {
  const { address, isConnected, chainId } = useAccount();
  const [activeTab, setActiveTab] = useState("swap");
  const chainSupported = SUPPORTED_CHAIN_IDS.includes(chainId);
  const enabled = ADDRESSES_CONFIGURED && isConnected && chainSupported;

  const reads = usePairReads({ address, enabled });
  const actions = useDexActions();
  usePairEvents({ chainId, enabled });

  const poolEmpty =
    enabled &&
    reads.reserve0 !== undefined &&
    reads.reserve1 !== undefined &&
    (reads.reserve0 === 0n || reads.reserve1 === 0n);

  return (
    <div className="app">
      <header className="header">
        <div>
          <h1>SimpleDex</h1>
          <p className="header-sub">
            Swap and provide liquidity on a two-token constant-product pool.
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
          <ConnectNotice />
        ) : (
          <>
            {reads.readsError ? (
              <ReadErrorNotice error={reads.readsError} chainId={chainId} />
            ) : null}
            {poolEmpty ? <EmptyPoolNotice /> : null}

            <div className="tabs" role="tablist" aria-label="Sections">
              {TABS.map((tab) => (
                <button
                  key={tab.id}
                  type="button"
                  role="tab"
                  id={`tab-${tab.id}`}
                  aria-selected={activeTab === tab.id}
                  aria-controls={`panel-${tab.id}`}
                  className="tab"
                  onClick={() => setActiveTab(tab.id)}
                >
                  {tab.label}
                </button>
              ))}
            </div>

            {activeTab === "swap" ? (
              <div
                role="tabpanel"
                id="panel-swap"
                aria-labelledby="tab-swap"
                className="panel"
              >
                <SwapPanel reads={reads} actions={actions} />
              </div>
            ) : (
              <div
                role="tabpanel"
                id="panel-liquidity"
                aria-labelledby="tab-liquidity"
                className="panel"
              >
                <LiquidityPanel reads={reads} actions={actions} poolEmpty={poolEmpty} />
              </div>
            )}

            <ActionFeedback actions={actions} />
          </>
        )}
      </main>

      <AddressFooter
        tokenAAddress={TOKEN_A_ADDRESS}
        tokenBAddress={TOKEN_B_ADDRESS}
        pairAddress={PAIR_ADDRESS}
      />
    </div>
  );
}
