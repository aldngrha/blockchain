# 🎯 Cyfrin Grand Review — Semua Patterns yang Dipelajari

> Review lengkap semua Solidity patterns dari Cyfrin course.
> Ini referensi cepat saat mau recall suatu pattern.

---

## 1. ACCESS CONTROL PATTERNS

### Ownable
```solidity
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
contract MyContract is Ownable {
    function sensitiveAction() external onlyOwner { }
}
```
**Kapan pakai:** 1 admin/owner

### AccessControl (RBAC)
```solidity
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
contract MyContract is AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    constructor() { _grantRole(DEFAULT_ADMIN_ROLE, msg.sender); }
    function mint() external onlyRole(MINTER_ROLE) { }
}
```
**Kapan pakai:** Multiple roles (minter, burner, pauser)

---

## 2. TOKEN STANDARDS

### ERC-20 (Fungible Token)
```solidity
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
contract MyToken is ERC20 {
    constructor() ERC20("MyToken", "MTK") { _mint(msg.sender, 1_000_000e18); }
}
```

### ERC-721 (Non-Fungible Token)
```solidity
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
contract MyNFT is ERC721 {
    uint256 private _tokenIdCounter;
    constructor() ERC721("MyNFT", "MNFT") {}
    function mint(address to) external { _safeMint(to, _tokenIdCounter++); }
}
```

### ERC-1155 (Multi-Token)
```solidity
import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
contract MyMultiToken is ERC1155 {
    constructor() ERC1155("") {}
}
```
**Kapan pakai:** Fungible + NFT dalam 1 kontrak, hemat gas

---

## 3. SECURITY PATTERNS

### ReentrancyGuard
```solidity
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
contract Vault is ReentrancyGuard {
    function withdraw(uint256 amount) external nonReentrant { }
}
```

### Checks-Effects-Interactions (CEI)
```solidity
function withdraw(uint256 amount) external {
    // CHECKS
    require(balances[msg.sender] >= amount);
    // EFFECTS (state update DULU)
    balances[msg.sender] -= amount;
    // INTERACTIONS (external call TERAKHIR)
    (bool success,) = msg.sender.call{value: amount}("");
}
```

### Pull Payment
```solidity
mapping(address => uint256) public pendingPayments;
function withdraw() public nonReentrant {
    uint256 amount = pendingPayments[msg.sender];
    pendingPayments[msg.sender] = 0; // Effect sebelum interaction
    payable(msg.sender).call{value: amount}("");
}
```

---

## 4. GAS OPTIMIZATION

| Technique | Savings | Example |
|-----------|---------|---------|
| Bitmap | 99%+ | `uint256` untuk 256 boolean flags |
| Storage Packing | 50%+ | `uint128 + uint128` = 1 slot |
| Custom Errors | 85% | `error Foo()` vs `require(cond, "msg")` |
| Immutable | 99.8% | `uint256 immutable x` vs `uint256 x` |
| Unchecked Math | ~200 gas/iter | `unchecked { i++; }` untuk safe increments |
| Calldata vs Memory | 30% | `string calldata` untuk read-only params |
| Constant | 100% | `uint256 constant X = 42` (embedded in bytecode) |

---

## 5. DESIGN PATTERNS

### Proxy (Upgradeable)
```
User → Proxy (state) → Implementation (code, bisa diganti)
```
**Rule:** Storage layout HARUS identik antar version!

### Factory Pattern
```solidity
function createContract() external returns (address) {
    return new MyContract();
}
```

### Oracle Pattern (Chainlink)
```solidity
import {AggregatorV3Interface} from "@chainlink/contracts/...";
(, int256 price,,,) = priceFeed.latestRoundData();
```

---

## 6. DEFINITIVE CHEAT SHEET

```
✅ Pakai custom errors, bukan string require
✅ Pakai immutable/constant untuk data yang gak berubah
✅ Pakai calldata bukan memory untuk read-only params
✅ Pakai unchecked {} untuk safe increments
✅ Pakai ReentrancyGuard untuk fungsi transfer ETH
✅ Pakai CEI pattern: Checks → Effects → Interactions
✅ Pakai slither untuk static analysis
✅ Pakai forge test --fuzz-runs 1000 untuk fuzz testing

❌ JANGAN pakai tx.origin untuk auth
❌ JANGAN pakai block.timestamp untuk randomness
❌ JANGAN pakai delegatecall ke untrusted contracts
❌ JANGAN update state SETELAH external call (reentrancy!)
❌ JANGAN hardcode addresses (kecuali precompile)
❌ JANGAN use floating pragma (pin versi!)
```

---

## 📊 PROGRESS SUMMARY

| Section | Topic | Status |
|---------|-------|--------|
| Foundry 1 | SimpleStorage | ✅ |
| Foundry 2 | FundMe | ✅ |
| Foundry 3 | Frontend | ⚠️ |
| Foundry 4 | Raffle | ✅ |
| Advanced 1 | ERC-20 | ✅ |
| Advanced 2 | NFT | ✅ |
| Advanced 3 | DeFi Stablecoin | ✅ |
| Advanced 4 | Cross-Chain Rebase | ⚠️ |
| Advanced 5 | Merkle + Signatures | ✅ |
| Advanced 6 | Proxy/Upgrades | ✅ |
| Advanced 7 | Account Abstraction | ⚠️ |
| Advanced 8 | DAO/Governance | ✅ |
| Advanced 9 | Security/Auditing | ✅ |
| Practice | Gas Optimization | ✅ |
| Practice | Access Control | ✅ |
| Practice | Pull Payment | ✅ |
| Practice | ERC-1155 | ✅ (just added) |
| Practice | Events Deep Dive | ✅ (just added) |
| Practice | Assembly/Low-Level | ✅ (just added) |
| Practice | Gas Advanced | ✅ (just added) |
