import { http } from "wagmi";
import { sepolia, mainnet } from "wagmi/chains";
import { getDefaultConfig } from "@rainbow-me/rainbowkit";
import abi from "./abi.json";

// Contract address — update after deploy
export const CONTRACT_ADDRESS = import.meta.env.VITE_CONTRACT_ADDRESS || "0x0000000000000000000000000000000000000000";
export const NFT_ABI = abi;

export const config = getDefaultConfig({
  appName: "Freebuff NFT Mint",
  projectId: import.meta.env.VITE_WALLETCONNECT_PROJECT_ID || "demo-project-id",
  chains: [sepolia, mainnet],
  transports: {
    [sepolia.id]: http(),
    [mainnet.id]: http(),
  },
});
