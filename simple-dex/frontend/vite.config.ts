import fs from "node:fs";
import { fileURLToPath, URL } from "node:url";
import react from "@vitejs/plugin-react";
import { defineConfig, type Plugin } from "vite";

const ADDRESS_RE = /^0x[0-9a-fA-F]{40}$/;

// Read deployments/31337.json (written by the Foundry deploy script at the repo
// root) so freshly deployed local addresses work without manual .env setup.
// A missing or malformed file resolves to empty strings; src/config.js treats
// those as "not configured" and the UI shows setup instructions.
function readLocalDeployment() {
  const file = fileURLToPath(new URL("../deployments/31337.json", import.meta.url));
  try {
    const raw = JSON.parse(fs.readFileSync(file, "utf8"));
    const contracts = raw?.contracts ?? {};
    return {
      tokenA: ADDRESS_RE.test(contracts.TokenA ?? "") ? contracts.TokenA : "",
      tokenB: ADDRESS_RE.test(contracts.TokenB ?? "") ? contracts.TokenB : "",
      dexPair: ADDRESS_RE.test(contracts.DexPair ?? "") ? contracts.DexPair : "",
    };
  } catch {
    return { tokenA: "", tokenB: "", dexPair: "" };
  }
}

// Expose the deployment addresses as a virtual module instead of a `define`
// global: Vite 8 applies custom identifier defines to builds only, so they do
// not reach the dev server. A plugin serves dev and build identically.
const VIRTUAL_LOCAL_DEPLOYMENT = "virtual:local-deployment";
const RESOLVED_VIRTUAL_LOCAL_DEPLOYMENT = `\0${VIRTUAL_LOCAL_DEPLOYMENT}`;

function localDeploymentPlugin(): Plugin {
  return {
    name: "local-deployment",
    resolveId(id) {
      if (id === VIRTUAL_LOCAL_DEPLOYMENT) return RESOLVED_VIRTUAL_LOCAL_DEPLOYMENT;
      return null;
    },
    load(id) {
      if (id === RESOLVED_VIRTUAL_LOCAL_DEPLOYMENT) {
        return `export default ${JSON.stringify(readLocalDeployment())};`;
      }
      return null;
    },
  };
}

export default defineConfig({
  plugins: [react(), localDeploymentPlugin()],
});
