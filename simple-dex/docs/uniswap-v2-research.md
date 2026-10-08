# Uniswap v2 Research: x*y=k dari First Principles

> Task roadmap: Rab 30 Sep 2026, "AMM Research: Uniswap v2. Baca Uniswap v2 whitepaper + core contracts. Pahami x*y=k formula secara mendalam. Simulasikan di spreadsheet: apa yang terjadi ke price dan liquidity saat ada swap besar? Pahami impermanent loss math."
> Catatan jujur: materi dipelajari 30 Sep, tapi dokumen finalnya baru dirampungkan 6 Okt saat sesi dokumentasi (catch-up task). Semua angka di sini dihitung dengan integer math yang identik dengan pembagian EVM (floor division), bukan dikutip dari run kontrak. Vektor eksaknya cocok dengan test di `test/AMMLibrary.t.sol` dan `test/DexPairSwap.t.sol`.

---

## 1. Model dasar: konstanta produk

Pool AMM Uniswap v2 menyimpan dua token, sebut reserves `x` (token in) dan `y` (token out). Aturan satu-satunya yang dipaksa kontrak:

```
(x + dx) * (y - dy) = x * y
```

Maknanya: swap TIDAK menambah likuiditas. Yang dilakukan trader cuma memindahkan pool di sepanjang kurva `x*y = k`. `k` berubah hanya kalau LP menambah/menarik likuiditas (atau, dengan fee, tumbuh pelan, lihat section 3).

Dari persamaan itu, output swap diturunkan langsung:

```
(x + dx) * (y - dy) = x * y
y - dy = x * y / (x + dx)
dy = y - x*y/(x + dx)
dy = y * (x + dx - x) / (x + dx)
dy = y * dx / (x + dx)
```

Jadi tanpa fee: `dy = y * dx / (x + dx)`.

Contoh cepat: pool 100/100, swap 10: `dy = 100*10/110 = 9.0909...`.

Ini yang bikin AMM jalan tanpa order book: harga spot `y/x` bergerak tiap swap, dan arbitrageur yang menjaga harga mendekati harga pasar luar, karena kalau spot menyimpang, membeli token murah di pool lalu menjual di tempat lain itu profitable. Convexity kurva juga bikin swap makin besar makin mahal per unit: swap 10% pool harganya lebih jelek dari swap 1% (tabel di section 4).

## 2. Fee 0.3%: kenapa masuk sebagai faktor di amountIn

Uniswap v2 memotong fee 0.3% dari INPUT, bukan dari output. Efektifnya cuma sebagian input yang ikut main di persamaan produk:

```
dx_eff = dx * 997 / 1000
(x + dx_eff) * (y - dy) = x * y
```

Kenapa di sisi input: (a) rumusnya tetap bentuk yang sama, tinggal menskalakan `dx`; (b) fee otomatis tinggal di pool dalam bentuk token input, jadi `k` tumbuh tiap swap dan itu yang jadi pendapatan LP; (c) kalau fee dipotong dari output, perhitungan jadi dua langkah dan pembulatannya lebih rawan bocor ke trader.

Selesaikan untuk `dy`:

```
dy = y * dx_eff / (x + dx_eff)
   = y * (dx*997/1000) / (x + dx*997/1000)
```

Kalikan pembilang dan penyebut dengan 1000 supaya bebas pecahan:

```
dy = (dx * 997 * y) / (x * 1000 + dx * 997)
```

Itu persis rumus di `src/AMMLibrary.sol::getAmountOut`:

```
amountOut = (amountIn * 997 * reserveOut) / (reserveIn * 1000 + amountIn * 997)
```

Pembagian integer di EVM floor, jadi dust pembulatan (paling banyak < 1 wei) tinggal di pool. Arah pembulatan selalu menguntungkan pool: output di-floor, required input di-ceil (+1 wei di `getAmountIn`).

## 3. Bukti bahwa k naik setelah swap berfee

Sebelum swap: `k0 = x * y`. Sesudah: `k1 = (x + dx) * (y - dy)` dengan `dy` versi berfee (pakai `dx_eff` di persamaan produk, tapi pool menerima `dx` penuh).

Karena `(x + dx_eff) * (y - dy) = x * y` dan `dx > dx_eff`:

```
k1 = (x + dx) * (y - dy) > (x + dx_eff) * (y - dy) = x * y = k0
```

Angka nyata, pool 100/100 swap 10 (18 desimal, hasil python integer math yang sama dengan library):

- `k` sebelum = 100e18 * 100e18 = 1e40
- out = 9066108938801491315 wei, jadi reserves baru (110e18, 90933891061198508685)
- `k` sesudah = 1.000272801673183595535e40, lebih besar dari `k0`

Selisihnya ~0.0248 token input adalah fee yang mengendap di pool. Properti ini dikunci fuzz: `testFuzz_GetAmountOut_ProductNeverDecreases` dan, di level pair, `test_Swap_ProductNeverDecreases_FeeStaysInPool` plus handler invariant I-a.

## 4. Simulasi swap besar: pool 100/100

