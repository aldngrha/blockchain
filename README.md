# Mini-Blockchain (Week 1 Fundamentals)

This project is a deep dive into the core fundamentals of blockchain technology, built from scratch using TypeScript and the Bun runtime.

## 🚀 Projects Included

This repository contains several modules that simulate different aspects of a blockchain:

### 1. **Core Blockchain (`blockchain.ts`)**
A minimal implementation of a blockchain including:
- **Hashing**: Using SHA-256 to secure block data.
- **Chaining**: Linking blocks via `previousHash`.
- **Proof of Work**: Mining blocks with adjustable difficulty (Nonce).
- **Validation**: A function to detect if the chain has been tampered with.

### 2. **Mining & Math Simulator (`math_test.ts`)**
A script to visualize the mathematical principles:
- **Deterministic Hashing**: Same input, same output.
- **Avalanche Effect**: Small changes in input lead to total change in output.
- **Probability**: Demonstrating why mining time increases exponentially with difficulty (16x per leading zero).

### 3. **Bitcoin Difficulty Simulator (`bitcoin_sim.ts`)**
A simulation of Bitcoin's dynamic difficulty adjustment:
- Watches the mining time of each block.
- Automatically increases/decreases difficulty to keep block times stable.

### 4. **Wallet Generator (`wallet.ts`)**
An Ethereum-compatible wallet generator using `viem`:
- Generates 12-word mnemonics (BIP-39).
- Derives valid EVM Addresses from private keys.

--- 

## 🛠️ Getting Started

### Prerequisites
- [Bun](https://bun.sh/) installed on your machine.

### Installation
```bash
bun install
