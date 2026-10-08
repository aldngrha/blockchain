import { http } from "wagmi";
import { defineChain, isAddress } from "viem";
import { sepolia } from "wagmi/chains";
import { getDefaultConfig } from "@rainbow-me/rainbowkit";
import localDeployment from "virtual:local-deployment";
import { GOVERNANCE_TOKEN_ABI, GOVERNOR_ABI, TREASURY_ABI } from "./abi";

// wagmi's built-in `localhost` chain has id 1337, but anvil's default chain id
// is 31337. Define the anvil chain explicitly so contract calls target the
// right network.
export const anvilChain = defineChain({
  id: 31337,
  name: "Anvil",
  nativeCurrency: { name: "Anvil Ether", symbol: "ETH", decimals: 18 },
  rpcUrls: { default: { http: ["http://127.0.0.1:8545"] } },
  testnet: true,
});
export const sepoliaChain = sepolia;
export const SUPPORTED_CHAIN_IDS = [anvilChain.id, sepoliaChain.id];

// Resolution order: explicit .env value wins, then the deployment file that
// the Foundry deploy script writes, then empty (UI shows setup instructions).
// strict: false accepts non-checksummed hex addresses copied into .env.
function pickAddress(envValue, deployedValue) {
  if (isAddress(envValue ?? "", { strict: false })) return envValue;
  if (isAddress(deployedValue ?? "", { strict: false })) return deployedValue;
  return "";
}

export const GOVERNOR_ADDRESS = pickAddress(
  import.meta.env.VITE_GOVERNOR_ADDRESS,
  localDeployment.governor,
);
export const TOKEN_ADDRESS = pickAddress(
  import.meta.env.VITE_GOVERNANCE_TOKEN_ADDRESS,
  localDeployment.governanceToken,
);
export const TREASURY_ADDRESS = pickAddress(
  import.meta.env.VITE_TREASURY_ADDRESS,
  localDeployment.treasury,
);
// Governor is the one address every page needs; the other two are needed for
// the payout proposal flow and the balance stat.
export const ADDRESSES_CONFIGURED = Boolean(GOVERNOR_ADDRESS && TOKEN_ADDRESS && TREASURY_ADDRESS);

export const wagmiConfig = getDefaultConfig({
  appName: "Governance DApp",
  projectId: import.meta.env.VITE_WALLETCONNECT_PROJECT_ID || "demo-project-id",
  chains: [anvilChain, sepoliaChain],
  transports: {
    [anvilChain.id]: http("http://127.0.0.1:8545"),
    [sepoliaChain.id]: http(),
  },
});

export { GOVERNOR_ABI, GOVERNANCE_TOKEN_ABI, TREASURY_ABI };
