# RESUME-HERE: Catch-up ROADMAP + lanjutan silabus

> Bookmark session, terakhir diperbarui: 18 Nov 2026. Catch-up 16 Sep-6 Okt SELESAI. Batch 7-9 Okt SELESAI. Batch 10-27 Okt SELESAI 12 Okt. Batch 28-31 Okt SELESAI 18 Nov (artefaknya menyusul, jadwal aslinya 28-31 Okt). Vault TIDAK ditulis untuk batch ini, sesuai keputusan user.

## Batch 28-31 Okt: SELESAI (18 Nov 2026)

Konteks: 28-31 Okt terlewat, artefaknya belum ada. Dikerjakan 18 Nov, semua diverifikasi sendiri di mesin lokal.

| Tanggal | Deliverable | Status |
|---|---|---|
| 28-29 Okt | `docs/uniswap-v3-notes.md` (concentrated liquidity, tick, `sqrtPriceX96`, diagram arsitektur, swap execution path, `TickMath`/`SqrtPriceMath`, fee growth, oracle, tabel efisiensi modal) | selesai |
| 30 Okt | `docs/aave-v3-liquidation-sim.md` (interest rate model dua lereng, tabel HF vs penurunan harga, matematika bonus likuidator, cara reproduksi di spreadsheet) | selesai |
| 31 Okt | `aave-v3-flashloan/` (receiver + plugin action ber-allowlist + mock pool + SPEC + devlog + deploy script) | selesai, fork mainnet terverifikasi |

**Verifikasi yang dijalankan sendiri:** `forge test` lokal aave-v3-flashloan **10/10 hijau** (termasuk 1 fuzz test). Fork mainnet **2/2 hijau** lawan Pool Aave v3 `0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2`: flash loan 1.000 USDC, premium 500.000 unit (0,05%), saldo aUSDC naik tepat sebesar premium. Deploy anvil fork port 8550 jalan, `deployments/31337.json` tertulis, dan satu flash loan sungguhan via `cast` sukses (`lastAmount` 1e9, `lastPremium` 500000). Data Uniswap v3 di notes dibaca on-chain block 26439489, bukan dari artikel.

**Temuan teknis yang masuk devlog:** (1) Aave v3 tidak menyimpan underlying di `Pool`, tapi di aToken, jadi mengukur premium lewat saldo Pool selalu nol; (2) `getTreasury()` revert di PoolAddressesProvider mainnet karena versi v3 di mainnet lebih baru; (3) premium flash loan harus sudah ada sebelum transaksi, bukan hasil pinjaman; (4) mock pool tanpa `transferFrom` membuat test tidak menguji pembayaran sama sekali.

**Berikutnya (1-8 Nov):** review DeFi week 1, mainnet fork interaksi langsung (swap v3 + supply/borrow Aave), GMX/perp DEX research, MEV Flashbots, oracle security (Mango Markets), reentrancy advanced, Code4rena contest. Belum ada artefak satu pun untuk tanggal-tanggal itu.

## Batch 10-27 Okt: DIBANGUN ULANG (12 Okt 2026)

Konteks: vault punya catatan silabus ini di tanggal Jul 2026, tapi artefaknya tidak ada. User memutuskan bikin ulang di repo ini. Track cari client tetap di-skip.

**Verifikasi dulu (semua hijau di mesin lokal):** defi-staking 75/75, governance-dapp 33/33, simple-dex 53/53 = 161 test. Lint 0 error dan build exit 0 untuk 3 frontend. Git bersih dan sinkron dengan origin/main.

**Yang dibangun:**

| Tanggal | Deliverable | Status |
|---|---|---|
| 17 Okt | `docs/how-audit-contests-work.md` (Code4rena vs Sherlock vs Codehawks vs Cantina, alur contest, severity, studi kasus) | selesai |
| 18-19 Okt | `security/AUDIT-TEMPLATE.md` (template finding, panduan severity, uji sebelum submit, anti-pattern) | selesai |
| 24 Okt | `docs/l2-deep-dive.md` (fraud vs validity proof, angka L2Beat, framework stage, bridging, langkah deploy zkSync) | selesai |
| 25 Okt | `ccip-crosschain/` (project Foundry: sender + receiver + 24 test + SPEC + devlog + deploy script) | selesai, deploy lokal terverifikasi |
| 26 Okt | `docs/defi-protocol-onepager.md` (Aave v3, plus data dibaca langsung dari mainnet) | selesai |

