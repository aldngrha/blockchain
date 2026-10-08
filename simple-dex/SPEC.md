# SimpleDex: Spesifikasi Final

> Status: **FINAL** (Design + Spec, Kam 1 Okt 2026)
> Implementasi math mulai Jum 2 Okt sesuai ROADMAP.md, security review Sen 5 Okt, deploy Sel 6 Okt.
> Acuan gaya kode: Uniswap v2 core. Acuan testing: suite `test/` (forge) + invariant handler.

---

## 1. Goal & Non-Goals

**Goal:** AMM constant-product (gaya Uniswap v2) minimal tapi production-pattern: satu pair 2 token, addLiquidity / removeLiquidity / swapExactTokensForTokens, LP token sebagai bukti porsi pool. Ini project portfolio kedua, kodenya harus bisa dijelaskan baris per baris ke interviewer.

**Non-Goals (v1):**
- Gak ada factory. Satu pair = satu kontrak yang di-deploy manual dengan 2 address token.
- Gak ada TWAP oracle. Spot price di v1 BUKAN sumber harga (lihat `docs/security-review.md`).
- Gak ada dukungan fee-on-transfer. Token yang makan fee di-reject aktif, bukan diakomodasi.
- Gak ada protocol fee switch (0.3% semuanya buat LP).
- Gak ada flash swap, gak ada price oracle cumulative, gak ada skim/sync ala v2.
- Gak ada frontend di tahap ini (swap UI Rabu 7 Okt).

**Pola utama yang dilatih:** constant product x*y=k, LP share math (geometric mean + proportional min), checks-effects-interactions, reentrancy lock gaya v2, custom errors, property-based + invariant testing.

---

## 2. Arsitektur

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

Keputusan desain besar (deviasi disengaja dari v2, konsisten dengan kode):

1. **Explicit-amount API.** User `approve` lalu panggil `addLiquidity/swap`; `transferFrom` dilakukan DI DALAM pair. v2 pakai alur "kirim token dulu, baru call". Konsekuensinya: gak ada flash swap, tapi UX jelas dan gak butuh factory untuk recover dust.
2. **CEI (checks-effects-interactions) + `lock` modifier.** Reserves dan LP di-update SEBELUM transfer eksternal. v2 aslinya update state BELAKANGAN (optimistic transfer) dan mengandalkan `lock`. Di sini `lock` tetap ada sebagai defense in depth dengan paritas pola v2 (bool `unlocked`, satu slot, bukan ReentrancyGuard OZ).
3. **MINIMUM_LIQUIDITY (1000 wei LP) di-mint ke `address(this)`.** v2 mint ke `address(0)`; OZ v5 melarang mint ke zero address. Efeknya identik: 1000 wei LP gak bisa diklaim selamanya, first-depositor share inflation keblokir, reserve gak pernah 0.
4. **Fee-on-transfer ditolak aktif.** Setiap transferFrom input dicek saldo aktual; kalau yang datang kurang dari nominal, revert `DexPair__FeeOnTransferNotSupported`. Berlaku di addLiquidity DAN swap.
5. **LP token = kontrak pool itu sendiri** (DexPair extends ERC20, nama "SimpleDex LP Token", simbol "SDX-LP"). Hemat kontrak, persis pola v2.

---

## 3. AMMLibrary (pure math)

Solidity `^0.8.20`, library internal, semuanya `pure` biar gampang dites tanpa state.

### Constants
| Nama | Nilai | Catatan |
|---|---|---|
| `FEE_NUMERATOR` | `997` | Fee 0.3% dikodekan 997/1000 (konvensi v2) |
| `FEE_DENOMINATOR` | `1000` | |

