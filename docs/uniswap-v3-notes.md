# Uniswap v3: Concentrated Liquidity dari Whitepaper ke Source Code

> Task roadmap: **Rab 28 Okt 2026** ("Baca whitepaper penuh. Pahami concentrated liquidity, tick system, price range. Bandingkan dengan v2. Buat diagram arsitektur sendiri") dan **Kam 29 Okt 2026** ("Clone v3-core. Baca PoolManager, TickMath, SqrtPriceMath. Fokus di swap execution path. Tulis catatan: yang paling berbeda dari v2 adalah...").
>
> Sumber: [whitepaper v3](https://uniswap.org/whitepaper-v3.pdf), [v3-core](https://github.com/Uniswap/v3-core), [v3-periphery](https://github.com/Uniswap/v3-periphery), [docs Uniswap v3](https://docs.uniswap.org/contracts/v3/overview). Angka di section 9 dibaca langsung dari kontrak di Ethereum mainnet, bukan dari artikel.
>
> Catatan: roadmap menyebut "PoolManager". Itu nama di v4. Di v3-core kontraknya `UniswapV3Pool`, dan yang dibaca di sini adalah `UniswapV3Pool`, `TickMath`, `SqrtPriceMath`, `SwapMath`, `TickBitmap`, `Oracle`.

---

## 1. Masalah yang diselesaikan v3

Di v2, likuiditas disebar merata dari harga 0 sampai tak hingga. Padahal pasar hampir tidak pernah menyentuh harga 0 atau tak hingga. Konsekuensinya: sebagian besar modal LP tidak pernah dipakai untuk trade, dan slippage tetap tebal di harga yang benar-benar ditransaksikan.

v3 membalik asumsi itu: LP memilih **rentang harga** tempat likuiditasnya aktif. Di luar rentang itu, posisinya tidak lagi berupa campuran dua token, melainkan 100% salah satu token (atau tidak dipakai sama sekali). Efeknya, untuk kedalaman yang sama di harga tertentu, modal yang dibutuhkan jauh lebih sedikit.

Tiga perubahan struktural yang mengikuti keputusan itu:

1. **Posisi jadi non-fungible.** Dua LP dengan rentang berbeda tidak bisa diwakili satu token ERC-20. Karena itu posisi di v3 adalah NFT (`NonfungiblePositionManager`), bukan LP token.
2. **Butuh representasi harga yang presisi.** Rentang butuh diskretisasi, dan perhitungan bunga berjalan tanpa loop yang mahal. Jawabannya: tick dan `sqrtPriceX96`.
3. **Fee harus dibagi per rentang.** LP yang likuiditasnya tidak aktif di harga saat trade tidak boleh dapat fee. Ini butuh akuntansi fee per posisi, bukan sekadar per pool.

## 2. Tick: kenapa harga didiskretisasi

Harga di v3 bukan angka bebas. Setiap tick adalah kelipatan tetap dalam skala eksponensial:

```
price(tick) = 1.0001^tick
```

Tick 0 berarti harga 1. Satu tick = pergeseran 1 basis poin (0,01%). Batasnya `MIN_TICK = -887272` dan `MAX_TICK = 887272` di `TickMath.sol`, yang kira-kira setara harga `1.0001^-887272` sampai `1.0001^887272`.

Kenapa eksponensial, bukan linear? Karena yang penting bagi AMM adalah **perubahan relatif** harga, bukan selisih absolut. Dengan skala log, jarak antar tick selalu berarti persentase yang sama, di harga berapa pun. Ini juga yang membuat rentang bisa dinyatakan sebagai dua integer kecil (`tickLower`, `tickUpper`) yang muat di `int24`.

Tick yang boleh dipakai LP tidak sembarang: harus kelipatan `tickSpacing` milik pool. Tick spacing terikat ke fee tier, karena pool dengan fee lebih besar butuh butir harga lebih kasar supaya gas swap tetap wajar.

| Fee tier | `fee` | `tickSpacing` |
|---|---|---|
| 0,01% | 100 | 1 |
| 0,05% | 500 | 10 |
| 0,30% | 3000 | 60 |
| 1,00% | 10000 | 200 |

Dua baris tengah itu bukan hafalan: nilainya dibaca dari dua pool mainnet di section 9 (`fee()` dan `tickSpacing()`).

## 3. Kenapa akar harga, bukan harga

Kontrak tidak menyimpan `price`. Yang disimpan `slot0.sqrtPriceX96`, yaitu akar harga dikali `2^96`:

```
sqrtPriceX96 = sqrt(price) * 2^96
```

Alasannya matematis. Kalau `L` didefinisikan sebagai `sqrt(x * y)`, maka di dalam rentang:

```
x = L / sqrt(p)
y = L * sqrt(p)
```

Keduanya jadi **linear terhadap L** kalau yang disimpan `sqrt(p)`. Kalau yang disimpan `p`, hubungannya jadi tidak linear dan setiap perubahan likuiditas butuh pembagian yang lebih rawan pembulatan. Faktor `2^96` ada karena EVM tidak punya desimal: `sqrt(p)` dikalikan bilangan bulat besar supaya presisinya cukup saat `p` kecil (misal pool dengan token berharga sangat murah).

`L` sendiri bukan angka bebas. Di dalam rentang dengan harga sekarang `p`, likuiditas efektif pool adalah nilai `L` yang memenuhi dua persamaan di atas terhadap saldo nyata pool.

## 4. Rumus posisi: tiga kasus

Untuk posisi dengan likuiditas `L` dan rentang `[pa, pb]`, di mana `pa = 1.0001^tickLower` dan `pb = 1.0001^tickUpper`:

**Harga di dalam rentang (`pa <= p <= pb`):** posisi memegang kedua token.

```
amount0 = L * (1/sqrt(p)  - 1/sqrt(pb))
amount1 = L * (sqrt(p)    - sqrt(pa))
```

**Harga di bawah rentang (`p < pa`):** posisi 100% token0, karena token1 sudah habis terjual saat harga turun menembus batas bawah.

```
amount0 = L * (1/sqrt(pa) - 1/sqrt(pb))
amount1 = 0
```

**Harga di atas rentang (`p > pb`):** posisi 100% token1.

```
amount0 = 0
amount1 = L * (sqrt(pb) - sqrt(pa))
```

Konsekuensi yang sering bikin kaget: begitu harga keluar rentang, posisi berhenti menghasilkan fee **dan** berhenti mengikuti harga. LP yang rentangnya sempit di pool volatil bisa berubah jadi 100% token yang sedang turun, dan itu kerugian yang tidak terlihat di UI sebagai "impermanent loss" biasa.

## 5. Efisiensi modal: angka, bukan klaim

Ini yang paling sering dikutip sebagai "v3 sampai 4000x lebih efisien". Angka itu benar untuk definisi tertentu, tapi lebih aman menghitung sendiri. Metrik yang dipakai di sini:

- Nilai modal v3 = `amount0 + amount1/p` (semua dinormalkan ke token0 pada harga sekarang).
- Nilai modal v2 untuk **L yang sama** = `L/sqrt(p) + (L*sqrt(p))/p`.
- Rasio = v2 / v3.

Dengan `L = 1e18`, harga dari pool USDC/WETH 0,05% (tick 201341), tick spacing 10:

| Rentang | tickLower..tickUpper | amount0 | amount1 | Rasio modal v2/v3 |
|---|---|---|---|---|
| +-0,1% | 201330..201360 | 6,370e10 | 3,532e19 | 666,70x |
| +-1% | 201240..201450 | 4,459e11 | 2,472e20 | 95,24x |
| +-5% | 200850..201830 | 2,082e12 | 1,154e21 | 20,41x |
| +-10% | 200380..202300 | 4,079e12 | 2,261e21 | 10,41x |
| +-50% | 197280..205400 | 1,736e13 | 9,623e21 | 2,45x |

Yang perlu dibaca dari tabel ini: efisiensi **bukan angka tunggal**, tapi fungsi lebar rentang. Rentang 0,1% memberi 666x, rentang 50% cuma 2,45x. Whitepaper menyebut angka 4000x karena memakai normalisasi `L` dan definisi kedalaman yang berbeda dari metrik di sini, jadi jangan campur keduanya.

Dan efisiensi itu bukan hadiah gratis. Rentang sempit berarti:

- Peluang keluar rentang jauh lebih besar, dan setelah keluar tidak ada fee.
- Butuh rebalancing aktif, dan setiap rebalance itu biaya gas plus realisasi kerugian.
- Kerugian saat harga bergerak satu arah (divergence loss) terkonsentrasi di rentang sempit itu.

## 6. Diagram arsitektur

```
                        user / bot / aggregator
                                  |
                    +-------------+-------------+
                    |                           |
             SwapRouter02                  QuoterV2
        (multi-hop, callback bayar)   (simulasi off-chain, view)
                    |
                    v
        +--------------------------------------------------+
        |              UniswapV3Pool (core)                |
        |                                                  |
        |  slot0: sqrtPriceX96, tick, observation index    |
        |  liquidity: L aktif di tick sekarang             |
        |  ticks[tick]: liquidityGross, liquidityNet,      |
        |               feeGrowthOutside0/1X128            |
        |  tickBitmap: wordPos -> bitmap tick initialized  |
        |  positions[key]: liquidity, feeGrowthInsideLast  |
        |  observations[]: ring buffer untuk TWAP          |
        +------------------+-------------------------------+
                           |
        swap()  -----------+-----------> uniswapV3SwapCallback()
        (loop antar tick)                  (pembayar = pemanggil)
                           |
                           v
                 UniswapV3Factory
                 (getPool, enableFeeAmount, fee tier)

        NonfungiblePositionManager (periphery)
        - ERC721, satu tokenId = satu posisi
        - mint / increaseLiquidity / decreaseLiquidity / collect
        - pool melihatnya sebagai owner posisi biasa
```

Yang penting dari diagram ini: `UniswapV3Pool` **tidak** menyimpan daftar posisi per user. Yang disimpan `positions[keccak256(owner, tickLower, tickUpper)]`, dan `owner` untuk LP retail adalah alamat `NonfungiblePositionManager`. Jadi NFT-nya cuma lapisan kepemilikan di periphery, bukan bagian dari core.

## 7. Swap execution path di `UniswapV3Pool.swap`

Ini bagian yang diminta roadmap 29 Okt. Urutannya:

1. **Validasi awal.** `amountSpecified != 0`, `sqrtPriceLimitX96` harus di dalam `(MIN_SQRT_RATIO, MAX_SQRT_RATIO)` dan bergerak ke arah yang benar (`zeroForOne` menentukan batas atas atau bawah).
2. **Transfer token masuk lebih dulu.** Pool memindahkan `tokenIn` dari `msg.sender` ke dirinya sendiri **sebelum** loop. Ini yang membuat v3 aman dari callback yang tidak membayar: kalau pemanggil tidak punya saldo, transaksi gagal di langkah ini, bukan di akhir.
3. **Siapkan `SwapState`.** Isinya `amountSpecifiedRemaining`, `amountCalculated`, `sqrtPriceX96`, `tick`, `feeGrowthGlobalX128`, `protocolFee`, `liquidity`.
4. **Loop.** Selama masih ada sisa amount dan harga belum menyentuh limit:
   - Cari tick initialized berikutnya lewat `tickBitmap.nextInitializedTickWithinOneWord(tick, tickSpacing, zeroForOne)`. Ini yang membuat swap tidak perlu menyentuh tick kosong satu per satu, cukup lompat per word bitmap (256 tick per word).
   - Hitung harga target langkah: `sqrtPriceNextX96` = harga di tick berikutnya, dibatasi `sqrtPriceLimitX96`.
   - `SwapMath.computeSwapStep(sqrtPriceCurrent, sqrtPriceNext, liquidity, amountRemaining, feePips)` mengembalikan `(sqrtPriceNext, amountIn, amountOut, feeAmount)`. Fee diambil dari **input**, jadi yang masuk kurva hanya `amountIn - feeAmount`.
   - Update `feeGrowthGlobal0X128` atau `feeGrowthGlobal1X128` dengan `feeAmount * Q128 / liquidity`.
   - Kalau harga menyentuh tick initialized, `liquidity` ditambah atau dikurangi `liquidityNet` tick itu (positif saat melewati ke atas, negatif saat ke bawah), dan `feeGrowthOutside` tick tersebut di-flip.
5. **Setelah loop.** Update `slot0` (`sqrtPriceX96`, `tick`, `observationIndex`, `observationCardinality`), tulis observasi oracle baru kalau timestamp berubah, dan simpan `liquidity` aktif.
6. **Transfer token keluar** ke `recipient`.
7. **Callback.** Kalau `amountSpecified` negatif (exact output), pool butuh token masuk setelah menghitung output. Pool memanggil `uniswapV3SwapCallback(amount0Delta, amount1Delta, data)` ke `msg.sender`. Delta positif berarti pemanggil berutang token itu ke pool.
8. **Cek saldo akhir.** Pool memverifikasi saldo token0 dan token1 tidak turun dibanding sebelum swap. Ini jaring pengaman terakhir: berapa pun logika callback-nya, pool tidak bisa dirugikan.

Poin 2 dan 8 itu pasangan yang sering salah dipahami. Untuk exact input, pembayaran terjadi **di awal** dan callback hanya dipakai kalau ada sisa yang perlu dibayar. Untuk exact output, callback adalah satu-satunya jalan pembayaran.

## 8. `TickMath` dan `SqrtPriceMath`: apa yang sebenarnya dihitung

**`TickMath`**

- `getSqrtRatioAtTick(int24 tick)` menghitung `sqrt(1.0001^tick) * 2^96` tanpa floating point, pakai dekomposisi tick jadi bit dan konstanta yang sudah di-precompute. Fungsinya `pure`, hasilnya deterministik, dan itulah kenapa tick dipakai: konversi harga ke akar harga jadi operasi integer yang konsisten di semua client.
- `getTickAtSqrtRatio(uint160 sqrtPriceX96)` kebalikannya, dipakai saat pool perlu tahu tick dari harga.

**`SqrtPriceMath`**

- `getNextSqrtPriceFromAmount0RoundingUp` dan `getNextSqrtPriceFromAmount1RoundingUp`: harga setelah sejumlah token masuk atau keluar.
- `getAmount0Delta` dan `getAmount1Delta`: selisih token antara dua harga untuk likuiditas tertentu, dengan opsi `roundUp`.

**Kenapa arah pembulatan jadi penting.** Setiap pembulatan dibulatkan ke arah yang **menguntungkan pool**, bukan ke arah yang rapi. Kalau pool menghitung jumlah token yang harus dibayar user, hasilnya dibulatkan ke atas. Kalau menghitung jumlah token yang harus dikeluarkan pool, dibulatkan ke bawah. Tanpa disiplin ini, swap berulang dalam jumlah kecil bisa menguras pool sedikit demi sedikit, dan itu bug klasik di AMM mana pun. Ini alasan `SqrtPriceMath` punya parameter `roundUp` eksplisit di signature-nya, bukan default.

## 9. Data terukur dari mainnet

Dibaca pada block **26439489** lewat RPC publik `https://ethereum-rpc.publicnode.com`.

| Yang dibaca | Pool USDC/WETH 0,05% | Pool USDC/WETH 0,30% |
|---|---|---|
| address | `0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640` | `0x8ad599c3A0ff1De082011EFDDc58f1908eb6e6D8` |
| `token0` / `token1` | USDC / WETH | USDC / WETH |
| `fee()` | 500 | 3000 |
| `tickSpacing()` | 10 | 60 |
| `maxLiquidityPerTick()` | 1917569901783203986719870431555990 | 11505743598341114571880798222544994 |
| `liquidity()` | 4780285180534378708 | 968675917015947125 |
| `slot0().tick` | 201341 | 201346 |
| `slot0().sqrtPriceX96` | 1865230519492229637694575799910309 | 1865737612313341871458905190601551 |

Turunan dari angka itu:

- `sqrtPriceX96 / 2^96 = 23542,51897684`, jadi `price_raw = 554231685,4705` (token1 per token0 dalam satuan terkecil).
- Setelah koreksi desimal (USDC 6, WETH 18): **1 USDC = 0,00055425 WETH**, atau **1 WETH = 1.804,24 USDC**.
- Tick 201341 cocok dengan `1.0001^201341 = 554231685,47` untuk harga raw. Selisihnya di digit ke-9, dan itu memang batas presisi representasi `sqrtPriceX96`, bukan kesalahan hitung.
- `maxLiquidityPerTick` beda antara dua pool karena rumusnya bergantung `tickSpacing` dan `MIN_TICK`/`MAX_TICK`. Pool 0,05% dengan spacing 10 punya batas per tick lebih kecil daripada pool 0,3% dengan spacing 60, karena rentang per tick-nya lebih sempit.

Cara mereproduksi:

```bash
RPC=https://ethereum-rpc.publicnode.com
cast call 0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640 "slot0()(uint160,int24,uint16,uint16,uint16,uint8,bool)" --rpc-url $RPC
cast call 0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640 "liquidity()(uint128)" --rpc-url $RPC
cast call 0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640 "maxLiquidityPerTick()(uint128)" --rpc-url $RPC
```

Angka ini bergerak tiap blok. Kalau mau dipakai, baca ulang.

## 10. Fee accounting: kenapa butuh `feeGrowthX128`

v2 membagi fee lewat LP token: fee menambah `k`, dan nilai LP token naik. v3 tidak bisa begitu karena posisi punya rentang berbeda.

Solusinya akumulator global per token, yang **hanya bertambah**:

```
feeGrowthGlobal0X128 += feeAmount0 * 2^128 / liquidity
```

Setiap tick menyimpan `feeGrowthOutside0X128` dan `feeGrowthOutside1X128`. Fee yang berlaku untuk sebuah rentang dihitung dari kombinasi global dan outside tick bawah serta atas. Posisi menyimpan `feeGrowthInsideLastX128` saat terakhir kali fee di-collect, dan fee yang jadi haknya:

```
feeOwed = liquidity * (feeGrowthInside - feeGrowthInsideLast) / 2^128
```

Kenapa `2^128` dan bukan desimal? Karena `feeAmount / liquidity` hampir selalu nol kalau pakai integer. Dengan mengalikan `2^128` lebih dulu, presisinya cukup untuk akumulasi jutaan trade sebelum dibagi lagi. Ini pola fixed-point yang sama seperti di `L` dan `sqrtPriceX96`.

## 11. Oracle: TWAP bawaan pool

v3 memindahkan oracle ke dalam pool. Tiap pool punya array `observations`, awalnya satu slot, dan bisa diperbesar lewat `increaseObservationCardinalityNext`. Setiap observasi menyimpan:

- `blockTimestamp`
- `tickCumulative`: jumlah tick dikali waktu, akumulasi
- `secondsPerLiquidityCumulativeX128`

TWAP dihitung dengan `observe(uint32[] secondsAgos)`: selisih `tickCumulative` dibagi selisih waktu. Karena yang dirata-ratakan adalah **tick** (log harga), hasilnya adalah geometric mean price, bukan arithmetic mean. Ini detail yang sering salah kutip.

Batasnya: oracle hanya punya data selama `cardinality` slot terisi. Kalau tidak pernah dinaikkan, riwayat yang tersedia cuma beberapa menit, dan protokol yang bergantung TWAP panjang harus menaikkan cardinality sendiri.

## 12. v2 vs v3

| Aspek | v2 | v3 |
|---|---|---|
| Sebaran likuiditas | Merata 0 sampai tak hingga | Dipilih LP per rentang |
| Representasi posisi | LP token ERC-20 (fungible) | NFT ERC-721, satu tokenId per posisi |
| Fee | Tetap 0,30% | Pilih tier: 0,01% / 0,05% / 0,30% / 1,00% |
| Harga | `x * y = k` dengan reserve nyata | `L` dan `sqrtPriceX96`, reserve virtual per rentang |
| Akuntansi fee | Pertumbuhan `k` per LP token | `feeGrowthGlobal/Outside/Inside` per tick dan posisi |
| Oracle | Tidak ada, harus eksternal | TWAP bawaan di pool |
| Flash loan | Flash swap (pinjam output, bayar di callback) | `flash()` di pool, fee tier sebagai sumber fee |
| Rumus output | `dy = y*dx*997/(x*1000 + dx*997)` | Loop antar tick, tiap langkah pakai `SwapMath` |
| Batas harga | Tidak ada | `sqrtPriceLimitX96` per swap |
| Biaya kompleksitas | Rendah, aman dibaca dalam sehari | Tinggi: tick, bitmap, fee growth, oracle |

## 13. "Yang paling berbeda dari v2 adalah..."

Kalau harus satu paragraf, ini jawabannya:

> Di v2, harga adalah hasil samping dari saldo, dan satu rumus `x*y=k` menjelaskan seluruh pool. Di v3, harga adalah **state eksplisit** (`sqrtPriceX96` dan `tick`), likuiditas adalah fungsi dari posisi siapa yang aktif di rentang mana, dan satu swap adalah loop yang berpindah dari satu tick initialized ke tick berikutnya sambil menagih fee per langkah. Jadi perbedaan terbesarnya bukan "LP bisa pilih range", tapi bahwa v3 mengubah AMM dari satu kurva menjadi **banyak kurva yang disambung**, dan semua kompleksitas tick, bitmap, `feeGrowthX128`, serta oracle adalah harga yang harus dibayar untuk itu.

Turunan praktisnya untuk audit: bug di v2 biasanya soal aritmetika dan reentrancy. Bug di v3 biasanya soal **batas**: pembulatan di batas tick, `liquidityNet` yang salah tanda saat melewati tick, fee yang dihitung ganda di tick boundary, dan oracle yang cardinality-nya tidak cukup.

## 14. Yang belum dikerjakan

- Belum implementasi ulang v3 di Foundry. Materi ini masih level baca source dan verifikasi on-chain. Kalau mau praktik, langkah paling masuk akal: port `TickMath.getSqrtRatioAtTick` ke Solidity sendiri lalu bandingkan hasilnya dengan kontrak asli untuk 1000 tick acak.
- Belum baca `Position.sol`, `ProtocolFee` (bagian fee protokol yang sekarang tidak aktif), dan jalur `mint`/`burn` di `UniswapV3Pool`.
- Belum hitung ulang tabel efisiensi dengan `L` yang berbeda untuk melihat apakah rasionya bergeser (secara teori tidak, karena semua suku linear terhadap `L`).
