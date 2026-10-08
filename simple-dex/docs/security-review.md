# Security Review SimpleDex v1

> Task roadmap: Sen 5 Okt 2026, "AMM: Security + Edge Cases. Security review AMM: reentrancy di swap, price manipulation via flashloan, integer precision (pakai MINIMUM_LIQUIDITY). Fuzz test semua fungsi. Cek: tidak ada stuck funds, tidak ada drain pool."
> Basis review: `src/AMMLibrary.sol`, `src/DexPair.sol`, `SPEC.md`, dan hasil test hari itu (suite tumbuh dari 51 ke 53 test setelah 2 test domain boundary ditambahkan; total sekarang 53/53 hijau, diverifikasi 6 Okt: 20 library + 17 liquidity + 11 swap + 5 invariant). Review ini bukan audit formal dan tidak menggantikan audit pihak ketiga.

## Ringkasan temuan

| # | Temuan | Severity | Status |
|---|---|---|---|
| 1 | Reentrancy pada swap/addLiquidity/removeLiquidity | High (jika tanpa mitigasi) | Fixed (lock + CEI) |
| 2 | Spot price dipakai sebagai oracle (flashloan price manipulation) | High (untuk protocol lain yang percaya) | Didokumentasikan, TWAP di luar scope v1 |
| 3 | Overflow di luar domain math (getAmountOut/getAmountIn) | Medium | Didokumentasikan (+2 test boundary) |
| 4 | Arah pembulatan yang merugi pool | Low | Fixed by design (floor/ceil) |
| 5 | First depositor / LP inflation attack | Medium | Fixed (MINIMUM_LIQUIDITY + reserve internal), sisa risiko didokumentasikan |
| 6 | Slippage + deadline (sandwich dan stale execution) | Medium | Fixed (amountOutMin + deadline) |
| 7 | Fee-on-transfer merusak pembukuan | Medium | Fixed (aktif di-reject) |
| 8 | Reserves uint256 tanpa guard uint112 | Low | Didokumentasikan sebagai limitasi v1 |
| 9 | Stuck funds / dust payout | Low | Fixed (guard dust + invariant solvency) |
| 10 | Donasi langsung ke pair (griefing) | Low | Didokumentasikan (di luar scope v1) |

---

## 1. Reentrancy pada swap (High, fixed)

**Permukaan serangan.** `swapExactTokensForTokens` melakukan dua external call (`safeTransferFrom` token input, `safeTransfer` token output). Token ERC-777 atau ERC-20 dengan hook transfer bisa menjalankan kode penerima; itu pintu masuk reentrancy kalau state belum final. `addLiquidity` dan `removeLiquidity` punya external call yang sama.

**Mitigasi, dua lapis:**

1. **CEI (checks-effects-interactions).** Semua update state (reserves, mint/burn LP, emit event) selesai SEBELUM transfer eksternal pertama. Di titik transfer berjalan, state internal sudah final, jadi reentry lihat state yang konsisten (`src/DexPair.sol`, ketiga fungsi state-changing).
2. **Modifier `lock` gaya Uniswap v2.** `bool unlocked` + revert `DexPair__Locked` kalau fungsi state-changing dipanggil lagi di tengah eksekusi. Ini defense in depth: kalau suatu hari ada jalur kode yang melanggar CEI, lock masih memblokir reentry ke entry point manapun di pair.

**Bandingkan singkat dengan OZ `ReentrancyGuard`:** OZ pakai `uint256 _status` (NOT_ENTERED/ENTERED) dengan custom error `ReentrancyGuardReentrantCall`; DexPair pakai `bool unlocked`. Semantiknya sama, keduanya satu storage slot, dua-duanya nonReentrant lintas fungsi (reenter ke fungsi terproteksi lain juga keblokir). Pilihan bool tanpa inheritance diambil demi paritas dengan pola v2 yang dikenal semua auditor AMM, tanpa overhead abstract contract. Perbedaan kosmetik: OZ default-nya `false/1` semantics, bool di sini default `true`. Keduanya revert, bukan silent.

