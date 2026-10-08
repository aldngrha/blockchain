# Project 2: Governance dApp: Spesifikasi Final

> Status: **FINAL** (Spec + Architecture, Sen 21 Sep 2026)
> Implementasi mulai Sel 22 Sep (GovernanceToken) sesuai ROADMAP.md.
> Research Compound Bravo vs OZ Governor ada di `docs/research-governance.md`.

---

## 1. Goal & Non-Goals

**Goal:** Governance stack minimal tapi production-pattern: token dengan voting checkpoint (ERC20Votes), Governor OZ v5 dengan quorum dinamis, TimelockController, dan Treasury ETH yang hanya bisa dikuras lewat proposal yang lolos. Portfolio item kedua, pasangan Project 1 yang di SPEC-nya gugur soal "gak ada timelock/governance (itu Project 2)".

**Non-Goals (v1):**
- Gak ada vote signature / gasless voting (`castVoteBySig` ada gratis di OZ, tapi gak dites eksplisit).
- Gak ada ERC721Votes / multi-token voting weight.
- Gak ada subgraph deploy (code siap, butuh akun The Graph Studio; lihat `subgraph/README.md`).
- Gak ada frontend di repo ini (folder `frontend/` dikerjakan agent lain, ada kontraknya di sini).
- Gak ada upgradeability. Kontraknya final, ganti timelock masih bisa lewat `updateTimelock()` via proposal.

**Pola utama yang dilatih:** inheritance matrix OZ v5 (5 mixin Governor), AccessControl role wiring, checkpoint voting (ERC20Votes), quorum dari past supply, dan pola "deployer renounce, lalu governance jadi satu-satunya pemegang kendali".

---

## 2. Arsitektur

```
                    delegate()                    propose() / queue() / execute() / cancel()
  ┌──────────────────────┐  IVotes   ┌────────────────────────────────┐
  │   GovernanceToken    │──────────►│        GovernorContract        │
  │  ERC20 + Permit +    │           │  Governor + Settings + Simple  │
  │  ERC20Votes          │           │  + QuorumFraction + TimelockCtl│
  └──────────────────────┘           └───────────────┬────────────────┘
        1.000.000 GT fixed, gak ada owner            │ PROPOSER_ROLE + CANCELER_ROLE
                                                     │ (EXECUTOR_ROLE open ke address(0))
                                                     ▼
                                     ┌────────────────────────────────┐
                                     │       TimelockController       │
                                     │  minDelay = 1 hari (produksi)  │
                                     └───────────────┬────────────────┘
                                                     │ satu-satunya pemanggil execute()
                                                     ▼
                                     ┌────────────────────────────────┐
                                     │            Treasury            │
                                     │  receive() ETH + execute()     │
                                     └────────────────────────────────┘
```

Prinsip kepemilikan:

- **GovernanceToken**: fixed supply 1.000.000 GT ke deployer, gak ada owner, gak ada minter. Voting power aktif hanya setelah `delegate()`.
- **GovernorContract**: logika voting murni, gak pegang dana.
- **TimelockController**: satu-satunya kontrak yang bisa mengeksekusi operasi ke dunia luar. Setelah deployer renounce admin, kontrak ini self-administered: mengubah apapun di timelock harus lewat proposal.
- **Treasury**: ETH vault. `execute(address payable to, uint256 amount)` hanya bisa dipanggil timelock (guard `msg.sender == timelock`, address immutable).

Flow proposal "kuras 1 ETH dari Treasury ke recipient":

```
propose([treasury], [0], [abi.encodeCall(Treasury.execute, (recipient, 1 ETH))], "...")
  -> vote -> queue() -> tunggu minDelay -> execute() -> timelock memanggil Treasury.execute
```

---

## 3. GovernanceToken

Solidity `^0.8.20`, OZ v5.4 (`ERC20`, `ERC20Permit`, `ERC20Votes`).

### State
| Var | Tipe | Catatan |
|---|---|---|
| `INITIAL_SUPPLY` | `uint256` constant | `1_000_000e18` |

