import { http, createConfig } from "wagmi";
import { mainnet, sepolia } from "wagmi/chains";
import { injected, walletConnect } from "wagmi/connectors";
import { getDefaultConfig } from "@rainbow-me/rainbowkit";

// Alchemy RPC — lebih reliable untuk events
const alchemyKey = import.meta.env.VITE_ALCHEMY_KEY;

function rpcUrl(chain) {
  if (alchemyKey) {
    return `https://${chain}.g.alchemy.com/v2/${alchemyKey}`;
  }
  // Fallback ke public RPC
  if (chain === "eth-mainnet") return "https://eth.llamarpc.com";
  if (chain === "eth-sepolia") return "https://rpc.sepolia.org";
  return "https://eth.llamarpc.com";
}

export const config = getDefaultConfig({
  appName: "My Web3 dApp",
  projectId: "demo-project-id",
  chains: [mainnet, sepolia],
  transports: {
    [mainnet.id]: http(rpcUrl("eth-mainnet")),
    [sepolia.id]: http(rpcUrl("eth-sepolia")),
  },
});

/*
 * WHY ALCHEMY?
 * 
 * Public RPC (rpc.sepolia.org):
 *   ✅ Gratis, tanpa signup
 *   ❌ Rate limited (10 req/sec)
 *   ❌ Events sering miss (polling lambat)
 *
 * Alchemy:
 *   ✅ Gratis tier (300M compute units/month)
 *   ✅ Reliable event listening
 *   ✅ Fast polling
 *
 * Setup:
 *   1. Buka https://dashboard.alchemy.com/
 *   2. Sign up (gratis)
 *   3. Create app → pilih Sepolia
 *   4. Copy API key
 *   5. Paste di .env: VITE_ALCHEMY_KEY=abc123...
 *   6. Restart dev server
 */
