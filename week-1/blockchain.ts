import { createHash } from "crypto";

// ==========================================
// CLASS BLOCK
// ==========================================
class Block {
  public hash: string;
  public nonce: number = 0; // [MATH] Variabel acak untuk "tebakan" kita

  constructor(
    public index: number,
    public timestamp: string,
    public data: string,
    public previousHash: string,
  ) {
    this.hash = this.calculateHash();
  }

  // [MATH] Fungsi Hash sekarang mengikutkan 'nonce' dalam perhitungannya
  calculateHash(): string {
    return createHash("sha256")
      .update(
        this.index +
          this.timestamp +
          this.data +
          this.previousHash +
          this.nonce,
      )
      .digest("hex");
  }

  // [CORE/MATH] Fungsi Mining (Proof of Work)
  // Kita terus mencoba angka nonce sampai hash-nya diawali dengan jumlah '0' yang kita mau
  mineBlock(difficulty: number): void {
    const target = Array(difficulty + 1).join("0"); // Contoh: "000" kalau difficulty = 3

    console.log(`\n⛏️  Mining block #${this.index}...`);

    // Perulangan Brute Force (Mencoba satu-satu secara acak)
    while (this.hash.substring(0, difficulty) !== target) {
      this.nonce++; // Tambah angka tebakan
      this.hash = this.calculateHash(); // Hitung ulang hash-nya
    }

    console.log(`✅ Block Mined! Hash: ${this.hash}`);
    console.log(
      `💡 Nonce used : ${this.nonce} (It took ${this.nonce} attempts)`,
    );
  }
}

// ==========================================
// CLASS BLOCKCHAIN
// ==========================================
class Blockchain {
  private chain: Block[];
  public difficulty: number = 4; // [MATH] Tingkat kesulitan (Coba ganti ke 5 atau 6 untuk lihat bedanya)

  constructor() {
    this.chain = [this.createGenesisBlock()];
  }

  private createGenesisBlock(): Block {
    return new Block(0, new Date().toISOString(), "Genesis Block", "0");
  }

  getLatestBlock(): Block {
    return this.chain[this.chain.length - 1];
  }

  // [CORE] Menambah blok sekarang butuh proses "Mining"
  addBlock(data: string): void {
    const previousBlock = this.getLatestBlock();
    const newBlock = new Block(
      previousBlock.index + 1,
      new Date().toISOString(),
      data,
      previousBlock.hash,
    );

    // [CORE] Panggil fungsi mining sebelum blok dimasukkan ke rantai
    newBlock.mineBlock(this.difficulty);

    this.chain.push(newBlock);
  }

  isChainValid(): boolean {
    for (let i = 1; i < this.chain.length; i++) {
      const currentBlock = this.chain[i];
      const previousBlock = this.chain[i - 1];

      if (currentBlock?.hash !== currentBlock?.calculateHash()) {
        return false;
      }

      if (currentBlock?.previousHash !== previousBlock?.hash) {
        return false;
      }
    }
    return true;
  }
}

// ==========================================
// SIMULATION
// ==========================================

const myChain = new Blockchain();

// Set difficulty (Misal 4 nol di depan hash)
myChain.difficulty = 4;

console.log("Starting the miner...");
myChain.addBlock("Transfer: Aldi sends 50 ETH to Alice");
myChain.addBlock("Transfer: Alice sends 20 ETH to Bob");

console.log("\nStatus Keamanan:");
console.log("Is chain valid?", myChain.isChainValid());
