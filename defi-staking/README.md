# DeFi Staking Protocol (Project 1)

Protokol staking minimal dengan pola production: user stake `RewardToken`, reward terakumulasi per detik dengan pola Synthetix (`rewardPerToken` accumulator), dan reward di-MINT saat claim (inflationary). Fokus project ini adalah kualitas pattern kontrak: checks-effects-interactions, `ReentrancyGuard`, custom errors, dan reward math yang benar, bukan kumpulan fitur.

Kontrak: Solidity `^0.8.20`, OpenZeppelin v5, Foundry. Frontend: Vite + React + wagmi + RainbowKit (lihat `frontend/`).

## Arsitektur

```
┌──────────────┐        mint()         ┌─────────────────┐
│ RewardToken  │◄──────────────────────│   StakingPool   │
│  (ERC-20)    │   saat claimReward()  │   (Ownable +    │
│  Ownable     │                       │  ReentrancyGuard)│
└──────────────┘                       └─────────────────┘
        ▲                                      │
        │            stake / unstake           │
        └──────────────── User (EOA) ──────────┘
```

- `RewardToken`: ERC-20 + Ownable. `mint()` hanya bisa dipanggil StakingPool (`setStakingPool()` dipanggil sekali, irreversible). Pre-mint bootstrap 1.000.000 RWT ke deployer supaya ada token yang bisa distake (tanpa itu, mint yang di-gate ke pool tidak pernah bisa dimulai).
- `StakingPool`: 1 pool, 1 token. Reward token = staking token. Reward di-mint saat claim, bukan di-pre-fund.

## Desain dan trade-off (baca sebelum pakai)

1. **Reward saat pool kosong hilang.** Kalau `totalStaked == 0` sementara rate berjalan, reward detik itu tidak diakumulasi ke siapa pun. Sama seperti Synthetix. Konsekuensi operasional: periode reward mulai saat `setRewardRate()`, jadi stake segera setelah deploy.
2. **Rounding dust.** Pembagian integer membuat tiap user bisa "kehilangan" di bawah 1 wei per operasi. Bounded dan di-test via fuzz (I-8).
3. **Inflationary reward.** Supply naik setiap claim. Tokenomics belum melalui governance (itu scope Project 2).
4. **`emergencyWithdraw` sengaja forfeit reward.** Escape hatch kalau reward math bermasalah: 100% stake kembali, reward di-reset. Trade-off eksplisit, ada test khusus (E5, E6).
5. **Owner = deployer.** Untuk mainnet harus pindah ke multisig. Belum diimplementasikan di v1.

## Hasil test

- `forge test`: **75 test, 5 suite, semua hijau** (unit, timing matrix, fuzz stateless, invariant handler).
- `forge coverage`: `RewardToken` **100%**, `StakingPool` **100%** (75/75 statement, 13/13 branch) dari target SPEC 95%.
- Invariant suite (handler-based, warp/roll acak, 5 aktor):
  - I-2: `sum(stakedBalance) == totalStaked`
  - I-3: pool tidak pernah memegang reward idle (`balanceOf(pool) == totalStaked`)
  - I-4: total mint == total claim (tidak ada mint bocor)
  - I-5: unstake semua + claim menghasilkan state bersih (tidak ada stuck funds)
  - I-6: `rewardPerToken()` tidak pernah turun
- Gas snapshot: `.gas-snapshot` committed. Cek regressi dengan `forge snapshot --check`.
- Slither: hasil terakhir untuk project security ada di `../security/SLITHER-REPORT.md`. Re-run terhadap repo ini masih harus dilakukan ulang (`pip install slither-analyzer` lalu `slither .`), tool belum ter-install di environment saat polish 17 Sep.

## Quickstart

```bash
forge install
forge build
forge test          # 75 test
forge snapshot      # regenerasi .gas-snapshot
```

## Deploy lokal + frontend

```bash
anvil                                    # terminal 1
# terminal 2, pakai salah satu key default anvil:
export PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
forge script script/DeployStaking.s.sol:DeployStaking --rpc-url http://127.0.0.1:8545 --broadcast
```

Script menulis `deployments/31337.json` berisi address `RewardToken` dan `StakingPool`. Frontend membaca file itu otomatis via vite config (override dengan `.env` `VITE_STAKING_POOL_ADDRESS` dan `VITE_REWARD_TOKEN_ADDRESS`):

```bash
cd frontend && npm install && npm run dev
```

## Deploy Sepolia

```bash
export PRIVATE_KEY=<key khusus deploy, bukan key dana besar>
export SEPOLIA_RPC_URL=<rpc url>
forge script script/DeployStaking.s.sol:DeployStaking \
  --rpc-url $SEPOLIA_RPC_URL --broadcast --verify --etherscan-api-key $ETHERSCAN_API_KEY
```

**Status: belum terdeploy ke Sepolia.** Address resmi akan ditulis di sini setelah deploy sungguhan, bukan sebelumnya.

## Struktur

```
src/
  RewardToken.sol        ERC-20, mint gated ke StakingPool
  StakingPool.sol        accumulator Synthetix, CEI di semua entrypoint
  mocks/                 mock untuk test
test/                    unit + fuzz + invariant (75 test)
script/
  DeployStaking.s.sol    deploy + wiring + deployments JSON
deployments/             output deploy (per chain id)
devlog/                  jurnal harian: masalah, kenapa, solusi
frontend/                dashboard (React + wagmi)
SPEC.md                  spesifikasi final (13 Sep)
```

## Referensi

- `SPEC.md` untuk keputusan desain lengkap (termasuk tabel edge case E1-E18 dan invariant I-1..I-8).
- `devlog/` untuk jurnal pengerjaan per tanggal.
- Pola reward math: Synthetix `StakingRewards`.
