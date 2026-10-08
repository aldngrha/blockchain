import { createHash } from "crypto";

function getHash(input: string) {
  return createHash("sha256").update(input).digest("hex");
}

console.log("=== 1. DETERMINISTIC TEST ===");
console.log("Hash 'Block1':", getHash("Block1"));
console.log("Hash 'Block1':", getHash("Block1")); // Always the same!

console.log("\n=== 2. AVALANCHE EFFECT (One-Way Logic) ===");
const hash1 = getHash("Block1");
const hash2 = getHash("Block2");
console.log("Hash 'Block1':", hash1);
console.log("Hash 'Block2':", hash2);
console.log("Results are totally different even with 1 character change!");

console.log("\n=== 3. PROBABILITY TEST (Mining Simulation) ===");
function simulateMining(difficulty: number) {
  const target = "0".repeat(difficulty);
  let nonce = 0;
  const startTime = Date.now();

  while (true) {
    const hash = getHash("Data" + nonce);
    if (hash.startsWith(target)) {
      const duration = (Date.now() - startTime) / 1000;
      console.log(
        `Difficulty ${difficulty}: Found at nonce ${nonce} in ${duration}s`,
      );
      console.log(`  Proof Hash: ${hash}`);
      break;
    }
    nonce++; // Move nonce increment back INSIDE the loop
  }
}

// Experience the time difference as difficulty increases
simulateMining(1);
simulateMining(3);
simulateMining(6);

console.log("\n=== 4. CPU STRESS TEST (Mining Difficulty 7) ===");
console.log("Watch your Activity Monitor now...");
simulateMining(7);