### Functions
| Signature | Behavior | Arah pembulatan |
|---|---|---|
| `getAmountOut(amountIn, reserveIn, reserveOut)` | Output max token lawan setelah fee 0.3%: `(in*997*rOut) / (rIn*1000 + in*997)` | Floor, dust fee tinggal di pool |
| `getAmountIn(amountOut, reserveIn, reserveOut)` | Input minimum untuk dapat `amountOut`; invers getAmountOut | Ceil `+1` wei, pool gak pernah subsidi |
| `quote(amountA, reserveA, reserveB)` | Pasangan seimbang di rasio reserve: `a*rb/ra` | Floor |
| `sqrt(y)` | Akar kuadrat integer (Babylonian), `floor(sqrt(y))` | Floor |

Rumus `getAmountOut` diturunkan dari x*y=k dengan fee di sisi input:
```
(rIn + in*997/1000) * (rOut - out) = rIn * rOut
=> out = (in * 997 * rOut) / (rIn * 1000 + in * 997)
```
Turunan lengkap + tabel numerik ada di `docs/uniswap-v2-research.md`.

---

## 4. DexPair

Solidity `^0.8.20`, OZ v5 (`ERC20`, `SafeERC20`, `Math`).

### State
| Var | Tipe | Keterangan |
|---|---|---|
| `MINIMUM_LIQUIDITY` | `uint256` constant | `1000`, LP terkunci permanen di pair |
| `token0` | `address` immutable | Token address lebih kecil (diurutkan di constructor) |
| `token1` | `address` immutable | Token address lebih besar |
| `reserve0` / `reserve1` | `uint256` | Pembukuan internal, harus selalu = saldo aktual |
| `unlocked` | `bool` private | Reentrancy lock gaya v2 (modifier `lock`) |
| ERC-20 standar | | `name="SimpleDex LP Token"`, `symbol="SDX-LP"`, 18 desimal |

### Functions
| Signature | Access | Behavior |
|---|---|---|
| `constructor(tokenA, tokenB)` | | Urutkan token, revert kalau identik / zero address |
| `addLiquidity(amount0Desired, amount1Desired)` | lock | Return `(amount0, amount1, liquidity)`. Pool kosong: LP = `sqrt(a0*a1)`, mint 1000 ke pair + sisanya ke caller, ambil semua yang diinginkan. Pool isi: snap ke rasio via `quote`, ambil sisi optimal, LP = `min(a0*ts/r0, a1*ts/r1)`, kelebihan gak ditarik (refund by not pulling). Cek saldo aktual tiap input (anti fee-on-transfer) |
| `removeLiquidity(lpAmount)` | lock | Burn LP, kembalikan proporsional `(lp*r0/ts, lp*r1/ts)` floor terhadap supply SEBELUM burn. Payout 0 di salah satu sisi di-reject (`InsufficientLiquidityBurned`) |
| `swapExactTokensForTokens(amountIn, amountOutMin, deadline, zeroForOne)` | lock | `amountOut = getAmountOut(...)`; reject kalau 0 atau < amountOutMin; reject kalau `block.timestamp > deadline`; update reserve (CEI); transferFrom input dengan verifikasi saldo; transfer output |
| `getReserves()` | view | `(reserve0, reserve1)` urutan kanonik |

### Errors
`DexPair__Locked`, `DexPair__IdenticalAddresses`, `DexPair__ZeroAddress`, `DexPair__ZeroAmount`, `DexPair__Expired`, `DexPair__InsufficientOutput`, `DexPair__InsufficientLiquidityMinted`, `DexPair__InsufficientLiquidityBurned`, `DexPair__FeeOnTransferNotSupported`.

### Events
`Mint(sender, amount0, amount1)`, `Burn(sender, amount0, amount1)`, `Swap(sender, zeroForOne, amountIn, amountOut)`, `Sync(reserve0, reserve1)`.

---

## 5. LP Math (pahami sebelum baca test)

**First provision** (totalSupply == 0):
```
liquidity = sqrt(amount0 * amount1)      // geometric mean
require liquidity > 1000
mint 1000 ke pair, mint (liquidity - 1000) ke provider
```
Geometric mean bikin share depositor kedua gak tergantung urutan deposit.