**Yang di-skip (bukan teknis atau track cari client):** 10, 12-16 Okt (cari client), 11 Okt (artikel Mirror, draft sudah ada), 20 Okt (daftar ETHGlobal), 21 Okt (portfolio polish), 22 Okt (review bulanan), 23 dan 27 Okt (client onboarding).

**Verifikasi yang sudah dijalankan sendiri:** `forge test` ccip-crosschain 24/24 hijau. Deploy lokal anvil port 8549 berhasil, `deployments/31337.json` tertulis, dicek lewat `cast` (getRouter, supportsInterface 0x85572ffb true, defaultGasLimit 200000). Data Aave dibaca on-chain dari Pool mainnet `0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2` block 26175066.

**Langkah manual user yang masih menumpuk:** deploy ccip-crosschain ke Sepolia + Arbitrum Sepolia (butuh router address dan chain selector dari CCIP directory resmi, plus `setTrustedSender` di receiver), deploy zkSync Era testnet (butuh `foundry-zksync`), dan semua item lama (deploy Sepolia/Arbitrum Sepolia 3 project, Vercel, Slither re-run, subgraph Studio, publish konten).

**28-31 Okt:** SELESAI 18 Nov, lihat section paling atas. Sebelum itu, batch ini sempat jadi pekerjaan yang menggantung selama 19 hari.

## Hasil catch-up (16 Sep s/d 6 Okt): SELESAI, diverifikasi final 7 Okt

- **defi-staking (16-19 Sep):** frontend dashboard + deploy script (verified anvil) + README + devlog 4 file + draft konten. `forge test`: **75/75**, coverage 100%/100%. Frontend build + lint hijau.
- **governance-dapp (20-29 Sep):** kontrak (GovernanceToken/GovernorContract/Treasury, OZ v5, via_ir + optimizer 1000 karena EIP-170) + deploy verified + subgraph (code only) + SPEC + README + `docs/research-governance.md` + frontend (34 file: proposal list event scan, voting snapshot via getPastVotes, delegate, create proposal; smoke test loop penuh via cast) + devlog 10 file. `forge test`: **33/33**. Frontend build + lint hijau.
- **simple-dex (30 Sep-6 Okt):** AMMLibrary + DexPair + 5 suite test + deploy verified (reserves 1000/1000, LP 1000e18) + SPEC + README + `docs/uniswap-v2-research.md` (IL table dihitung dari rumus) + `docs/security-review.md` (10 temuan, termasuk cerita overflow fuzz yang di-fix dengan domain uint112 + natspec) + devlog 7 file. `forge test`: **53/53**.
- **Total: 161 test hijau, 2 frontend build+lint hijau, 21/21 tanggal punya devlog, 0 em dash di semua dokumen baru.**

## STATUS AKHIR SESSION (7 Okt malam, user istirahat)

Catch-up 16 Sep-6 Okt SELESAI (lihat section di bawah). Batch 7-9 Okt JUGA SELESAI (frontend AMM + demo script + draft artikel Mirror, verifikasi build+lint hijau, detail di section "Batch 7-9 Okt: SELESAI"). Progres silabus: **tertuntas sampai 9 Okt**. GAK ADA agent yang masih jalan saat session ditutup.

## Pelajaran teknis (jangan diulang)

