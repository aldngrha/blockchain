# Smart Contract Security Best Practices

**Date:** Sep 8, 2026
**Source:** ConsenSys Best Practices + OpenZeppelin + Personal Checklist
**Purpose:** Review checklist sebelum deploy kontrak ke mainnet

---

## 1. ACCESS CONTROL

```
✅ DO:
  → Pakai OpenZeppelin Ownable untuk single owner
  → Pakai AccessControl untuk role-based permissions
  → Pakai modifier untuk restrict function access
  → Default: semua function harus restricted
  → Gunakan two-step ownership transfer

❌ DON'T:
  → Jangan pakai tx.origin untuk auth
  → Jangan hardcode owner address
  → Jangan biarkan constructor bisa dipanggil ulang
  → Jangan lupa restrict admin functions
```

```solidity
// GOOD: Role-based access
import "@openzeppelin/contracts/access/AccessControl.sol";

contract Vault is AccessControl {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
    }
    
    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }
}
```

---

## 2. REENTRANCY PROTECTION

```
✅ DO:
  → Apply Checks-Effects-Interactions (CEI) pattern
  → Pakai ReentrancyGuard dari OpenZeppelin
  → NonReentrant modifier di semua function yang kirim ETH
  → Update state SEBELUM external call
  → Check return value dari low-level call

❌ DON'T:
  → Jangan update state SETELAH external call
  → Jangan pakai transfer() (gas limit 2300)
  → Jangan pakai send() (gas limit 2300)
  → Pakai call{value: amount}("") dengan check return
```

```solidity
// GOOD: Checks-Effects-Interactions
function withdraw(uint256 amount) external nonReentrant {
    // CHECKS
    require(balances[msg.sender] >= amount, "Insufficient");
    
    // EFFECTS (update state DULU)
    balances[msg.sender] -= amount;
    
    // INTERACTIONS (kirim ETH TERAKHIR)
    (bool success,) = msg.sender.call{value: amount}("");
    require(success, "Transfer failed");
}
```

---

## 3. INTEGER SAFETY

```
✅ DO:
  → Selalu pakai Solidity 0.8+
  → Jangan pakai unchecked{} kecuali SANGAT yakin aman
  → Cek overflow sebelum operasi matematika
  → Pakai SafeMath untuk backward compatibility

❌ DON'T:
  → Jangan pakai Solidity <0.8 tanpa SafeMath
  → Jangan asumsi operasi aman
  → Jangan lupa cek batch operations
  → Jangan pakai tipe data yang terlalu kecil
```

---

## 4. EXTERNAL CALLS

```
✅ DO:
  → Cek return value dari semua external call
  → Pakai try/catch untuk high-level call
  → Limit gas untuk external call
  → Verifikasi msg.sender sebelum callback
  → Pakai Pull pattern, bukan Push

❌ DON'T:
  → Jangan trust return value dari external contract
  → Jangan panggil external contract dengan gas forwarding
  → Jangan kirim ETH ke address yang gak diketahui
  → Jangan biarkan callback memanipulasi state
```

---

## 5. STORAGE SECURITY

```
✅ DO:
  → Jangan simpan secrets di blockchain
  → Pahami storage layout untuk proxy contracts
  → Pakai mapping untuk akses by key
  → Gunakan events untuk data off-chain
  → Audit storage slots untuk upgradeable contracts

❌ DON'T:
  → Jangan hardcode private keys
  → Jangan simpan password di storage
  → Jangan asumsi "private" = aman
  → Jangan gunakan tx.origin untuk auth
```

---

## 6. PROXY PATTERNS

```
✅ DO:
  → Pakai OpenZeppelin Upgrades plugins
  → Pahami storage collision (EIP-1967)
  → Gunakan unstructured storage
  → Test upgrade sebelum deploy
  → Batasi siapa yang bisa upgrade

❌ DON'T:
  → Jangan ubah storage layout saat upgrade
  → Jangan lupa initalize (bukan constructor)
  → Jangan biarkan semua orang upgrade
  → Jangan upgrade tanpa testing
```

---

## 7. TOKEN STANDARDS

