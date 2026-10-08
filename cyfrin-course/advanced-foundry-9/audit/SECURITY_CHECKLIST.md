# Smart Contract Security Checklist

> Gunakan checklist ini saat audit smart contract.
> Setiap item harus dicek dan di-note statusnya.

---

## 1. ACCESS CONTROL

- [ ] Semua fungsi sensitif punya access control yang benar
- [ ] Owner/admin bisa di-rotate jika compromised
- [ ] Tidak ada fungsi yang seharusnya `onlyOwner` tapi `public`
- [ ] `tx.origin` tidak digunakan untuk authentication ( pakai `msg.sender`)
- [ ] Role-based access control (RBAC) digunakan jika ada banyak role
- [ ] Initializer bisa dipanggil ulang (re-initialization attack)

## 2. REENTRANCY

- [ ] Semua external call dilakukan SETELAH state update (CEI pattern)
- [ ] `ReentrancyGuard` digunakan pada fungsi yang transfer ETH
- [ ] `receive()` dan `fallback()` tidak punya logic berbahaya
- [ ] Cross-function reentrancy dipertimbangkan
- [ ] Cross-contract reentrancy dipertimbangkan

## 3. INTEGER MATH

- [ ] Solidity >=0.8.0 (auto overflow/underflow check)
- [ ] Jika pakai `unchecked {}`, pastikan aman
- [ ] Division sebelum multiplication (untuk precision)
- [ ] Tidak ada precision loss yang signifikan
- [ ] `type(uint256).max` tidak bisa di-exploit

## 4. TOKEN INTERACTIONS

- [ ] ERC20 `transfer()` return value di-check
- [ ] ERC721 `safeTransferFrom()` return value di-check
- [ ] Tidak ada假 token (fake token) yang bisa di-deploy
- [ ] Token approval pattern aman dari front-running

## 5. EXTERNAL CALLS

- [ ] Semua return value dari external call di-check
- [ ] `call{value: amount}("")` digunakan bukan `transfer()` atau `send()`
- [ ] Gas limit cukup untuk external call
- [ ] Callback functions aman dari reentrancy

## 6. ORACLE INTERACTIONS

- [ ] Price feed menggunakan Chainlink (bukan DEX spot price)
- [ ] Oracle data freshness di-check (stale data check)
- [ ] Oracle manipulation resistance di-test
- [ ] Multi-oracle pattern digunakan jika kritis

## 7. DEFI-SPECIFIC

- [ ] Flash loan attack resistance di-test
- [ ] Price manipulation resistance di-test
- [ ] Sandwich attack resistance dipertimbangkan
- [ ] Health factor / liquidation logic benar
- [ ] Slippage protection ada

## 8. UPGRADABLE CONTRACTS

- [ ] Storage layout compatible antar version
- [ ] Tidak ada storage collision
- [ ] Initializer hanya bisa dipanggil sekali
- [ ] `__gap` variable ada untuk future storage
- [ ] Upgrade delay/timelock ada

## 9. GAS OPTIMIZATION

- [ ] Tidak ada loop yang bisa DoS (unbounded loops)
- [ ] Storage packing optimal
- [ ] `calldata` digunakan bukan `memory` untuk read-only params
- [ ] `unchecked {}` digunakan untuk safe increments
- [ ] Custom errors digunakan bukan string require

## 10. GENERAL

- [ ] Semua state changes emit events
- [ ] Tidak ada hardcoded addresses (kecuali precompile)
- [ ] Solc version di-pin (bukan floating pragma)
- [ ] License identifier ada
- [ ] NatSpec documentation lengkap
- [ ] `selfdestruct` tidak digunakan
- [ ] `delegatecall` aman (hanya ke trusted contracts)

---

## Severity Classification

| Severity | Impact | Likelihood | Example |
|----------|--------|------------|---------|
| 🔴 Critical | Total fund loss, contract bricked | High | Reentrancy, Access control bypass |
| 🟠 High | Significant fund loss possible | Medium | Oracle manipulation, Flash loan attack |
| 🟡 Medium | Limited impact, edge case | Medium | Front-running, Timestamp dependence |
| 🔵 Low | Minor issue, best practice | Low | Missing event, Gas waste |
| ℹ️ Info | Informational, no impact | N/A | Code style, Documentation |

---

## Tools Checklist

- [ ] `forge build` — Compile tanpa error
- [ ] `forge test` — Semua test passed
- [ ] `slither .` — Static analysis
- [ ] `forge test --fuzz-runs 1000` — Fuzz testing
- [ ] `forge coverage` — Test coverage > 90%
- [ ] Manual review — Line-by-line review