1. Sub-agent besar: SERIAL, maksimal 1. Paralel = mati (limit concurreny dinamis). Cek disk dulu sebelum relaunch agent yang mati/stop.
2. Verifikasi: jangan percaya report agent, jalankan sendiri (forge test, npm build). Agent B ngaku sukses padahal EIP-170 bikin deploy gagal di anvil, ketahuan karena verify; viem 2.57 `getLogs` diam-diam ngeabaikan `abi`+`eventName` (ketahuan karena smoke test agent C).
3. Em dash dilarang di semua file baru (antislop R-02). Dokumen Indonesia lo/gw, kode Inggris. Roadmap asli masih punya em dash: kutipan devlog dipangkas ke bagian bersih.
4. Foundry: fs_permissions read-write untuk vm.writeFile; console.log import eksplisit; deployer via vm.addr(PRIVATE_KEY) bukan msg.sender; forge-std baru: stdError import eksplisit dari StdError.sol, Test gak lagi ngeriv; OZ v5 Governor butuh via_ir.
5. Deployments JSON standar: `{"chainId","deployedAt"(epoch ms),"deployer","contracts":{...}}`. Port anvil: gue 8545, governance 8547, simple-dex 8548.
6. Stack frontend proven: Vite + React 19 + wagmi v3 + RainbowKit v2 + TanStack Query 5 + oxlint (mirror nft-minting-dapp/defi-staking), BUKAN Next.js walau roadmap bilang begitu.
7. Dilarang fabricate: address testnet, tx hash, angka gas yang gak diukur, hasil deploy. Tandai sebagai langkah manual user.

## Batch 7-9 Okt: SELESAI (7 Okt, diverifikasi build+lint)

- `simple-dex/frontend/`: swap UI (mirror JS getAmountOut BigInt, 2 definisi price impact, slippage + deadline, tx states) + liquidity UI (pool stats, share %, position tracker, guidance rasio, estimasi payout remove) + 3 devlog (7/8/9 Okt) + `content/demo-script.md` + `content/mirror-article-draft.md` (1.018 kata).
- Verifikasi: build + lint hijau; mirror JS dicek ke 26 vektor eksak suite Solidity (PASS); smoke test on-chain: swap via cast menghasilkan reserves bit-exact sama prediksi mirror. Findings penting: remove liquidity GAK butuh approve LP (pair burn LP langsung), refund addLiquidity = surplus gak pernah ditarik (CEI), semua kecatat di devlog.
- Manual user: sesi klik-through MetaMask sebelum rekam Loom, rekam Loom + publish Mirror, deploy Vercel (butuh kontrak Sepolia dulu).
- `STUDY-GUIDE.md` udah ada Tahap 4 buat baca materi ini.

## Setelah 9 Okt: rencana silabus (versi artifact), BELUM DIMULAI

Besok mulai di sini. Batch per batch, lapor dulu sebelum lanjut (kesepakatan dengan user):
- **Batch berikutnya: 17-31 Okt** (10-16 Okt + 20-23 Okt = track cari client, DILEWATKAN per keputusan user; item real-world seperti ikut audit contest/ETHGlobal = bahan saja, eksekusi manual): `docs/how-audit-contests-work.md` (Code4rena vs Sherlock, 17 Okt), `docs/l2-deep-dive.md` + coba deploy zkSync (24 Okt), CCIP receiver minimal + riset (25 Okt), one-pager protocol DeFi (26 Okt), `docs/uniswap-v3-notes.md` (28-29 Okt), Aave v3 + flash loan receiver dengan anvil fork (30-31 Okt), devlog per tanggal + catatan tanggal yang di-skip.
- Nov: MEV, oracle security, DVDeFi 15 level (Foundry, bisa penuh), Echidna, user interview (manual).
- Des-Jan: AA + paymaster, Cosmos SDK, Dune, dst. sampai silabus teknis habis.

## Langkah manual user (akumulasi, dokumentasikan jujur)

1. git init + push 3 project; deploy Sepolia (staking + governance) dan Arbitrum Sepolia (simple-dex); Vercel untuk 3 frontend; update address di README setelah deploy.
2. Slither re-install + re-run 3 project (belum ada test reentrancy end-to-end di simple-dex, lihat security review section 9).
3. Subgraph: akun The Graph Studio (code ada di governance-dapp/subgraph/).
4. Publish konten: thread X + Mirror (draft di defi-staking/content/ dan simple-dex), Loom video, GitHub profile README.
5. Paling penting: baca ulang per project (SPEC, kontrak, jalanin test, rusakin sesuatu, baca devlog) supaya skill-nya nempel, bukan cuma tanggal ketutup.
