import { createHash } from "crypto";

// ==========================================
// BITCOIN DIFFICULTY SIMULATION
// ==========================================

function getHash(input: string) {
  return createHash("sha256").update(input).digest("hex");
}

function mine(difficulty: number, blockNumber: number) {
  const target = "0".repeat(difficulty);
  let nonce = 0;
  const start = Date.now();

  while (true) {
    const hash = getHash("Block" + blockNumber + nonce);
    if (hash.startsWith(target)) {
      const duration = (Date.now() - start) / 1000;
      return { nonce, duration, hash };
    }
    nonce++;
  }
}

// SIMULATION PARAMETERS
let currentDifficulty = 4; // Start easy
const TARGET_TIME = 2.0; // We want a block every 2 seconds (Simulation speed)
let totalTime = 0;
const blocksToMine = 10;

console.log(`=== BITCOIN SIMULATION START ===`);
console.log(`Target Block Time: ${TARGET_TIME}s\n`);

for (let i = 1; i <= blocksToMine; i++) {
  console.log(`Mining Block #${i} (Difficulty: ${currentDifficulty})...`);

  const result = mine(currentDifficulty, i);

  console.log(
    `  ✅ Mined! Nonce: ${result.nonce}, Time: ${result.duration.toFixed(3)}s`,
  );
  console.log(`  Proof: ${result.hash.substring(0, 20)}...`);

  // --- DIFFICULTY ADJUSTMENT LOGIC ---
  // If we're faster than target, increase difficulty.
  // If we're slower, decrease it.
  if (result.duration < TARGET_TIME * 0.5) {
    currentDifficulty++;
    console.log(
      `  📈 FASTER than target! Increasing Difficulty to: ${currentDifficulty}`,
    );
  } else if (result.duration > TARGET_TIME * 2.0 && currentDifficulty > 1) {
    currentDifficulty--;
    console.log(
      `  📉 SLOWER than target! Decreasing Difficulty to: ${currentDifficulty}`,
    );
  }

  totalTime += result.duration;
  console.log("------------------------------------------");
}

console.log(`\nSimulation Finished!`);
console.log(`Average Block Time: ${(totalTime / blocksToMine).toFixed(3)}s`);
