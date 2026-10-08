# RESUME-HERE: Catch-up ROADMAP + lanjutan silabus

> Bookmark session, terakhir diperbarui: 7 Okt 2026 siang. Catch-up 16 Sep-6 Okt: SELESAI 100%. Lanjutan: batch 7-9 Okt sedang berjalan. User memutuskan: track "cari client" (10 Okt dst) DILEWATKAN, fokus menuntaskan silabus teknis dulu.

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
