# SimpleDex (Project 3: AMM)

AMM constant-product (gaya Uniswap v2) minimal tapi production-pattern untuk satu pair 2 token: swap dengan fee 0.3%, add/remove liquidity, dan LP token ERC-20 (`SDX-LP`) sebagai bukti porsi pool. Satu kontrak `DexPair` merangkap pool dan LP token. Semua fungsi state-changing pakai checks-effects-interactions plus reentrancy lock gaya v2, math-nya pure library yang bisa dites tanpa state. Fokus project ini pola kontrak dan math yang bisa dijelaskan baris per baris ke interviewer, bukan jumlah fitur.

Kontrak: Solidity `^0.8.20`, OpenZeppelin v5, Foundry. Frontend menyusul di task 7-8 Okt (lihat "Yang tidak ada di v1").

## Arsitektur

```
   ┌────────────────────┐            ┌─────────────────────────────┐
   │  Token0 (ERC-20)   │            │            DexPair          │
   │  (ERC20Mock lokal) │◄───────┐   │  (ERC20 = LP token sekaligus│
   └────────────────────┘        │   │   pool, satu kontrak)       │
   ┌────────────────────┐        ├───│  addLiquidity               │
   │  Token1 (ERC-20)   │        │   │  removeLiquidity            │
   └────────────────────┘        │   │  swapExactTokensForTokens   │
                                 │   │  lock() + CEI               │
   ┌────────────────────┐        │   └─────────────────────────────┘
   │  User / LP (EOA)   │────────┘            ▲
   └────────────────────┘   transferFrom di    │ panggil
        approve dulu         dalam pair        │
   ┌────────────────────┐                     │
   │   AMMLibrary       │─────────────────────┘ (pure math, internal)
   │  getAmountOut/in   │
   │  quote, sqrt       │
   └────────────────────┘
```

- **DexPair** = pool + LP token. Token diurutkan di constructor (`token0 < token1`, urutan kanonik ala v2). `MINIMUM_LIQUIDITY` 1000 wei LP di-mint ke pair sendiri pada first provision dan terkunci selamanya.
- **AMMLibrary** = pure math: `getAmountOut`/`getAmountIn` (fee 0.3% dikodekan 997/1000), `quote`, `sqrt` (Babylonian). Pembulatan selalu menguntungkan pool: output floor, required input ceil +1.
- **API explicit-amount** (deviasi disengaja dari v2): user `approve` lalu panggil pair, `transferFrom` dilakukan di dalam pair dengan verifikasi saldo aktual (fee-on-transfer token di-reject).

Math lengkap (turunan rumus, tabel price impact, impermanent loss) ada di `docs/uniswap-v2-research.md`. Keputusan desain lengkap di `SPEC.md`.

## Hasil test

- `forge test`: **53 test, 4 suite, semua hijau** (diverifikasi 6 Okt):
  - `test/AMMLibrary.t.sol`: 20 test (vektor eksak hasil hitung manual, fuzz properti, domain boundary)
  - `test/DexPairLiquidity.t.sol`: 17 test (first provision sqrt, MINIMUM_LIQUIDITY, unbalanced + refund, dust guard)
  - `test/DexPairSwap.t.sol`: 11 test (vektor output eksak, arah harga, slippage, deadline)
  - `test/invariant/DexPairInvariantTest.t.sol`: 5 invariant via handler (3 aktor + lpOwner, add/remove/swap/warp acak, 100 runs x 32 depth, `fail_on_revert = true`)
- Invariant yang dikunci: k tidak pernah turun lewat swap (I-a), saldo token aktual pair == reserves tercatat (I-b), pembukuan LP supply (I-c), payout proporsional eksak (I-d), MINIMUM_LIQUIDITY terkunci permanen.
- Satu fuzz failure nyata yang ditemukan dan didokumentasikan: overflow di luar domain math (panic 0x11) dengan counterexample asli. Fix-nya domain documentation + 2 test boundary, cerita lengkap di `docs/security-review.md` dan `devlog/2026-10-02-core-math.md`.

## Quickstart

```bash
forge install
forge build
forge test          # 53 test
```

Untuk invariant dengan intensitas lebih tinggi (disarankan sebelum deploy serius):

```bash
FOUNDRY_INVARIANT_RUNS=256 FOUNDRY_INVARIANT_DEPTH=64 forge test
```

## Deploy lokal

```bash
anvil -p 8548          # terminal 1, port khusus biar gak tabrak anvil default
# terminal 2, pakai salah satu key default anvil:
export PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
forge script script/DeploySimpleDex.s.sol:DeploySimpleDex --rpc-url http://127.0.0.1:8548 --broadcast
```

