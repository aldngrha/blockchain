# Frontend: Governance DApp

Dashboard buat stack governance di repo ini (`GovernanceToken` GT, `GovernorContract`, `TimelockController`, `Treasury`). Lo bisa connect wallet, lihat daftar proposal dengan status badge, vote For/Against/Abstain dengan voting power snapshot, delegate GT, bikin payout proposal (`Treasury.execute` via governor), lalu queue dan execute lewat timelock. Update angka lewat event watching (ProposalCreated/VoteCast/ProposalQueued/ProposalExecuted/ProposalCanceled) plus polling ringan.

Stack: Vite + React 19 + wagmi v3 + viem + RainbowKit v2 + TanStack Query 5 + oxlint. Sama persis dengan `defi-staking/frontend` dan `nft-minting-dapp/frontend`.

## Prasyarat

- Node.js 20.11+ dan npm.
- Foundry (buat `anvil` dan deploy script).
- MetaMask (atau wallet injected lain).

## Setup end-to-end lokal

Dari `frontend/`:

```bash
npm install
```

File `.npmrc` di folder ini nge-set `legacy-peer-deps=true`, jadi `npm install` polos cukup (RainbowKit 2.2.11 masih nge-deklarasikan peer `wagmi ^2.9.0`, kombinasi dengan wagmi 3.x proven jalan).

Terminal 1, jalankan local chain:

```bash
anvil
```

Terminal 2, dari **root repo** (`governance-dapp/`, bukan `frontend/`), deploy:

```bash
export PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80  # akun 0 anvil
forge script DeployGovernance --rpc-url http://127.0.0.1:8545 --broadcast
```

Script-nya nulis `deployments/31337.json` berisi address `GovernanceToken`, `Timelock`, `Governor`, `Treasury`, sekaligus ngisi treasury 0.1 ETH.

Address kebaca otomatis: `vite.config.ts` baca `deployments/31337.json` dan nyuntik sebagai virtual module. Kalau file-nya gak ada, app tetap jalan tapi nampilin instruksi setup. (Opsional) `cp .env.example .env` buat override address atau isi WalletConnect project ID; nilai `.env` menang. Restart dev server setelah deploy ulang.

Terminal 3:

```bash
npm run dev
```

Buka `http://localhost:5173`, connect wallet (import private key anvil ke MetaMask; akun 0 = deployer pegang 1.000.000 GT).

## Alur governance penuh di UI

1. **Delegate dulu** (form di halaman utama, default ke diri sendiri). Saldo GT bukan voting power: votes cuma terhitung setelah `delegate()`, dan berlaku buat proposal yang dibuat SETELAH blok delegasi.
2. **Create a payout proposal**: isi recipient, jumlah ETH, deskripsi. Form meng-encode `Treasury.execute(recipient, amount)` dan submit `propose`. ETH-nya datang dari saldo treasury (0.1 ETH dari deploy), bukan dari proposer. Setelah sukses, lo langsung dibawa ke halaman detail.
3. **Vote**: proposal Pending selama voting delay (7200 blok; di anvil block time 1 detik artinya ~2 jam, cepatin dengan `cast rpc anvil_mine --rpc-url http://127.0.0.1:8545 7201` kalau mau). Saat Active, pilih For/Against/Abstain, konfirmasi di wallet. Voting power yang dihitung adalah `getPastVotes` di blok snapshot.
4. **Queue + execute**: setelah voting period (50400 blok) lewat dan quorum 4% tercapai (for + abstain), state jadi Succeeded. Queue tombolnya, tunggu timelock delay 1 hari (accelerate: `cast rpc anvil_increaseTime --rpc-url http://127.0.0.1:8545 86401` lalu mine 1 blok), execute jadi aktif, dan treasury bayar recipient.
5. Proposer bisa cancel, tapi cuma selama proposal masih Pending (aturan OZ 5.4, bukan UI yang resektif).

## Lint, build, preview

```bash
npm run lint      # oxlint, 0 warning saat diserahkan
npm run build     # output di dist/
npm run preview   # serve hasil build
```

## Keterbatasan (jujur)

- **Daftar proposal itu hasil scan event.** OZ Governor gak punya registry proposal on-chain: satu-satunya cara nemu proposal adalah nyari log `ProposalCreated` dari blok 0. Konsekuensinya: scan pertama lambat di testnet, RPC bisa nolak range besar, dan ada margin rescan 20 blok buat reorg. Cache localStorage mempercepat load berikutnya tapi bisa kehapus.
- **Deskripsi proposal cuma ada di event log.** Proposal id adalah hash payload + deskripsi, jadi gak ada view call yang balikin deskripsinya. Deskripsi yang lo lihat berasal dari event scan (atau dari receipt proposal yang lo buat sendiri). Kalau cache kosong dan log gak bisa discan, deskripsi tampil sebagai "not available", dan queue/execute/cancel gak bisa dibangun dari UI. **Solusi penuhnya subgraph** (udah disiapkan di `../subgraph/`, task 27 Sep): indexing event jadi queryable, frontend tinggal ganti sumber data.
- **Estimasi tanggal deadline itu estimasi.** Deadline proposal itu nomor blok; tanggal dihitung dari rata-rata block time hasil sampel 1000 blok terakhir dan selalu dilabeli "est.". Satu-satunya tanggal yang eksak adalah eta timelock (detik on-chain).
- **Belum ada link explorer.** Anvil gak punya explorer; link tx bisa ditambah pas deploy ke Sepolia (task 28 Sep).
- Kontrak belum diaudit, ini chain lokal/testnet, jangan hubungkan dana beneran.

## Checklist verifikasi manual (butuh wallet di browser)

Smoke test otomatis udah nutup jalur encoding/decoding sampai payout (lihat `../devlog/2026-09-26-voting-ui.md`), tapi klik-klik dengan MetaMask asli butuh tangan manusia. Yang perlu dicek:

1. Connect wallet via RainbowKit, gak ada error console.
2. Wallet di chain lain: muncul banner switch network, tombol switch jalan.
3. List: proposal tampil dengan badge state, votes, quorum bar, deadline; klik kartu buka detail.
4. Delegate: submit muncul popup wallet, setelah konfirmasi voting power ter-update.
5. Vote: tombol disabled dengan alasan yang bener (belum delegate / sudah vote / bukan Active); saat Active, popup wallet muncul, setelah konfirmasi tally dan "Vote history" bertambah.
6. Create proposal: popup wallet, setelah sukses pindah ke halaman detail proposal baru, deskripsi langsung tampil.
7. Queue/execute: tombol execute disabled sampai eta lewat, setelah itu jalan dan saldo treasury berkurang.
8. Kecilkan window sampai mobile: gak ada scroll horizontal, tombol tetap 44px.