**Bukti:** `DexPair__Locked` ada di errors, CEI terlihat di urutan baris `swapExactTokensForTokens` (reserve update sebelum `_pullToken`/`safeTransfer`). Edge case E14 di SPEC. Tidak ada test yang mem-fake token reentrant di suite (mock yang ada cuma fee-on-transfer), jadi klaim kekuatan mitigasi ini dari inspeksi kode, bukan exploit test. Catat sebagai gap minor.

## 2. Spot price BUKAN oracle (High untuk konsumen, didokumentasikan)

`getReserves()` adalah view publik, dan spot price `reserve1/reserve0` bisa dipindahkan siapapun yang mau bayar biaya swap. Ini properti dasar AMM, bukan bug implementasi.

**Alur serangan klasik terhadap protocol yang memakai spot price SimpleDex sebagai sumber harga:**

1. Attacker pinjam flashloan dana besar (di protocol lending yang menyediakannya).
2. Swap besar di SimpleDex untuk memindahkan reserves, mis. pool 1000/1000 dibanjiri 10000 token0, spot price token0 jatuh drastis (rumus impact di `docs/uniswap-v2-research.md` section 4: swap 10% pool saja sudah 9.34%).
3. Protocol korban membaca `getReserves()` dan mengeksekusi sesuatu berdasarkan harga palsu itu (mis. liquidasi posisi dengan harga yang diperhitungkan salah, atau mint/membayar berdasarkan collateral yang dinilai murah).
4. Attacker swap balik, bayar flashloan + fee, sisa jadi profit. Semua dalam satu transaksi.

**Posisi SimpleDex v1:** tidak ada fungsi `price()` dan tidak ada konsumen oracle di repo ini, jadi v1 sendiri tidak diekspose. Tapi Dokumen ini menegaskan: **SimpleDex v1 tidak boleh dijadikan sumber harga untuk protocol lain.** Siapapun yang butuh harga dari pool ini butuh TWAP (time-weighted average price, akumulator `priceCumulative` ala v2 yang di-update tiap touch), dan itu non-goal v1 (lihat SPEC section 1). Implementasi TWAP nyata juga harus menangani window, manipulasi multi-block, dan stale checkpoint, jadi bukan tambahan sepele.

## 3. Integer precision: domain overflow getAmountOut/getAmountIn (Medium, didokumentasikan)

Ini satu-satunya temuan yang DITEMUKAN oleh test, bukan oleh bacaan kode.

**Kejadian nyata (5 Okt):** fuzz test `testFuzz_GetAmountIn_ConsistentWithGetAmountOut` gagal dengan panic 0x11 (arithmetic overflow). Counterexample yang ditemukan fuzzer:

- `amountOut = 1329227995784915872903807060280344572` (sekitar 2^120, tepatnya 2^120 - 4)
- `reserveIn = 10756`
- `reserveOut = 1329227995784915872903807060280344574` (2^120 - 2)

**Root cause, langkah per langkah (dihitung eksak, formula `getAmountIn` di `src/AMMLibrary.sol`):**

1. `numerator = reserveIn * amountOut * 1000`, `denominator = (reserveOut - amountOut) * 997 = 2 * 997 = 1994`.
2. `requiredIn = numerator/1994 + 1 = 7170098456701381709605490842715840630107` (sekitar 7.17e39). reserveIn yang mungil relatif terhadap amountOut membuat requiredIn meledak.
3. `requiredIn` jauh di atas 2^112 = 5192296858534827628530496329220096 (sekitar 5.19e33), sekitar 1.38 juta kali lipat.
4. Round-trip memanggil `getAmountOut(requiredIn, ...)`: `amountInWithFee = requiredIn * 997` (sekitar 7.15e42) lolos, lalu `amountInWithFee * reserveOut` = sekitar 9.5e78, melewati 2^256 (sekitar 1.158e77). PANIC 0x11.

**Kenapa ini bukan bug math:** rumusnya benar dalam domainnya. Yang kurang adalah dokumentasi domain. Konvensi Uniswap v2 menyimpan reserves sebagai `uint112` PERSIS supaya `amountIn * 997 * reserveOut <= 2^112 * 2^10 * 2^120 < 2^256` dan produk internal tidak pernah overflow. Di luar domain itu perilakunya panic, dan panic itu failure-safe: transaksi revert, tidak ada state change, tidak ada dana pindah.

**Keputusan fix (tanpa mengubah math):**