```
✅ DO:
  → Pakai OpenZeppelin ERC-20/ERC-721/ERC-1155
  → Implementasi sesuai EIP standard
  → Cek approval sebelum transferFrom
  → Pakai SafeERC20 untuk transfer
  → Handle return value dari token transfer

❌ DON'T:
  → Jangan implement send/transfer token manual
  → Jangan lupa cek return value
  → Jangan pakai approve(0) sebelum approve(amount)
  → Jangan biarkan unlimited approval
```

---

## 8. GAS OPTIMIZATION

```
✅ DO:
  → Pakai calldata untuk read-only parameters
  → Pack variables dalam 1 storage slot
  → Pakai immutable untuk constants
  → Gunakan unchecked{} untuk safe arithmetic
  → Batch operations untuk hemat gas

❌ DON'T:
  → Jangan pakai memory untuk read-only data
  → Jangan iterasi array besar on-chain
  → Jangan pakai string panjang di storage
  → Jangan lupa gas limits untuk loops
```

---

## 9. ERROR HANDLING

```
✅ DO:
  → Pakai require() untuk input validation
  → Pakai custom errors untuk hemat gas
  → Berikan pesan error yang jelas
  → Handle semua kemungkinan error
  → Panic untuk invariant violations

❌ DON'T:
  → Jangan pakai assert() untuk validasi input
  → Jangan biarkan error tanpa pesan
  → Jangan catch error tanpa处理
  → Jangan pakai revert() tanpa pesan
```

---

## 10. TESTING

```
✅ DO:
  → Test semua fungsi (unit tests)
  → Test edge cases (boundary tests)
  → Test dengan fuzzing (Foundry fuzz)
  → Test akses control (negative tests)
  → Achieve 100% coverage untuk critical paths

❌ DON'T:
  → Jangan deploy tanpa test suite
  → Jangan skip edge cases
  → Jangan test hanya happy path
  → Jangan lupa test reentrancy
```

---

## PRE-DEPLOY CHECKLIST

```
SEBELUM DEPLOY KE MAINNET:
═══════════════════════════════════════════════════════════════

✅ CODE QUALITY
  [ ] Semua code di-review
  [ ] Tidak ada TODO/FIXME
  [ ] Naming conventions konsisten
  [ ] Comments lengkap dan akurat

✅ TESTING
  [ ] Unit tests pass
  [ ] Integration tests pass
  [ ] Fuzz tests pass
  [ ] Coverage > 95%
  [ ] Edge cases covered

✅ SECURITY
  [ ] Slither scan: 0 HIGH findings
  [ ] Reentrancy protection aktif
  [ ] Access control terpasang
  [ ] Integer overflow protected (0.8+)
  [ ] External calls handled

✅ GAS OPTIMIZATION
  [ ] Gas profiling done
  [ ] Critical functions optimized
  [ ] Storage layout optimal
  [ ] Batch operations implemented

✅ DOCUMENTATION
  [ ] NatSpec comments lengkap
  [ ] README.md tersedia
  [ ] Deployment guide ada
  [ ] Emergency procedures documented

✅ DEPLOYMENT
  [ ] Testnet deploy & tested
  [ ] Etherscan verification siap
  [ ] Multi-sig untuk admin
  [ ] Upgrade plan documented
  [ ] Emergency pause mechanism
```

---

## EMERGENCY RESPONSE

```
KALAU ADA VULNERABILITY DITEMUKAN:
═══════════════════════════════════════════════════════════════

1. PAUSE
   → Aktifkan circuit breaker
   → Stop semua transaksi
   → Protect user funds

2. ASSESS
   → Apakah vulnerability bisa dieksploit?
   → Berapa banyak funds yang terdampak?
   → Siapa yang perlu diberitahu?

3. COMMUNICATE
   → Notify tim internal
   → Notify partner yang terdampak
   → Publish post-mortem

4. FIX
   → Develop fix di branch terpisah
   → Test di testnet
   → Deploy ke mainnet (jika upgradeable)
   → Verify fix bekerja

5. LEARN
   → Post-mortem report
   → Update security practices
   → Share lessons learned
```
