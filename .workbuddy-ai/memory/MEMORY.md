# MEMORY.md - Project blockchain (curated)

## Identitas project

Workspace belajar blockchain engineering. Silabus = `ROADMAP.md` (3 Ags 2026 sampai 21 Jan 2027, 172 hari). Status terkini = `RESUME-HERE.md`. Index project = `README.md`.

## Konvensi wajib

- **Em dash DILARANG di semua file baru** (aturan antislop R-02). Pakai koma, titik dua, atau tanda hubung biasa. Sudah dicek: semua file baru bebas em dash. Catatan: `ROADMAP.md` dan `README.md` versi lama masih punya em dash, belum dibersihkan (nunggu keputusan user).
- Dokumen bahasa Indonesia (lo/gw), kode bahasa Inggris.
- Tiap project Foundry punya `SPEC.md`, `README.md`, `devlog/`, test suite. Spec dulu (edge cases E1..En, invariants I-1..I-n), baru kode + test.
- `lib/` tidak di-commit. Fresh clone = install ulang dep.
- **Dilarang fabricate:** address testnet, tx hash, angka gas, hasil deploy. Kalau belum diukur, tulis metodenya atau tandai sebagai langkah manual user.

## Peta port anvil (biar tidak tabrakan)

| Project | Port |
|---|---|
| foundry-practice / default | 8545 |
| governance-dapp | 8547 |
| simple-dex | 8548 |
| ccip-crosschain | 8549 |
| aave-v3-flashloan | 8550 |

## Test suite (per 18 Nov 2026, semua hijau)

defi-staking 75, governance-dapp 33, simple-dex 53, ccip-crosschain 24, aave-v3-flashloan 10 lokal + 2 fork. Total 197 (fork butuh `FORK_RPC_URL`, kalau tidak di-skip).

## Jebakan lingkungan yang sudah ketemu

- `timeout` tidak ada di macOS. Pakai `curl -m <detik>`.
- `forge script` / `cast` ke anvil lokal gagal dengan 502 kalau env `HTTP_PROXY`/`HTTPS_PROXY` aktif. Pakai `env -u HTTP_PROXY -u HTTPS_PROXY -u http_proxy -u https_proxy <cmd>`.
- Anvil yang di-spawn dengan `&` di dalam satu tool call ikut mati saat call itu selesai. Jalankan sebagai background task.
- Build vite bisa gagal (`unwrapBindingResult` dari rolldown) kalau jalan di dalam sandbox; di luar sandbox normal.
- Aave v3: underlying token dipegang kontrak aToken, bukan `Pool`. Mengukur fee/premium lewat `balanceOf(pool)` hasilnya nol. `getTreasury()` di PoolAddressesProvider mainnet revert (versi v3 mainnet lebih baru), `getCollector()` juga.
- RPC publik yang jalan tanpa API key: `https://ethereum-rpc.publicnode.com`. Cocok buat `forge test --fork-url` dan anvil fork.

## Vault user (di luar repo ini)

`~/Documents/Aldi/Personal-Vault`. Punya aturan sendiri di `AGENTS.md` (wajib dibaca sebelum nulis). Ringkasnya: agent TIDAK bikin file topik baru di `03-Learning/`; nulis ke `00-Daily/<tanggal-kejadian>.md` di akhir section `## 🤖 Agent Log` sebelum footer `_Related:`, bahasa Inggris, wajib `<!-- key:slug -->`. Detail lengkap ada di user-level MEMORY.md.

## Posisi & rencana

- Selesai: silabus sampai 9 Okt, batch 10-27 Okt (12 Okt), dan batch 28-31 Okt (`docs/uniswap-v3-notes.md`, `docs/aave-v3-liquidation-sim.md`, project `aave-v3-flashloan/`) dikerjakan 18 Nov.
- Berikutnya: **1-8 Nov** = review DeFi week 1, interaksi langsung fork (swap v3 + supply/borrow Aave), GMX/perp DEX, MEV Flashbots, oracle security, reentrancy advanced, Code4rena contest.
- Kosong total di vault: Nov 2026 sampai Jan 2027 (MEV, oracle security, DVDeFi, Echidna, AA/paymaster, Cosmos, Dune).