### Functions
| Signature | Access | Behavior |
|---|---|---|
| `constructor()` | internal | name `"Governance Token"`, symbol `"GT"`, mint 1.000.000 GT ke `msg.sender` (deployer) |
| `ERC-20 standar` | any | transfer/approve/transferFrom bawaan OZ |
| `permit(...)` | any | approve via EIP-2612 (ERC20Permit) |
| `delegate(address)`, `delegateBySig(...)` | any | aktivasi/redirect voting power |
| `getVotes`, `getPastVotes`, `getPastTotalSupply`, `delegates`, `nonces` | view | bacaan buat Governor + frontend |

### Override wajib (sumber compile error paling sering)
| Fungsi | Dari | Kenapa |
|---|---|---|
| `_update(address,address,uint256)` | `ERC20` + `ERC20Votes` | ERC20Votes menjuntai checkpoint di setiap pergerakan token |
| `nonces(address)` | `ERC20Permit` + `Nonces` | Votes juga warisin Nonces, bentrok |

### Error / Event
- Bawaan OZ (`ERC20InsufficientBalance`, `ERC5805FutureLookup`, dst). Gak ada custom error.
- Event standar + `DelegateChanged`, `DelegateVotesChanged`.

---

## 4. GovernorContract

Solidity `^0.8.24` (syarat OZ v5.4 `Governor.sol`), OZ v5.4.

### Inheritance (urutan ini yang dipakai)
```
Governor, GovernorSettings, GovernorCountingSimple,
GovernorVotes (via QuorumFraction), GovernorVotesQuorumFraction, GovernorTimelockControl
```

### Constructor
```solidity
constructor(
    IVotes _votes,              // GovernanceToken
    TimelockController _timelock,
    uint256 _quorumPercentage,  // 4
    uint256 _votingDelay,       // 7200 block (1 hari)
    uint256 _votingPeriod       // 50400 block (1 minggu)
)
    Governor("Governance DApp Governor")
    GovernorSettings(uint48(_votingDelay), uint32(_votingPeriod), 0) // threshold 0
    GovernorCountingSimple()
    GovernorVotes(_votes)
    GovernorVotesQuorumFraction(_quorumPercentage)
    GovernorTimelockControl(_timelock)
```

### Override matrix yang dibutuhkan Solidity (hasil eksperimen compile, bukan tebak-tebakan)
| Fungsi | Override dari | Wajib? |
|---|---|---|
| `state(uint256)` | `Governor` + `GovernorTimelockControl` | YA (dua-duanya concrete) |
| `proposalNeedsQueuing(uint256)` | idem | YA |
| `proposalThreshold()` | `Governor` + `GovernorSettings` | YA: core Governor punya default body `return 0`, jadi bukan abstract murni |
| `_queueOperations(...)`, `_executeOperations(...)`, `_cancel(...)`, `_executor()` | `Governor` + `GovernorTimelockControl` | YA |
| `votingDelay()`, `votingPeriod()`, `quorum(uint256)` | core vs Settings/QuorumFraction | GAK: di core mereka abstract tanpa body, linearization otomatis ambil versi modul |

### Semantik state (GovernorCountingSimple + QuorumFraction)
| State | Syarat |
|---|---|
| `Pending` | block < snapshot (`clock() + votingDelay`) |
| `Active` | snapshot <= block <= deadline |
| `Succeeded` | lewat deadline DAN `for + abstain >= quorum(snapshot)` DAN `for > against` |
| `Defeated` | lewat deadline, salah satu syarat di atas gagal |
| `Queued` | sudah `queue()`, operasi timelock masih `Waiting`/`Ready` |
| `Executed` / `Canceled` | via timelock (`isOperationDone`) / cancel |
| `Expired` | OZ v5 core gak implementasi grace period expired otomatis (beda dengan Bravo) |

Quorum: `quorum(snapshot) = getPastTotalSupply(snapshot) * 4 / 100`. Dengan supply 1.000.000 GT = 40.000 GT.

---

## 5. TimelockController + Treasury

