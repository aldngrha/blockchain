import { http } from "wagmi";
import { defineChain, isAddress } from "viem";
import { sepolia } from "wagmi/chains";
import { getDefaultConfig } from "@rainbow-me/rainbowkit";
import localDeployment from "virtual:local-deployment";
import { DEX_PAIR_ABI, ERC20_ABI } from "./abi";

// wagmi's built-in `localhost` chain has id 1337, but anvil's default chain id
// is 31337. This repo runs anvil on port 8548 on purpose (see the root README,
// "Deploy lokal"), so the chain def and transport both target that port.
export const anvilChain = defineChain({
  id: 31337,
  name: "Anvil",
  nativeCurrency: { name: "Anvil Ether", symbol: "ETH", decimals: 18 },
  rpcUrls: { default: { http: ["http://127.0.0.1:8548"] } },
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

export const TOKEN_A_ADDRESS = pickAddress(
  import.meta.env.VITE_TOKEN_A_ADDRESS,
  localDeployment.tokenA,
);
export const TOKEN_B_ADDRESS = pickAddress(
  import.meta.env.VITE_TOKEN_B_ADDRESS,
  localDeployment.tokenB,
);
export const PAIR_ADDRESS = pickAddress(
  import.meta.env.VITE_DEX_PAIR_ADDRESS,
  localDeployment.dexPair,
);
export const ADDRESSES_CONFIGURED = Boolean(TOKEN_A_ADDRESS && TOKEN_B_ADDRESS && PAIR_ADDRESS);

export const wagmiConfig = getDefaultConfig({
  appName: "SimpleDex",
  projectId: import.meta.env.VITE_WALLETCONNECT_PROJECT_ID || "demo-project-id",
  chains: [anvilChain, sepoliaChain],
  transports: {
    [anvilChain.id]: http("http://127.0.0.1:8548"),
    [sepoliaChain.id]: http(),
  },
});

export { DEX_PAIR_ABI, ERC20_ABI };
