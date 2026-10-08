/**
 * May 25 — ethers.js v6 Fundamentals
 * 
 * Yang dipelajari hari ini:
 * 1. Provider — koneksi ke blockchain
 * 2. Wallet/Signer — manage private key
 * 3. Reading data dari blockchain
 * 4. Basic contract interaction
 */

const { ethers } = require("ethers");

// ================================================================
// 1. PROVIDER — Gateway ke Blockchain
// ================================================================

/**
 * Provider = koneksi ke Ethereum node
 * Bisa pakai: Infura, Alchemy, Anvil (local), MetaMask
 * 
 * Provider = READ-ONLY (tidak perlu private key)
 */

// Public provider (gratis, rate-limited)
const publicProvider = new ethers.JsonRpcProvider("https://eth.llamarpc.com");

// Local provider (Anvil/Foundry)
// const localProvider = new ethers.JsonRpcProvider("http://127.0.0.1:8545");

// Sepolia testnet provider
const sepoliaProvider = new ethers.JsonRpcProvider(
  "https://rpc.sepolia.org"
);

async function demonstrateProvider() {
  console.log("=== PROVIDER ===\n");

  // Get latest block
  const block = await publicProvider.getBlock("latest");
  console.log("Latest block number:", block.number);
  console.log("Block timestamp:", new Date(block.timestamp * 1000).toISOString());

  // Get chain ID
  const network = await publicProvider.getNetwork();
  console.log("Chain ID:", network.chainId.toString());
  console.log("Network name:", network.name);

  // Get ETH balance (Vitalik's address)
  const vitalik = "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045";
  const balance = await publicProvider.getBalance(vitalik);
  console.log("Vitalik balance:", ethers.formatEther(balance), "ETH");
}

// ================================================================
// 2. WALLET / SIGNER — Private Key Management
// ================================================================

/**
 * Wallet/Signer = bisa SIGN transactions (write ke blockchain)
 * Butuh: private key
 * 
 * JANGAN pernah hardcode private key di production!
 */

function demonstrateWallet() {
  console.log("\n=== WALLET / SIGNER ===\n");

  // Generate random wallet (untuk testing)
  const randomWallet = ethers.Wallet.createRandom();
  console.log("Random wallet address:", randomWallet.address);
  console.log("Private key:", randomWallet.privateKey.slice(0, 10) + "...");

  // Create wallet dari private key
  // const wallet = new ethers.Wallet("0x...", provider);

  // Connect wallet ke provider (bisa sign + read)
  // const connectedWallet = wallet.connect(provider);

  console.log("\n⚠️ JANGAN share private key ke siapapun!");
}

// ================================================================
// 3. READING DATA DARI BLOCKCHAIN
// ================================================================

/**
 * Membaca data dari smart contract (tidak butuh private key)
 * Semua fungsi view/pure bisa dipanggil via provider
 */

// Contoh: SimpleStorage contract di Sepolia
// Ganti address ini dengan contract yang sudah lo deploy
const SIMPLE_STORAGE_ADDRESS = "0xYOUR_CONTRACT_ADDRESS";

// ABI (Application Binary Interface) — interface kontrak
const SIMPLE_STORAGE_ABI = [
  "function retrieve() view returns (uint256)",
  "function store(uint256 newValue)",
];

async function demonstrateReadContract() {
  console.log("\n=== READ CONTRACT ===\n");

  // Cara 1: Baca langsung dari provider (read-only)
  const contract = new ethers.Contract(
    SIMPLE_STORAGE_ADDRESS,
    SIMPLE_STORAGE_ABI,
    publicProvider
  );

  try {
    const value = await contract.retrieve();
    console.log("Stored value:", value.toString());
  } catch (error) {
    console.log("Contract belum di-deploy atau address salah");
    console.log("Ganti SIMPLE_STORAGE_ADDRESS di file ini");
  }

  // Cara 2: Baca balance address
  const balance = await publicProvider.getBalance(SIMPLE_STORAGE_ADDRESS);
  console.log("Contract ETH balance:", ethers.formatEther(balance));
}

// ================================================================
// 4. WRITING DATA (Butuh Signer)
// ================================================================

/**
 * Menulis data ke blockchain = butuh private key + bayar gas
 * Hanya bisa dilakukan oleh Wallet/Signer
 */

async function demonstrateWriteContract() {
  console.log("\n=== WRITE CONTRACT ===\n");

  // ⚠️ Untuk demo ini, lo butuh:
  // 1. Private key (dari Anvil test account)
  // 2. Contract yang sudah di-deploy

  // Anvil default account #0
  // Private key: 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
  const ANVIL_RPC = "http://127.0.0.1:8545";
  const provider = new ethers.JsonRpcProvider(ANVIL_RPC);

  // Get signer from provider (Anvil unlocked accounts)
  const signer = await provider.getSigner(0);
  console.log("Signer address:", await signer.getAddress());

  // Connect contract ke signer (bisa write)
  const contract = new ethers.Contract(
    SIMPLE_STORAGE_ADDRESS,
    SIMPLE_STORAGE_ABI,
    signer
  );

  try {
    // Send transaction
    const tx = await contract.store(42);
    console.log("Transaction hash:", tx.hash);

    // Wait for confirmation
    const receipt = await tx.wait();
    console.log("Confirmed in block:", receipt.blockNumber);
    console.log("Gas used:", receipt.gasUsed.toString());
  } catch (error) {
    console.log("Write failed:", error.message);
  }
}

// ================================================================
// 5. HELPER FUNCTIONS
// ================================================================

/**
 * Utility functions yang sering dipakai di ethers.js v6
 */

function demonstrateHelpers() {
  console.log("\n=== HELPER FUNCTIONS ===\n");

  // Convert between units
  const oneEth = ethers.parseEther("1.0");      // 1 ETH → wei
  const oneGwei = ethers.parseGwei("1.0");      // 1 Gwei → wei
  const backToEth = ethers.formatEther(oneEth); // wei → ETH string

  console.log("1 ETH =", oneEth.toString(), "wei");
  console.log("1 Gwei =", oneGwei.toString(), "wei");
  console.log("Back to ETH:", backToEth);

  // Hashing
  const hash = ethers.keccak256(ethers.toUtf8Bytes("Hello Ethereum"));
  console.log("keccak256('Hello Ethereum'):", hash);

  // Address validation
  const validAddress = ethers.isAddress("0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045");
  console.log("Is valid address:", validAddress);

  // Encode function call
  const encoded = ethers.Interface.encodeFunctionData("store", [42]);
  console.log("Encoded store(42):", encoded);
}

// ================================================================
// RUN
// ================================================================

async function main() {
  try {
    await demonstrateProvider();
    demonstrateWallet();
    await demonstrateReadContract();
    // demonstrateWriteContract(); // Uncomment kalau Anvil running
    demonstrateHelpers();
  } catch (error) {
    console.error("Error:", error.message);
  }
}

main();