### TimelockController (OZ v5.4, dipakai apa adanya)
- Constructor: `(minDelay, proposers[], executors[], admin)`. Proposers di constructor otomatis dapat `PROPOSER_ROLE` + `CANCELER_ROLE`.
- `DEFAULT_ADMIN_ROLE` diberikan ke timelock itu sendiri (self-admin) + ke `admin` kalau bukan nol.
- Wiring project 2: `proposers = []`, `executors = []`, `admin = deployer` saat deploy, lalu grant manual:
  - `PROPOSER_ROLE` -> governor
  - `CANCELER_ROLE` -> governor
  - `EXECUTOR_ROLE` -> `address(0)` (open: siapa pun boleh mengeksekusi operasi yang sudah dischedule)
  - deployer `renounceRole(DEFAULT_ADMIN_ROLE)` TERAKHIR. Sejak titik ini gak ada jalan pintas.

### Treasury (custom, src/Treasury.sol)
| Signature | Access | Behavior |
|---|---|---|
| `constructor(address timelock_)` | internal | set `timelock` immutable |
| `receive() external payable` | any | terima ETH (funding dari siapa pun) |
| `execute(address payable to, uint256 amount)` | **hanya timelock** | kirim ETH, revert `Treasury__OnlyTimelock` kalau bukan, `Treasury__ExecutionFailed` kalau call gagal |
| `getBalance()` | view | saldo vault |

### Errors
- `Treasury__OnlyTimelock(address caller, address timelock)`
- `Treasury__ExecutionFailed(address to, uint256 amount)`
- Event: `TreasuryPaymentExecuted(address indexed to, uint256 amount)`

---

## 6. Edge Cases (daftar wajib test)

| # | Kasus | Expected |
|---|---|---|
| E1 | vote sebelum proposal aktif | Revert `GovernorUnexpectedProposalState` (Pending) |
| E2 | vote 2x oleh address yang sama | Revert `GovernorAlreadyCastVote` |
| E3 | vote oleh holder yang gak pernah delegate | Sukses tapi weight 0, tally gak berubah |
| E4 | quorum gak tercapai | `Defeated` setelah deadline; `queue()` revert |
| E5 | AGAINST > FOR padahal quorum tercapai | `Defeated` (majority kalah) |
| E6 | abstain ikut quorum, gak ikut majority | `Succeeded` jika for > against dan for+abstain >= quorum |
| E7 | `execute()` tanpa `queue()` | Governor meneruskan, timelock revert `TimelockUnexpectedOperationState` |
| E8 | `execute()` sebelum minDelay lewat | timelock revert `TimelockUnexpectedOperationState` (state Waiting) |
| E9 | proposer cancel saat Pending | `Canceled`; non-proposer cancel revert `GovernorUnableToCancel` |
| E10 | `treasury.execute()` oleh non-timelock | Revert `Treasury__OnlyTimelock` |
| E11 | transfer ke holder yang gak delegate | Voting power hilang sampai dia delegate (bukan revert) |
| E12 | lookup checkpoint di block sekarang/masa depan | Revert `ERC5805FutureLookup` |
| E13 | propose 2x dengan parameter persis sama | Revert `GovernorUnexpectedProposalState` (id sama, sudah ada) |
| E14 | deployer timelock sudah renounce | `hasRole(DEFAULT_ADMIN_ROLE, deployer) == false`, timelock self-admin |

Full flow happy path (E0): propose -> Pending -> Active -> vote FOR/FOR/AGAINST -> deadline -> Succeeded -> queue -> warp > minDelay -> execute -> saldo Treasury berkurang persis sebesar payout, recipient menerima.

---

## 7. Fuzz Test Plan (ringan, sesuai kontrak SPEC)

Stateless fuzz (bukan invariant suite, scope governance terlalu besar buat handler):

- **F1**: `governor.getVotes(a, tp) == token.getPastVotes(a, tp)` untuk amount/timepoint acak, DAN weight <= `getPastTotalSupply(tp)`. (Governor cuma cermin checkpoint token.)
- **F2**: `hashProposal` deterministik: parameter sama -> id sama; description beda -> id beda.
- **F3**: propose 2x dengan parameter sama revert (konsekuensi determinisme F2).

Konfigurasi: `[fuzz] runs = 256`, `[invariant] runs = 50 depth = 32` (foundry.toml).

---

## 8. Test Plan (mapping ke jadwal)

**Sel 22 Sep: GovernanceToken (test/GovernanceToken.t.sol, 14 test)**
Metadata, fixed supply, delegate self/other, transfer hanya mindah voting power setelah kedua pihak delegate, power hilang ke penerima yang gak delegate, historic lookup `getPastVotes`/`getPastTotalSupply` dengan vm.roll, future lookup revert, fuzz delegate.