**Provision berikutnya:**
```
amount1Optimal = quote(amount0Desired, r0, r1)
kalau amount1Optimal <= amount1Desired : (amount0, amount1) = (desired0, amount1Optimal)
selain itu                            : (amount0, amount1) = (quote(desired1, r1, r0), desired1)
liquidity = min(amount0 * ts / r0, amount1 * ts / r1)
```
Sisi yang "lebih murah" yang jadi patokan (min), kelebihan gak pernah ditarik.

**Remove:**
```
amount0 = lp * r0 / ts ; amount1 = lp * r1 / ts   (ts = totalSupply sebelum burn)
```
Dust pembulatan tinggal di pool, mem-backing 1000 LP terkunci.

---

## 6. Edge Cases (wajib ada testnya)

| # | Kasus | Expected |
|---|---|---|
| E1 | `addLiquidity` dengan salah satu amount 0 | Revert `DexPair__ZeroAmount` |
| E2 | First provision terlalu kecil, `sqrt(a0*a1) <= 1000` | Revert `InsufficientLiquidityMinted`, state gak berubah |
| E3 | Deposit tidak seimbang | Ambil sisi optimal saja, kelebihan gak ditarik, LP = min-formula |
| E4 | `removeLiquidity(0)` | Revert `DexPair__ZeroAmount` |
| E5 | Remove melebihi balance LP | Revert `ERC20InsufficientBalance` (dari `_burn`) |
| E6 | Remove debu, payout floor ke 0 di satu sisi | Revert `InsufficientLiquidityBurned`, gak ada dana nyangkut |
| E7 | Remove semua LP milik user | Pool masih pegang share 1000/totalSupply, reserve gak pernah 0 |
| E8 | `swap` amountIn 0 | Revert `DexPair__ZeroAmount` |
| E9 | `swap` output floor ke 0 (input debu) | Revert `InsufficientOutput` |
| E10 | `swap` dengan `amountOutMin` > output aktual | Revert `InsufficientOutput` (slippage) |
| E11 | `swap` setelah deadline | Revert `DexPair__Expired`; deadline == block.timestamp masih valid |
| E12 | `swap` ke pool kosong | Revert `AMMLibrary__InsufficientLiquidity` |
| E13 | Token fee-on-transfer di addLiquidity / swap | Revert `FeeOnTransferNotSupported`, saldo aktual dicek |
| E14 | Reentrancy dari token jahat | Diblok `lock` + state sudah final sebelum transfer (CEI) |

---

## 7. Invariants (suite handler, `test/invariant/`)

Handler: 3 aktor + 1 lpOwner, pool di-seed (1000e18, 1000e18), aksi acak add/remove/swap/warp, `fail_on_revert = true` (catatan: key TOML-nya snake_case, `fail-on-revert` diabaikan Foundry diam-diam, ini bikin assert handler tadinya ke-swallow).

- **I-a** k = reserve0*reserve1 gak pernah turun akibat swap. Dicek di handler tepat setiap swap + echo final.
- **I-b** Solvency: saldo token aktual pair == reserve tercatat, dua-duanya.
- **I-c** LP accounting: `totalSupply == ghost_lpMinted - ghost_lpBurned`.
- **MINIMUM_LIQUIDITY terkunci**: supply gak pernah < 1000 dan share-nya selalu di pair.
- **I-d** Remove proporsional eksak terhadap supply sebelum burn (dicek tiap remove di handler).
- **LP backing**: jumlah klaim proporsional semua holder <= reserve, dust <= 1 wei per holder.

Konfigurasi: `runs = 100`, `depth = 32`, `fail_on_revert = true` di foundry.toml. Naikkan via env `FOUNDRY_INVARIANT_RUNS=256 FOUNDRY_INVARIANT_DEPTH=64` sebelum deploy serius.

---

## 8. Test Plan (mapping ke jadwal)