- Fuzz round-trip dibatasi domain: `vm.assume(requiredIn <= type(uint112).max)` di `testFuzz_GetAmountIn_ConsistentWithGetAmountOut`.
- Dua test baru di `test/AMMLibrary.t.sol`:
  - `test_GetAmountIn_RoundTripOutsideDomainPanics`: mengunci perilaku di luar domain secara eksplisit pakai counterexample asli di atas, `vm.expectRevert(stdError.arithmeticError)`.
  - `test_GetAmountIn_RoundTripAtDomainEdge`: config ekstrem tapi dalam domain (requiredIn sekitar 1.002e15, masih di bawah 2^112) tetap round-trip `>= amountOut` berkat ceil +1.
- Natspec DOMAIN di `AMMLibrary.getAmountOut` mendokumentasikan batasnya: caller yang butuh range penuh uint256 harus membatasi input sendiri.

**Arah pembulatan selalu menguntungkan pool (fixed by design):**

| Fungsi | Arah | Efek |
|---|---|---|
| `getAmountOut` | floor | dust fee dan pembulatan tinggal di pool |
| `getAmountIn` | ceil (+1 wei) | pool tidak pernah mensubsidi round-trip |
| `quote` | floor | provision tidak pernah menarik kelebihan |
| `sqrt` | floor | LP first provision tidak pernah berlebih |
| LP mint | min dari dua sisi | share sesuai sisi yang lebih murah |
| removeLiquidity | floor terhadap supply SEBELUM burn | dust mem-backing 1000 LP terkunci |

Dikunci fuzz: `testFuzz_GetAmountIn_ConsistentWithGetAmountOut` (round-trip >=), `testFuzz_Quote_Proportional`, `testFuzz_Sqrt_FloorBounds`.

**MINIMUM_LIQUIDITY** juga bagian precision story: 1000 wei LP terkunci menjaga reserves tidak pernah menyentuh 0, jadi tidak ada division by zero di formula share, dan memberi floor anti-inflation (section 5).

## 4. First depositor / LP inflation attack (Medium, fixed dengan sisa risiko)

**Skema klasik** (adaptasi ERC-4626 inflation ke AMM): attacker menanam first provision dengan deposit debu agar pegang hampir 100% share, menggelembungkan denominator share, lalu deposit korban yang masuk kemudian menerima LP hampir nol padahal menyetor token sungguhan; attacker menarik likuiditas dan menyedot deposit korban.

**Mitigasi yang aktif di DexPair:**

1. `MINIMUM_LIQUIDITY = 1000` di-mint permanen ke pair pada first provision. First provision dengan `sqrt(a0*a1) <= 1000` di-revert, jadi tidak ada first provision yang memberi share 100%; porsi terkunci selalu ada. Dikunci `test_FirstProvision_MinimumLiquidityLockedForever` dan invariant I-3 (`invariant_I3_MinimumLiquidityLocked`).
2. Pembukuan berbasis reserves internal, bukan saldo mentah. LP yang di-mint dihitung dari `quote` dan jumlah yang BENAR-BENAR ditarik (explicit-amount API, `transferFrom` di dalam pair dengan verifikasi saldo). Donasi langsung ke pair menambah `balanceOf(pair)` tapi TIDAK menambah `reserve0/reserve1`, jadi tidak bisa menggelembungkan denominator share. Ini perbedaan dengan v2 yang men-capture saldo mentah lewat `_update` di tiap operasi.

**Sisa risiko yang jujur didokumentasikan:**

- Donasi ke pair jadi dana nyangkut: menambah saldo tapi bukan reserves, tidak bisa diklaim siapapun karena payout selalu dari reserves, dan v1 tidak punya `skim`/`sync` ala v2 untuk menyatukan kembali. Itu griefing (bisa mem-break mirror saldo == reserves yang dicek invariant I-b), bukan vektor pencurian. Kalau suatu hari ada fungsi resync dari saldo ke reserves, mitigasi (2) hilang dan attack surface lama kembali; MINIMUM_LIQUIDITY (1) tetap menjadi lapisan terakhir.
- Rounding dust per holder di bawah 1 wei (dikunci invariant I-4).

## 5. Slippage + deadline (Medium, fixed)