Script deploy 2 ERC20Mock + DexPair, mint 10.000e18 per token ke deployer, seed 1000e18 + 1000e18, lalu menulis `deployments/<chainId>.json` (kunci `TokenA`, `TokenB`, `DexPair`). Run terverifikasi 6 Okt di anvil port 8548: `getReserves` = (1e21, 1e21) wei yaitu 1000/1000 token, LP totalSupply = 1000e18 (di antaranya 1000 wei terkunci di pair). Catatan: label `TokenA`/`TokenB` di JSON adalah label deploy, urutan kanonik pair ikuti `pair.token0()`.

**Catatan frontend:** repo ini belum punya frontend (task swap UI Rab 7 Okt, liquidity UI Kam 8 Okt). File `deployments/31337.json` disiapkan sebagai sumber address tunggal untuk tooling/frontend nanti, formatnya sama dengan yang dipakai project defi-staking.

## Deploy Arbitrum Sepolia

```bash
export PRIVATE_KEY=<key khusus deploy, bukan key dana besar>
export ARBITRUM_SEPOLIA_RPC_URL=<rpc url, mis. https://sepolia-rollup.arbitrum.io/rpc>
forge script script/DeploySimpleDex.s.sol:DeploySimpleDex \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --broadcast
# verifikasi kontrak di Arbiscan Sepolia kalau API key tersedia (flag --verify)
```

**Status: belum terdeploy.** Langkah ini butuh RPC pilihan gw sendiri + private key + faucet ETH Arbitrum Sepolia, semuanya kredensial manual yang tidak boleh dibuat-buat. Address resmi akan ditulis di sini (dan di `deployments/421614.json`) setelah deploy sungguhan, bukan sebelumnya. Catatan gas L1 vs L2: bandingkan field gas di `broadcast/<chainId>/run-*.json` kedua chain; angka apa pun di luar itu adalah estimasi, bukan hasil ukur (baseline snapshot L1 sendiri belum diambil, lihat devlog 6 Okt).

## Yang TIDAK ada di v1

- **Factory.** Satu pair = satu kontrak yang di-deploy manual dengan 2 address token. Tidak ada registry, tidak ada CREATE2 pair address deterministik.
- **TWAP oracle.** Spot price di v1 BUKAN sumber harga untuk protocol lain (lihat `docs/security-review.md` section 2). Tidak ada akumulator `priceCumulative`.
- **Fee-on-transfer.** Token yang makan fee di-reject aktif (`DexPair__FeeOnTransferNotSupported`), bukan diakomodasi.
- **Protocol fee switch.** 0.3% semuanya untuk LP, tidak ada bagian untuk treasury/dev.
- **Flash swap, skim/sync** ala v2. Donasi token langsung ke pair akan nyangkut (tidak bisa diklaim siapapun).
- **Frontend.** Masuk task 7-8 Okt, belum ada di repo ini.
- **Upgradeability/access control.** Pair sengaja trustless: tidak ada owner, tidak ada fungsi admin.

## Struktur

```
src/
  AMMLibrary.sol         pure math: getAmountOut/in, quote, sqrt
  DexPair.sol            pool + LP token (ERC20), lock + CEI
  mocks/                 ERC20Mock, FeeOnTransferMock untuk test
test/
  AMMLibrary.t.sol       vektor eksak + fuzz + domain boundary (20)
  DexPairLiquidity.t.sol liquidity, LP, MINIMUM_LIQUIDITY (17)
  DexPairSwap.t.sol      swap, slippage, deadline (11)
  invariant/             handler + 5 invariant (5)
script/
  DeploySimpleDex.s.sol  deploy + seed + deployments JSON
deployments/            output deploy per chain id
docs/
  uniswap-v2-research.md turunan x*y=k, tabel impact, impermanent loss
  security-review.md     10 temuan dengan severity dan status
devlog/                  jurnal harian: masalah, kenapa, solusi
SPEC.md                  spesifikasi final (1 Okt)
```

## Referensi

- `SPEC.md` untuk keputusan desain lengkap (termasuk edge case E1-E14 dan invariant I-a..I-d).
- `docs/uniswap-v2-research.md` untuk math dari first principles.
- `docs/security-review.md` untuk tabel temuan keamanan.
- `devlog/` untuk jurnal pengerjaan per tanggal (termasuk cerita fuzz overflow 2 Okt dan deploy L2 6 Okt).
- Pola kode: Uniswap v2 core (`UniswapV2Pair.sol`).