Semua baris dihitung dengan rumus section 2, integer floor, dalam wei (18 desimal). Kolom "out tanpa fee" adalah `dx*y/(x+dx)` untuk pembanding.

| Swap (% pool) | amountIn | amountOut (wei) | amountOut (token) | Harga eksekusi | Price impact | Harga marginal sesudah | Out tanpa fee |
|---|---|---|---|---|---|---|---|
| 1% | 1e18 | 987158034397061298 | 0.9871580344 | 0.987158 | 1.28% | 0.980325 | 0.9901 |
| 10% | 10e18 | 9066108938801491315 | 9.0661089388 | 0.906611 | 9.34% | 0.826672 | 9.0909 |
| 25% | 25e18 | 19951971182709625775 | 19.9519711827 | 0.798079 | 20.19% | 0.640384 | 20.0000 |
| 50% | 50e18 | 33266599933266599933 | 33.2665999333 | 0.665332 | 33.47% | 0.444889 | 33.3333 |

Definisi dua kolom harga (ini yang sering bikin bingung, termasuk gw waktu mengerjakan):

- **Harga eksekusi** = amountOut / amountIn, harga rata-rata yang benar-benar didapat trader. Untuk swap 10%: 9.0661/10 = 0.906611, padahal spot sebelum swap 1.0, jadi price impact = (1 - 0.906611)/1 = 9.34%. Angka 9.34% inilah yang dipakai sebagai acuan "price impact ~9.34%" untuk vektor test 10% pool.
- **Harga marginal sesudah** = y'/x' setelah swap selesai. Untuk swap 10%: (100 - 9.0661)/110 = 0.826672, turun 17.33% dari spot awal. Ini harga untuk WEI BERIKUTNYA, bukan harga rata-rata swap tadi. Marginal selalu lebih jelek dari eksekusi karena kurva makin curam sepanjang swap.

Baris 10% adalah vektor eksak `test_GetAmountOut_ExactHalfPool` (9066108938801491315 wei), baris 1% adalah vektor `test_GetAmountOut_ExactSmallSwap` (987158034397061298 wei).

Pelajaran praktis untuk swap UI (task 7 Okt): price impact yang ditampilkan ke user harus dari rumus eksekusi ini, dihitung SEBELUM swap, dan dipasangkan dengan `amountOutMin` supaya user bisa menolak eksekusi yang lebih jelek dari toleransi.

## 5. Impermanent loss (IL)

Skenario: LP deposit 1 token0 + 1 token1 ke pool 1:1 (posisi awal x=1, y=1, k=1). Harga token0 naik sehingga rasio harga jadi `r` (r = harga akhir / harga awal). Bandingkan nilai portofolio LP vs cukup HODL 1 + 1 token.

Pool rebalance sendiri lewat arbitrage. Di titik harga baru, isi pool adalah `x = 1/sqrt(r)` dan `y = sqrt(r)` (cek: `x*y = 1 = k`, dan `y/x = r`, harga spot cocok). Nilai posisi LP dalam unit token1:

```
V_LP  = x*P + y = r/sqrt(r) + sqrt(r) = 2*sqrt(r)
V_HODL = 1*P + 1 = r + 1
```

IL sebagai fraksi (negatif = rugi dibanding HODL):

```
IL(r) = V_LP / V_HODL - 1 = 2*sqrt(r)/(1+r) - 1
```

Tabel (tiap kolom dihitung dari rumus di atas, dibulatkan 2 desimal persen):

| r | 2*sqrt(r) | 1+r | IL | IL (2 desimal) |
|---|---|---|---|---|
| 1.25 | 2.2360679775 | 2.25 | -0.006192 | 0.62% |
| 1.5 | 2.4494897428 | 2.50 | -0.020204 | 2.02% |
| 2 | 2.8284271247 | 3.00 | -0.057191 | 5.72% |
| 3 | 3.4641016151 | 4.00 | -0.133975 | 13.40% |
| 4 | 4.0000000000 | 5.00 | -0.200000 | 20.00% |
| 5 | 4.4721359550 | 6.00 | -0.254644 | 25.46% |

Sifat yang penting dipahami:

- IL = 0 persis di r = 1, dan naik mulus untuk pergerakan sekecil apapun (r=1.25 sudah 0.62%).
- Simetris: r dan 1/r menghasilkan IL yang sama (harga naik 2x vs turun 2x, ruginya sama).
- Makin besar pergerakan makin dalam, tapi bounded: saat r -> tak hingga, IL mendekati 100% (posisi LP tinggal hampir seluruhnya token yang harganya jatuh).
- Fee 0.3% yang mengendap di pool adalah kompensasi untuk IL. Untuk pool volatil, fee bisa kalah dari IL; itulah kenapa "menjadi LP" bukan income gratis.

Catatan jujur soal tabel: angka IL yang beredar di banyak artikel sering dikutip tanpa rumus. Gw menurunkan dari `2*sqrt(r)/(1+r) - 1` dan menghitung tiap baris di python; pas cek silang, nilai umum (1.25 -> 0.6%, 2 -> 5.7%, dst) cocok.

## 6. MINIMUM_LIQUIDITY: kenapa ada

Tanpa MINIMUM_LIQUIDITY, dua masalah muncul di first provision:

