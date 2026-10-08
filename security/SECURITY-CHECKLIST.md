# Personal Security Checklist

**Updated:** Sep 8, 2026
**Purpose:** Checklist personal untuk review kontrak sebelum deploy

---

## 🔴 CRITICAL (Harus dicek SETIAP KALI)

```
ACCESS CONTROL:
  □ Semua admin functions punya modifier
  □ Owner bisa di-transfer dengan aman (two-step)
  □ Tidak ada tx.origin untuk auth
  □ Role-based access untuk multi-user

REENTRANCY:
  □ External call di SETELAH state update
  □ ReentrancyGuard dipasang
  □ Return value dari call() di-check
  □ Tidak ada cross-function reentrancy

ARITHMETIC:
  □ Solidity 0.8+ atau SafeMath
  □ Tidak ada unchecked{} tanpa alasan
  □ Batch operations aman dari overflow
  □ Tidak ada division by zero
```

---

## 🟠 HIGH (Dicek sebelum deploy)

```
EXTERNAL CALLS:
  □ Semua return value di-handle
  □ Try/catch untuk high-level calls
  □ Gas limits untuk external calls
  □ Tidak ada callback manipulation

TOKEN INTERACTIONS:
  □ SafeERC20 untuk ERC-20 transfers
  □ Return value dari transfer di-check
  □ Approval handling yang benar
  □ Tidak ada unlimited approvals

PROXY PATTERNS:
  □ Storage collision di-check
  □ Initializer dipanggil
  □ Upgrade bisa dilakukan dengan aman
  □ Siapa yang bisa upgrade terbatas
```

---

## 🟡 MEDIUM (Best practices)

```
GAS OPTIMIZATION:
  □ Calldata untuk read-only
  □ Variable packing
  □ Immutable untuk constants
  □ Batch operations

ERROR HANDLING:
  □ Custom errors untuk hemat gas
  □ Pesan error yang jelas
  □ Panic untuk invariant violations
  □ Semua error di-handle

EVENTS:
  □ Semua state changes punya event
  □ Indexed parameters untuk filtering
  □ Event names konsisten
  □ Data lengkap untuk off-chain
```

---

## 🔵 LOW (Nice to have)

```
CODE QUALITY:
  □ NatSpec comments lengkap
  □ Naming conventions konsisten
  □ Tidak ada dead code
  □ Functions di-organize dengan baik

TESTING:
  □ Unit tests untuk semua fungsi
  □ Edge cases di-test
  □ Fuzz testing dilakukan
  □ Coverage > 95%

DOCUMENTATION:
  □ README lengkap
  □ Deployment guide
  □ Architecture diagram
  □ Emergency procedures
```

---

## SLITHER SCANNING

```
SEBELUM SETIAP DEPLOY:
  □ Slither scan: 0 HIGH findings
  □ Slither scan: 0 MEDIUM findings
  □ Review semua warnings
  □ Fix atau document semua findings
```

---

## EMERGENCY PREPAREDNESS

```
PAUSE MECHANISM:
  □ Contract bisa di-pause
  □ Hanya admin yang bisa pause
  □ Pause menghentikan semua operasi
  □ Emergency withdraw tersedia

MULTI-SIG:
  □ Admin address = multi-sig
  □ Threshold minimum 2/3
  □ Time delay untuk transaksi besar
  □ Recovery plan tersedia

UPGRADE PLAN:
  □ Upgrade bisa dilakukan dengan aman
  □ Storage layout tidak berubah
  □ Test upgrade di testnet
  □ Rollback plan tersedia
```

---

## AUDIT PREPARATION

```
SEBELUM AUDIT:
  □ Semua tests pass
  □ Coverage > 95%
  □ Slither clean (0 high/medium)
  □ Documentation lengkap
  □ Code freeze (tidak ada perubahan)

DURING AUDIT:
  □ Responsive terhadap pertanyaan
  □ Document semua keputusan design
  □ Jangan defend — listen and fix
  □ Take notes untuk learning

AFTER AUDIT:
  □ Fix semua HIGH findings
  □ Fix atau document MEDIUM findings
  □ Update documentation
  □ Publish audit report
```
