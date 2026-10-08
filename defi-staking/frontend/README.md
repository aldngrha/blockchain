# Frontend: DeFi Staking Dashboard

Dashboard buat kontrak `RewardToken` + `StakingPool` di repo ini. Lo bisa connect wallet, lihat posisi stake dan claimable reward, stake/unstake, claim, dan emergency withdraw. Update angka terjadi lewat event watching (Staked/Unstaked/RewardPaid/EmergencyWithdraw/RewardRateSet) plus polling ringan buat reward yang jalan tiap detik.

Stack: Vite + React 19 + wagmi v3 + viem + RainbowKit v2 + TanStack Query 5 + oxlint. Sama persis dengan frontend `nft-minting-dapp`, jadi pattern-nya udah lo kuasai.

## Prasyarat

- Node.js 20.11+ (dipakai `import.meta.dirname`-style URL resolution di vite.config) dan npm.
- Foundry (buat `anvil` dan deploy script).
- MetaMask (atau wallet injected lain).

## Setup end-to-end lokal

Dari `frontend/`:

```bash
npm install
```

File `.npmrc` di folder ini nge-set `legacy-peer-deps=true`, jadi `npm install` polos cukup. Tanpa flag itu npm bakal nolak karena `@rainbow-me/rainbowkit@2.2.11` masih nge-deklarasikan peer `wagmi ^2.9.0` padahal kita pakai wagmi 3.x (kombinasi ini proven jalan di `nft-minting-dapp`).

Terminal 1, jalankan local chain:

```bash
anvil
```

Terminal 2, dari **root repo** (`defi-staking/`, bukan `frontend/`), jalankan deploy script Foundry. Script-nya nulis `deployments/31337.json` berisi address `RewardToken` dan `StakingPool`. Cek folder `script/` buat nama file persisnya.

Address kebaca otomatis: `vite.config.ts` baca `deployments/31337.json` (path `../deployments/` dari folder frontend) dan nyuntik sebagai virtual module. Kalau file-nya gak ada, app tetap jalan tapi nampilin instruksi setup.

(Opsional) kalau mau override address atau isi WalletConnect project ID:

```bash
cp .env.example .env
# isi VITE_STAKING_POOL_ADDRESS / VITE_REWARD_TOKEN_ADDRESS / VITE_WALLETCONNECT_PROJECT_ID
```

Nilai `.env` menang kalau konflik dengan deployment file. Restart dev server setelah deploy ulang kontrak, karena address dibaca saat server start.

Terminal 3, jalankan app:

```bash
npm run dev
```

Buka `http://localhost:5173`.

## Bikin akun user + token

1. Import salah satu private key anvil ke MetaMask (yang muncul di output `anvil`, prefiks `0xac09...` itu akun deployer dengan 10000 ETH).
2. Kalau lo pakai akun deployer di wallet, token langsung ada di situ karena deploy script mint initial supply ke deployer.
3. Kalau mau user terpisah, transfer RewardToken dari deployer ke akun kedua, atau import private key akun kedua dan transfer pakai cast.
4. Pool butuh `rewardRate` di-set biar reward jalan. Kalau deploy script belum nge-set, panggil sebagai owner:

```bash
cast send $STAKING_POOL_ADDRESS "setRewardRate(uint256)" 1000000000000000000 \
  --rpc-url http://127.0.0.1:8545 --private-key $PRIVATE_KEY
```

(contoh: 1e18 wei per detik). Sebelum rate di-set, APY tampil `n/a` dan claimable reward nol, itu perilaku kontrak yang bener.

5. Connect wallet di dashboard. Kalau wallet belum di network Anvil (chain id 31337), muncul banner switch network.
6. Isi form Stake, submit, approve di wallet kalau diminta (2 tx: approve + stake), tunggu beberapa detik, terus Claim.

## Lint, build, preview

```bash
npm run lint      # oxlint
npm run build     # output di dist/
npm run preview   # serve hasil build
```

## Catatan jujur

- Address disimpan satu set global, gak per chain. Buat Sepolia (task 17 Sep), isi `VITE_STAKING_POOL_ADDRESS` dan `VITE_REWARD_TOKEN_ADDRESS` dengan address Sepolia; jangan lupa ganti lagi kalau balik ke anvil.
- Anvil gak punya block explorer, jadi gak ada link tx di feedback. Di Sepolia juga belum ada link, bisa ditambah pas deploy.
- Kontrak belum diaudit dan ini chain lokal/testnet. Jangan hubungkan dana beneran.
- UI masih draft tanpa arahan desain: fungsional, bersih, kontras WCAG AA, keyboard accessible.