1. **Division by zero / share jadi 100%.** LP pertama yang deposit winy (mis. 1 wei + 1 wei) pegang 100% share. Setelah dia keluar total, totalSupply balik ke 0 dan setiap formula `amount * totalSupply / reserve` di provision berikutnya jadi degenerate; tepat setelah dia keluar sebagian, reserves bisa menyentuh 0 di salah satu sisi dan `getAmountOut` revert `InsufficientLiquidity`.
2. **LP inflation attack.** LP pertama bisa menanam share hampir 100% dengan deposit debu, menyisakan numerator mungil bagi depositor kedua, lalu menarik likuiditas dan menyedot sebagian besar deposit korban.

Fix Uniswap v2: pada first provision, mint `liquidity = sqrt(amount0 * amount1)` dan kunci 1000 wei LP secara permanen (`MINIMUM_LIQUIDITY`). Konsekuensinya totalSupply gak pernah di bawah 1000, share siapapun gak pernah 100%, dan reserves gak pernah 0.

Di SimpleDex (`src/DexPair.sol`): `liquidity <= MINIMUM_LIQUIDITY` di-reject (`DexPair__InsufficientLiquidityMinted`), dan 1000 wei LP di-mint ke `address(this)` (bukan `address(0)` ala v2, karena OZ v5 melarang mint ke zero address; efeknya identik, tidak ada entry point yang bisa membakar LP milik pair). Bukti nyata di test `test_FirstProvision_MinimumLiquidityLockedForever`: setelah alice burn SEMUA LP miliknya, sisa reserves 667 dan 1500 wei, persis share 1000 LP terkunci (666.67 eksak) ditambah dust floor 1 wei dari pembulatan payout alice sendiri; kedua sisi tetap gak pernah 0.

## 7. Kenapa LP first provision = sqrt(amount0 * amount1)

Geometric mean dipilih supaya hasilnya simetris dan konsisten dengan formula provision berikutnya:

- **Simetri urutan deposit.** `sqrt(a*b) = sqrt(b*a)`, jadi deposit (4, 9) dan (9, 4) menghasilkan LP yang sama persis. Dikunci test `test_FirstProvision_GeometricMeanIsDepositOrderIndependent`.
- **Konsisten dengan formula share selanjutnya.** Depositor kedua yang deposit proporsional menerima `amount * totalSupply / reserve`. Kalau LP pertama pakai geometric mean, depositor kedua yang deposit di rasio yang sama menerima LP proporsional eksak terhadap kontribusinya, gak peduli berapa besar pool awalnya.
- **Arithmetic mean (a+b)/2 gak bisa dipakai:** gak simetris terhadap unit, dan bikin depositor kedua bisa kebulat lewat pilihan urutan/ukuran deposit.

Contoh dari test: deposit (4e18, 9e18) memberi `sqrt(36e36) = 6e18` LP eksak.

## 8. Mapping ke implementasi SimpleDex

| Konsep riset | Lokasi di kode | Test yang mengunci |
|---|---|---|
| Turunan amountOut berfee | `AMMLibrary.getAmountOut` | `test_GetAmountOut_ExactHalfPool`, `test_GetAmountOut_ExactSmallSwap`, `testFuzz_GetAmountOut_NeverDrainsPool` |
| k gak pernah turun | properti produk | `testFuzz_GetAmountOut_ProductNeverDecreases`, invariant I-a |
| Invers dengan fee (ceil +1) | `AMMLibrary.getAmountIn` | `test_GetAmountIn_Exact`, `testFuzz_GetAmountIn_ConsistentWithGetAmountOut` |
| Harga bergerak sesuai arah swap | spot = r1/r0 | `test_Swap_ZeroForOne_PushesToken0PriceDown`, `test_Swap_OneForZero_PushesToken0PriceUp` |
| IL (bukan kode, tapi konteks LP) | n/a | n/a (dokumen ini) |
| MINIMUM_LIQUIDITY | `DexPair.MINIMUM_LIQUIDITY` + first provision | `test_FirstProvision_MinimumLiquidityLockedForever`, `test_FirstProvision_TooSmallReverts` |
| sqrt geometric mean | `AMMLibrary.sqrt` (Babylonian) | `test_Sqrt_ExactVectors`, `testFuzz_Sqrt_FloorBounds` |

Satu domain yang penting diingat dari riset ini: rumus di atas dijamin aman dari overflow selama reserves dan amount muat di ~112 bit (konvensi `uint112` Uniswap v2). Di luar domain itu `getAmountOut` PANIC (revert, failure-safe). Cerita lengkapnya di `docs/security-review.md` section integer precision, kejadian aslinya ada di `devlog/2026-10-02-core-math.md`.

## Referensi

- Uniswap v2 whitepaper dan kontrak core (`UniswapV2Pair.sol`, `UniswapV2Library.sol`), khususnya `getAmountOut`/`getAmountIn` dan `_mint` first provision.
- Implementasi gw sendiri: `src/AMMLibrary.sol`, `src/DexPair.sol`, `SPEC.md`.
- `docs/security-review.md` untuk sisi keamanan math dan domain overflow.
