import { createWalletClient, http, hashMessage, isHex } from "viem";
import { privateKeyToAccount } from "viem/accounts";
import { mainnet } from "viem/chains";
import { createPublicClient } from "viem";

// ── 1. Buat account dari private key ──────────────────
// JANGAN pakai private key nyata — ini hanya untuk belajar!
const privateKey =
  "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80";

const account = privateKeyToAccount(privateKey);

console.log("Address :", account.address);

// ── 2. Sign pesan ─────────────────────────────────────
const message = "Aldi authorize: kirim 1 ETH ke Alice";

const signature = await account.signMessage({ message });

console.log("\nPesan    :", message);
console.log("Signature:", signature);

// ── 3. Verify signature ───────────────────────────────
const publicClient = createPublicClient({
  chain: mainnet,
  transport: http(),
});

const isValid = await publicClient.verifyMessage({
  address: account.address,
  message,
  signature,
});

console.log("\nSignature valid?", isValid); // true

// ── 4. Buktikan: signature palsu tidak bisa lolos ─────
const fakeSignatureRaw = "0x" + "a".repeat(130);
const fakeSignature = isHex(fakeSignatureRaw) ? fakeSignatureRaw : "0x";

const isFakeValid = await publicClient
  .verifyMessage({
    address: account.address,
    message,
    signature: fakeSignature,
  })
  .catch(() => false);

console.log("Fake signature valid?", isFakeValid); // false