- **Jum 2 Okt, AMMLibrary:** vektor eksak hasil hitung manual (python), property fuzz (monoton, k gak turun, round-trip getAmountIn/getAmountOut, bound sqrt), revert cases. Ada di `test/AMMLibrary.t.sol`.
- **Sab 3 Okt, liquidity:** first provision sqrt eksak + lock 1000, proporsional & unbalanced + refund, min-formula LP, revert E1..E7, sorting constructor, events. Ada di `test/DexPairLiquidity.t.sol`.
- **Min 4 Okt, swap:** vektor output eksak, arah pergerakan harga, slippage, deadline, E8..E12, k gak turun, LP gak tersentuh, events. Ada di `test/DexPairSwap.t.sol`.
- **Sen 5 Okt, security + invariant:** suite I-a..I-d + fuzz lintas fungsi. Ada di `test/invariant/`.
- **Gate:** `forge build` exit 0, `forge test` semua hijau, deploy anvil terverifikasi via cast.

---

## 9. Deployment (Sel 6 Okt)

**Anvil (terotomasi, sudah diverifikasi):**
1. `anvil -p 8548` (port khusus biar gak tabrak anvil default).
2. `PRIVATE_KEY=0xac09...ff80 forge script script/DeploySimpleDex.s.sol:DeploySimpleDex --rpc-url http://127.0.0.1:8548 --broadcast`
3. Script deploy 2 ERC20Mock + DexPair, mint 10.000e18/token ke deployer, seed 1000e18 + 1000e18, tulis `deployments/<chainId>.json` (chainId, deployedAt epoch ms string, deployer, contracts).
4. Assert via `cast call`: getReserves = (1000e18, 1000e18), LP deployer = 1e21 - 1000, saldo token pair = reserve.

**Arbitrum Sepolia (langkah manual, butuh kredensial gw sendiri):**
1. Siapkan RPC publik (mis. `https://sepolia-rollup.arbitrum.io/rpc`) dan faucet ETH Arbitrum Sepolia.
2. `export PRIVATE_KEY=...` (jangan key yang dipakai mainnet), lalu:
   `forge script script/DeploySimpleDex.s.sol:DeploySimpleDex --rpc-url $ARBITRUM_SEPOLIA_RPC --broadcast`
3. Bandingkan gas L1 vs L2 dari `broadcast/*.json` (field gas used) terhadap deploy kontrak serupa di Ethereum Sepolia. Angka apa pun yang gw tulis di README itu ESTIMASI/perbandingan lokal, bukan klaim hasil bill mainnet.
4. Verifikasi kontrak di explorer (Arbiscan Sepolia) kalau API key tersedia.

Kenapa L2 murah (ringkas, detail di devlog 6 Okt): Optimistic Rollup mengeksekusi tx di L2, L1 cuma menyimpan batch data (calldata/blobs). Biaya tx L2 = biaya L2 yang kecil + share biaya data availability L1. Optimistic = fraud proof dengan window challenge ~7 hari; ZK = validity proof, finalitas cepat tapi mahal prover-nya.

---

## 10. Definition of Done

- [x] `forge build` exit 0.
- [x] `forge test` hijau semua: 18 (library) + 17 (liquidity) + 11 (swap) + 5 (invariant) = 51 test.
- [x] Semua edge case E1..E14 punya test eksplisit (E13/E14 di liquidity + review dokumen).
- [x] Invariant I-a..I-d jalan dengan fail_on_revert = true, 0 revert handler.
- [x] Security review terdokumentasi (`docs/security-review.md`).
- [x] Deploy anvil 8548 terverifikasi via cast + smoke swap, JSON deployment format sesuai spec.
- [ ] Deploy Arbitrum Sepolia (langkah manual gw, butuh RPC + private key sendiri).
- [x] README lengkap: arsitektur, math ringkas, quickstart, status deploy jujur, "apa yang gak ada di v1".
