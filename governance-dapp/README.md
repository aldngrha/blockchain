# Governance dApp

Portfolio project kedua: DAO governance lengkap dengan ERC-20 voting token, OZ Governor v5, timelock, dan treasury. Pair dari [defi-staking](../defi-staking/) (yang di SPEC-nya disebut "governance itu Project 2").

Kontrak ini **sudah lulus full test suite dan terverifikasi di anvil**, tapi **belum dideploy ke Sepolia** (butuh private key pribadi; lihat bagian Deploy). Gak ada klaim live di luar itu.

## Arsitektur

```
                    delegate()                    propose() / queue() / execute() / cancel()
  ┌──────────────────────┐  IVotes   ┌────────────────────────────────┐
  │   GovernanceToken    │──────────►│        GovernorContract        │
  │  ERC20 + Permit +    │           │  Governor + Settings + Simple  │
  │  ERC20Votes          │           │  + QuorumFraction + TimelockCtl│
  └──────────────────────┘           └───────────────┬────────────────┘
        1.000.000 GT fixed, tanpa owner              │ PROPOSER_ROLE + CANCELER_ROLE
                                                     │ EXECUTOR_ROLE open (address(0))
                                                     ▼
                                     ┌────────────────────────────────┐
                                     │       TimelockController       │
                                     │        minDelay = 1 hari       │
                                     └───────────────┬────────────────┘
                                                     │ satu-satunya pemanggil execute()
                                                     ▼
                                     ┌────────────────────────────────┐
                                     │            Treasury            │
                                     │   ETH vault, guard timelock    │
                                     └────────────────────────────────┘
```

Kenapa bentuknya begini: **governor gak pegang dana**. Dana ada di Treasury, dan satu-satunya jalan keluar adalah `Treasury.execute()` yang cuma bisa dipanggil timelock. Timelock cuma mengeksekusi operasi yang di-schedule oleh proposal yang menang. Jadi setiap pengeluaran dana selalu melewati: vote menang -> queue -> jeda 1 hari -> execute. Jeda itu exit window buat user yang gak setuju.

## Parameter (roadmap) dan alasannya

| Parameter | Nilai | Alasan |
|---|---|---|
| Quorum | 4% dari past supply | Sama dengan Uniswap. Dengan supply 1M GT berarti 40.000 GT voting power minimum buat menang. Rendah cukup untuk demo, cukup tinggi untuk mencegah proposal 1-orang lolos. |
| Voting delay | 7200 block (1 hari @ 12 s/block) | Jeda sejak propose sampai snapshot voting. Fungsinya memutus flash-loan governance attack (beli token, vote, jual dalam 1 tx gak cukup karena bobot diambil di snapshot). |
| Voting period | 50400 block (1 minggu) | Jendela voting. Standar protokol nyata: 3-7 hari. |
| Proposal threshold | 0 | Siapa pun boleh propose. Demo-friendly; untuk produksi naikkan lewat `setProposalThreshold` (via proposal, bukan langsung). |
| Timelock minDelay | 1 hari | Exit window sebelum eksekusi. Compound pakai 2 hari; 1 hari cukup untuk testnet demo. |
| Supply | 1.000.000 GT fixed | Gak ada mint, gak ada burn via governance. Simpel dan bisa dianalisis. |

Quorum dihitung dari **past total supply di snapshot** (`GovernorVotesQuorumFraction`), bukan supply sekarang.

## Struktur

```
src/
  GovernanceToken.sol   ERC20 + ERC20Permit + ERC20Votes, fixed supply, override _update + nonces
  GovernorContract.sol  5 mixin OZ v5, threshold 0, counting simple, quorum 4%, timelock control
  Treasury.sol          vault ETH, execute() hanya timelock
test/
  GovernanceToken.t.sol     14 test
  GovernorFullFlow.t.sol    16 test (wiring, happy path, negative, cancel)
  GovernorFuzz.t.sol         3 test fuzz (256 runs per test)
script/
  DeployGovernance.s.sol    deploy 4 kontrak + wiring roles + renounce + deployments JSON
subgraph/                   code subgraph (butuh akun The Graph Studio, lihat subgraph/README.md)
docs/research-governance.md research Compound Bravo vs OZ Governor
SPEC.md                     spesifikasi final (edge cases, deployment plan, DoD)
deployments/<chainId>.json  hasil deploy (address semua kontrak)
devlog/                     catatan harian masalah nyata yang ditemui
```

## Quickstart

```bash
forge build        # via_ir = true, butuh waktu 1-2 menit pertama kali
forge test         # 33 test, semua hijau
forge snapshot     # gas report (opsional)
```

### Deploy lokal (anvil)

```bash
# terminal 1
anvil -p 8547

# terminal 2
export PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80  # akun anvil default #0
forge script script/DeployGovernance.s.sol --rpc-url http://127.0.0.1:8547 --broadcast
```

Output nyata dari verifikasi di anvil (chainId 31337, anvil default mnemonic):

```
GovernanceToken: 0x5FbDB2315678afecb367f032d93F642f64180aa3
Timelock:         0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512
Governor:         0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0
Treasury:         0xa513E6E4b8f2a923D98304ec87F64353C4D5C853
Deployer:         0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
```

