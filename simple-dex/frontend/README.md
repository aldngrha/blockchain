# Frontend: SimpleDex Swap + Liquidity

Interface buat kontrak `DexPair` + dua token di repo ini. Dua tab: Swap (quote client-side, price impact, slippage, deadline) dan Liquidity (pool stats, add/remove, position tracker). Update angka lewat event watching (`Mint`/`Burn`/`Swap`/`Sync` di pair) plus polling ringan buat balances dan reserves.

Stack: Vite + React 19 + wagmi v3 + viem + RainbowKit v2 + TanStack Query 5 + oxlint. Pola config, hooks, dan tx states di-mirror dari `defi-staking/frontend` yang udah proven, jadi konsisten dengan project-project lain di roadmap ini.

## Prasyarat

- Node.js 20.11+ dan npm.
- Foundry (buat `anvil` dan deploy script).
- MetaMask (atau wallet injected lain).

## Setup end-to-end lokal

Dari `frontend/`:

```bash
npm install
```

File `.npmrc` di folder ini nge-set `legacy-peer-deps=true`, jadi `npm install` polos cukup. Tanpa flag itu npm bakal nolak karena `@rainbow-me/rainbowkit@2.2.11` masih nge-deklarasikan peer `wagmi ^2.9.0` padahal kita pakai wagmi 3.x.

Terminal 1, jalankan local chain. Repo ini pakai port 8548 (lihat README root):

```bash
anvil -p 8548
```

Terminal 2, dari **root repo** (`simple-dex/`, bukan `frontend/`), deploy + seed pool:

```bash
export PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
forge script script/DeploySimpleDex.s.sol:DeploySimpleDex --rpc-url http://127.0.0.1:8548 --broadcast
```

Script menulis `deployments/31337.json` (kunci `TokenA`, `TokenB`, `DexPair`), mint 10.000e18 per token ke deployer, dan seed pool 1000 + 1000. Address kebaca otomatis: `vite.config.ts` membaca file itu via virtual module. Kalau file-nya gak ada, app tetap jalan tapi nampilin instruksi setup.

(Opsional) override address atau isi WalletConnect project ID:

```bash
cp .env.example .env
# isi VITE_TOKEN_A_ADDRESS / VITE_TOKEN_B_ADDRESS / VITE_DEX_PAIR_ADDRESS / VITE_WALLETCONNECT_PROJECT_ID
```

Nilai `.env` menang kalau konflik dengan deployment file. Restart dev server setelah deploy ulang kontrak, karena address dibaca saat server start.

Terminal 3:

```bash
npm run dev
```

Buka `http://localhost:5173`, connect wallet (import salah satu private key anvil, yang `0xac09...` itu deployer dengan 10.000 token per side), pastikan wallet di network Anvil (31337). Kalau wallet di chain lain, muncul banner switch.

## Yang ada di masing-masing tab

**Swap.** Masukkan jumlah token in, output dihitung di browser pakai mirror JS dari `AMMLibrary.getAmountOut` (BigInt, pembagian floor: hasilnya bit-exact dengan EVM). Ditampilkan: pool price, price impact eksekusi, price impact marginal, minimum received. Slippage default 0.5% (preset 0.1/0.5/1 + custom sampai 50%), deadline default 20 menit. Kalau allowance kurang, tombol jalanin approve dulu lalu swap (2 tx).

Dua angka impact itu beda definisi (dokumentasinya di `docs/uniswap-v2-research.md` section 4): impact eksekusi = seberapa jelek harga rata-rata trade lo vs pool price sebelum swap; impact marginal = seberapa jauh pool price pindah setelah swap lo (harga untuk wei berikutnya). Marginal selalu lebih besar. Persen di UI di-floor, jadi angka yang tampil gak pernah lebih optimis dari hitungan.

**Liquidity.** Pool stats (reserves, LP total supply), position tracker (LP lo, share %, estimasi holdings kalau ditarik sekarang), form add (ada guidance rasio dari mirror `quote`, plus peringatan kalau rasio off: pair cuma narik proporsi yang sesuai rasio, sisanya gak pernah ditransfer), form remove (estimasi payout dua token, peringatan kalau debu bakal revert). Add butuh approve TokenA dan TokenB. Remove gak butuh approve: pair membakar LP lo langsung via `_burn`, dan `_burn` gak cek allowance.

## Verifikasi yang sudah dijalankan

- Mirror JS diuji terhadap 26 vektor eksak dari `test/AMMLibrary.t.sol` dan `test/DexPairSwap.t.sol` (termasuk 9066108938801491315 dan 9871580343970612988): semua cocok. Script ceknya sementara, dihapus setelah lulus (catatan di devlog 7 Okt).
- Selector ABI diverifikasi: encoding viem dari `src/abi.js` cocok dengan `cast sig` untuk `swapExactTokensForTokens` (0xd8d44478), `addLiquidity` (0x9cd441da), `removeLiquidity` (0x9c8f9f23), dan error `DexPair__Expired` ter-decode benar.
- Smoke test on-chain di anvil sementara (port 8548, salinan repo di /tmp): swap 25 SDA lewat `cast` menghasilkan reserves pasca-swap persis prediksi mirror: (1025e18, 975681147401029343611 wei), amountOut di event `Swap` = 24318852598970656389 wei, sama dengan hitungan mirror.

## Lint, build, preview

```bash
npm run lint      # oxlint, 0 warning 0 error
npm run build     # output di dist/
npm run preview   # serve hasil build
```

## Catatan jujur / keterbatasan

- **Belum ada klik-through browser.** Verifikasi di atas semuanya non-GUI: build, lint, unit-check matika, selector ABI, dan smoke test via `cast`. Sesi interaksi MetaMask sungguhan (connect, approve di wallet, submit form) masih perlu lo jalankan sendiri; kalau ada yang melebar dari catatan ini, perbaiki dulu sebelum demo.
- **Deploy Vercel manual.** Build statik (`npm run build`), tinggal import project ke Vercel. Tapi frontend ini bergantung ke node RPC lokal di `http://127.0.0.1:8548`, jadi deployment publik cuma berguna kalau addressnya diarahkan ke Sepolia via `.env`, dan itu belum dikerjakan (kontrak belum dideploy ke Sepolia).
- **Address satu set global, gak per chain.** Sama seperti `defi-staking/frontend`: ganti chain berarti ganti isi `.env`.
- **UI draft tanpa arahan desain** (belum ada DESIGN.md): dials ENERGY 1 / RHYTHM 1 / MOTION 1, fungsional, kontras WCAG AA, keyboard accessible, tanpa emoji. Bukan hasil arahan desain yang matang.
- **Kontrak belum diaudit**, ini chain lokal/testnet, dan token-nya mock permissionless mint. Jangan hubungkan dana beneran.