Tanpa parameter ini, user yang menandatangani/submit swap bisa dieksekusi di harga berapa pun: bot sandwich (frontrun swap besar + backrun) membuat trader bayar harga terburuk antara submit dan eksekusi, dan transaksi yang mengantri lama bisa dieksekusi di kondisi pool yang sudah berubah total.

DexPair: `swapExactTokensForTokens(amountIn, amountOutMin, deadline, zeroForOne)` dengan dua guard:

- `amountOut < amountOutMin` revert `DexPair__InsufficientOutput`. Semantik boundary: output PERSIS sama dengan min lolos (cek `<`, bukan `<=`), dikunci `test_Swap_SlippageReverts` termasuk kasus satu wei di atas output eksak.
- `block.timestamp > deadline` revert `DexPair__Expired`. Boundary: deadline == block.timestamp masih valid, dikunci `test_Swap_DeadlineReverts`.

Batas kejujuran: ini melindungi user DARI pool yang bergerak, tapi tidak melindungi dari orderflow yang dilihat builder/validator (mev-protect/pagging private adalah domain off-chain, di luar scope).

## 6. Fee-on-transfer merusak pembukuan (Medium, fixed)

Token yang memotong fee saat transfer membuat pair menerima lebih sedikit dari `amount` sementara reserves mencatat `amount` penuh. Semua rasio downstream (LP mint, output swap, payout withdraw) jadi salah, dan selisih itu bisa dieksploitasi (deposit lewat token FoT, klaim share atas saldo yang tidak pernah masuk).

DexPair menolak aktif: `_pullToken` membandingkan `balanceOf(pair)` sebelum vs sesudah `safeTransferFrom`; kalau delta != amount, revert `DexPair__FeeOnTransferNotSupported`. Berlaku di addLiquidity DAN swap (keduanya lewat `_pullToken`). Dikunci `test_AddLiquidity_FeeOnTransferRejected` (nothing minted, no reserves) dengan `FeeOnTransferMock` 1%.

## 7. Reserves uint256 tanpa guard uint112 (Low, didokumentasikan)

Limitasi v1 yang paling perlu dicatat untuk production-grade: `reserve0/reserve1` bertipe `uint256`, tidak ada guard yang memaksa nilai <= 2^112 (konvensi v2, lihat section 3). Konsekuensi: pada config ekstrem (input atau reserves raksasa), path math PANIC di titik perkalian internal. Panic itu failure-safe (revert, tanpa state change), jadi ini soal ergonomi dan jaminan, bukan kebocoran dana. Rekomendasi kalau naik kelas: simpan reserves sebagai `uint112` (opsi lain: explicit bound di `getAmountOut` yang mengembalikan error custom alih-alih panic), plus test domain yang sudah ada sebagai regression net.

## 8. Stuck funds / dust payout (Low, fixed)

- `removeLiquidity` yang payout-nya floor ke 0 di salah satu sisi di-reject (`DexPair__InsufficientLiquidityBurned`) supaya share debu tidak nyangkut diam-diam; dikunci `test_RemoveLiquidity_DustReverts`.
- Payout dihitung terhadap totalSupply SEBELUM burn; dust pembulatan tinggal di pool mem-backing LP terkunci.
- Solvency total dikunci invariant I-b: saldo token aktual pair == reserves tercatat, dua sisi, setelah SEQUENCE acak apapun (100 runs x 32 depth, fail_on_revert = true). Tidak ada jalur yang meninggalkan saldo phantom.

## 9. Yang belum dicover review ini (jujur)

- Tidak ada audit pihak ketiga dan tidak ada formal verification. Review ini manual + berbasis test.
- Slither/static analyzer belum di-run terhadap repo ini (tool belum ter-install di environment saat review). Direkomendasikan sebelum deploy ke testnet publik: `pip install slither-analyzer` lalu `slither .`.
- Tidak ada test reentrancy exploit end-to-end (mock token reentrant belum ada, lihat section 1). Mitigasi dinilai dari inspeksi CEI + lock.
- Invariant suite default 100 runs x 32 depth; naikkan sebelum deploy serius: `FOUNDRY_INVARIANT_RUNS=256 FOUNDRY_INVARIANT_DEPTH=64 forge test`.