Hasil cast setelah deploy (potongan):

| Cek | Nilai |
|---|---|
| `governor` codesize | 16.404 bytes (di bawah limit EIP-170 24.576) |
| timelock `hasRole(PROPOSER_ROLE, governor)` | true |
| timelock `hasRole(CANCELLER_ROLE, governor)` | true |
| timelock `hasRole(EXECUTOR_ROLE, address(0))` | true |
| timelock `hasRole(DEFAULT_ADMIN_ROLE, deployer)` | false (sudah renounce) |
| `getMinDelay()` | 86400 (1 hari) |
| treasury balance | 0.1 ETH |
| `totalSupply()` | 1.000.000e18 |
| `getVotes(deployer)` | 1.000.000e18 (deployer delegate ke dirinya) |
| `votingDelay()` / `votingPeriod()` / `quorumNumerator()` | 7200 / 50400 / 4 |

Hasil yang sama (address anvil berbeda tergantung nonce) juga tersimpan otomatis di `deployments/31337.json`:

```json
{"chainId":31337,"deployedAt":"<epoch ms>","deployer":"0x...","contracts":{"GovernanceToken":"0x...","Timelock":"0x...","Governor":"0x...","Treasury":"0x..."}}
```

### Frontend

Folder `frontend/` dikerjakan terpisah. Instruksi buat sisi frontend: baca `frontend/README.md` (akan dibuat oleh agent frontend). Sumber address kontrak = `deployments/<chainId>.json`. Abi tiap kontrak bisa diambil dengan `forge inspect <Contract> abi --json`. Perhatian khusus UX: **voting power = 0 sampai user `delegate()`**, tampilkan status delegasi di UI sebelum form voting.

## Status deploy (jujur)

| Target | Status |
|---|---|
| Test suite | 33/33 pass (`forge test`, Foundry 1.5.1, solc 0.8.28, via-ir) |
| Anvil (31337) | Deployed + verified via cast (tabel di atas) |
| Sepolia (11155111) | **Belum.** Butuh private key user, RPC Sepolia, dan (opsional) Etherscan API key. Langkah: |

```bash
export PRIVATE_KEY=0x<PRIVATE KEY KAMU>   # wallet yang punya ETH Sepolia
forge script script/DeployGovernance.s.sol \
  --rpc-url <SEPOLIA_RPC_URL> \
  --broadcast \
  --verify --etherscan-api-key <ETHERSCAN_KEY>
```

Setelah deploy Sepolia: ganti `source.address` dan `source.startBlock` di `subgraph/subgraph.yaml` dengan address Governor dari `deployments/11155111.json`, lalu ikuti `subgraph/README.md`.

## Hasil test

Per suite (`forge test`, Foundry 1.5.1, `via_ir = true`, `optimizer_runs = 1000`, solc 0.8.28):

| Suite | Jumlah | Hasil |
|---|---|---|
| test/GovernanceToken.t.sol | 14 | pass (termasuk 2 fuzz @ 256 runs) |
| test/GovernorFullFlow.t.sol | 16 | pass |
| test/GovernorFuzz.t.sol | 3 | pass (256 runs/test) |
| Total | 33 | 33 pass, 0 fail |

Coverage naratif per kasus ada di SPEC section 6 (E1-E14 + full flow).

## Catatan keamanan

1. **Timelock satu-satunya executor.** `Treasury.execute()` di-guard immutable ke address timelock. Proposal yang menang harus tetap melewati `queue()` + `minDelay`.
2. **Admin renounce.** Setelah renounce `DEFAULT_ADMIN_ROLE`, deployer gak bisa grant role siapa pun lagi. Menambah proposer baru harus lewat proposal. Ini disengaja: gak ada jalan pintas darurat.
3. **EXECUTOR_ROLE terbuka** (`address(0)`): siapa pun boleh mengeksekusi operasi yang sudah menyelesaikan delay. Ini aman karena eksekusi cuma bisa untuk operasi yang di-schedule oleh PROPOSER (governor).
4. **Caveat demo: single-delegate.** Deploy script delegate seluruh supply ke deployer, jadi 1 address bisa pass proposal apa pun. Untuk DAO nyata: distribusikan token, pastikan delegate tersebar, baru anggap governance live.
5. **Threshold 0.** Siapa pun bisa propose (potensi spam proposal). Naikkan via governance untuk produksi.
6. **Ukuran kontrak.** Stack Governor OZ v5 tanpa via-ir = 28.857 bytes runtime, GAGAL di-deploy (EIP-170, limit 24.576 bytes; terbukti literally gagal di anvil sebelum konfigurasi diperbaiki). Dengan `via_ir = true` + `optimizer_runs = 1000`: 16.404 bytes.
7. **Delegate requirement.** Voting power = 0 sampai `delegate()`. Token yang dipindah ke address yang belum delegate sementara "gak punya suara". Ini perilaku ERC20Votes standar, bukan bug, tapi wajib dikomunikasikan di UI.

## Lisensi

MIT.