**Rab 23 Sep + Kam 24 Sep: GovernorFullFlow (test/GovernorFullFlow.t.sol, 16 test)**
Wiring roles (proposer/canceler/executor/admin renounce), parameter governor, quorum 4%, full happy path propose->execute, E1 sampai E14.

**Min 27 Sep: subgraph (code only)**, **Sen 28 Sep: deploy + polish** (script + verifikasi anvil).

**Gate sebelum frontend:** `forge build` + `forge test` hijau penuh, deploy script verified di anvil, ABI subgraph ter-generate.

---

## 9. Deployment (Sen 28 Sep: lokal verified, Sepolia = langkah manual)

Urutan `script/DeployGovernance.s.sol`:

1. Deploy `GovernanceToken` (1.000.000 GT ke deployer).
2. Deploy `TimelockController(1 days, [], [], deployer)`.
3. Deploy `GovernorContract(token, timelock, 4, 7200, 50400)`.
4. Grant `PROPOSER_ROLE` + `CANCELER_ROLE` ke governor, `EXECUTOR_ROLE` ke `address(0)`.
5. Deployer renounce semua role timelock yang dia pegang (faktanya cuma DEFAULT_ADMIN).
6. Deploy `Treasury(timelock)`, fund 0.1 ETH.
7. `token.delegate(deployer)` (catatan jujur: demo single-delegate, lihat catatan keamanan).
8. Tulis `deployments/<chainId>.json` (format di bawah) + sanity assert post-deploy.

Format deployments JSON (sumber address buat frontend + subgraph):
```json
{"chainId":31337,"deployedAt":"1791296715387","deployer":"0xf39F...92266","contracts":{"GovernanceToken":"0x...","Timelock":"0x...","Governor":"0x...","Treasury":"0x..."}}
```

**Status Sepolia (jujur): belum dideploy.** Butuh private key user + RPC + Etherscan API key. Langkah manual:
```bash
export PRIVATE_KEY=0x<key user>
forge script script/DeployGovernance.s.sol \
  --rpc-url <SEPOLIA_RPC> --broadcast --verify --etherscan-api-key <KEY>
```

---

## 10. Catatan Keamanan

- **Timelock adalah satu-satunya executor.** Treasury guard `msg.sender == timelock` immutable. Governor sendiri gak bisa narik dana.
- **Admin renounce permanen.** Setelah renounce, gak ada upgrade path darurat. Ini disengaja.
- **Demo caveat: single-delegate.** Deploy script delegate seluruh 1M GT ke deployer: satu address bisa pass proposal apa pun. Untuk DAO sungguhan, distribusikan token DAN pastikan delegate tersebar SEBELUM governance dianggap live.
- **Threshold 0**: siapa pun bisa propose, termasuk bikin papan proposal penuh sampai DoS ringan UI. Untuk produksi, set `proposalThreshold > 0` lewat... ya, lewat proposal (`GovernorSettings.setProposalThreshold`).
- **EIP-170**: stack Governor v5 + via-ir + optimizer_runs rendah bisa lewat 24.576 bytes runtime. foundry.toml memakai `via_ir = true` + `optimizer_runs = 1000` (governor 16.405 bytes). Kalau ubah konfigurasi compiler, cek ukuran lagi.
- **`vm.roll` + via-ir**: di test, jangan pakai `block.number` turunan sebagai target roll lebih dari sekali per frame; optimizernya re-derive nilai turunannya di titik pemakaian. Detail di devlog 2026-09-22.

## 11. Definition of Done

- [x] `forge build` exit 0.
- [x] Semua test hijau: 33 test (14 token + 16 flow + 3 fuzz).
- [x] Edge case E1-E14 punya test eksplisit.
- [x] Deploy script verified di anvil (chainId 31337): roles, saldo, supply ter-verify via cast.
- [x] ABI subgraph ter-generate (`subgraph/abis/Governor.json`).
- [x] README + devlog.
- [ ] Deploy Sepolia + verifikasi Etherscan (butuh private key user, manual).
- [ ] Subgraph deploy ke The Graph Studio (butuh akun user).
