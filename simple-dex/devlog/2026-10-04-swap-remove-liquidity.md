# 4 Okt 2026 - AMM: Swap + removeLiquidity

> Task roadmap: "Implement swap() dengan slippage protection (minimum output parameter). removeLiquidity(): burn LP tokens, kembalikan proportional token amounts." Test-nya: swap mengubah price sesuai formula.

## Apa yang dikerjakan

- Implement `swapExactTokensForTokens(amountIn, amountOutMin, deadline, zeroForOne)` di `src/DexPair.sol`: guard amount/deadline, `getAmountOut` dari AMMLibrary, guard slippage + output 0, update reserves (CEI, sebelum transfer), emit Swap + Sync, transfer in/out.
- Implement `removeLiquidity(lpAmount)`: payout `(lp * r / totalSupply)` dihitung terhadap supply SEBELUM burn, floor, guard payout 0 di salah satu sisi, burn, update reserves, transfer out.
- `test/DexPairSwap.t.sol` (11 test): vektor output eksak (10e18 ke pool 1000/1000 = 9871580343970612988), fuzz pair-vs-library, arah harga (jual token0 = harga token0 turun, beli = naik), k tumbuh oleh fee, slippage boundary, deadline boundary, dust input, pool kosong, events.
- Test remove di `test/DexPairLiquidity.t.sol` yang ditinggal kemarin dilengkapi dan hijau.

## Masalah & Solusi

### Dust input: library balikin 0 tanpa revert, pair hampir kirim 0 wei

- Masalah: `getAmountOut(1 wei, 1000e18, 1000e18)` floor ke 0 TANPA revert (fungsi pure, gak tahu konteks). Kalau pair percaya buta ke library, dia akan menyetujui swap dengan output 0, user bayar input penuh dan terima nol.
- Kenapa: pembagian integer floor tidak punya cara menandai "hasil ini debu, sebaiknya ditolak"; keputusan itu milik caller yang punya konteks state.
- Solusi: pair menambah guard sendiri: `amountOut == 0` revert `DexPair__InsufficientOutput` (src/DexPair.sol, swap). Dikunci `test_Swap_DustInputRevertsAsInsufficientOutput` dengan input 1 wei.
- Pelajaran: library pure dan kontrak stateful punya tanggung jawab beda; guard yang butuh konteks ekonomi (debu vs bukan) milik kontrak, bukan library.

### Semantik boundary slippage: satu wei bisa berarti kalah/menang

- Masalah: cek slippage `amountOut < amountOutMin` atau `<=`? Dan bagaimana membuktikan boundary-nya benar, bukan cuma "revert kalau beda jauh".
- Kenapa: `<=` akan menolak eksekusi yang persis sesuai toleransi user (false negative); `<` berarti output PERSIS sama dengan min lolos. Pilihan ini harus eksplisit dan teruji di boundary-nya, karena bug off-by-one di guard perlindungan dana itu klasik.
- Solusi: pakai `<` (src/DexPair.sol). `test_Swap_SlippageReverts` mengunci tiga titik: min = output eksak + 1 wei HARUS revert, min yang optimistis jauh HARUS revert, min = output eksak PERSIS harus LOLOS dengan output eksak yang sama.
- Pelajaran: guard boundary diuji di tepinya (+1, eksak), bukan di tengah; kasus tengah lolos bahkan dengan guard yang salah arah.

### Deadline: strictly after atau at

- Masalah: apakah swap dengan `block.timestamp == deadline` masih valid?
- Kenapa: deadline adalah janji "gak eksekusi SETELAH waktu ini"; pada timestamp yang sama, user masih dalam janjinya. Strict `>` juga cocok dengan konvensi v2.
- Solusi: `block.timestamp > deadline` revert `DexPair__Expired` (src/DexPair.sol). `test_Swap_DeadlineReverts` warp ke 1000: deadline 999 revert, deadline 1000 (persis) lolos.
- Pelajaran: inclusivity operator di parameter keamanan itu keputusan produk, tulis di natspec dan uji kedua sisinya.

### Payout remove dihitung terhadap supply sebelum atau sesudah burn

- Masalah: `removeLiquidity` membakar LP. Kalau payout dihitung SETELAH `_burn`, totalSupply sudah mengecil dan payout jadi terlalu besar (user membayar share yang seharusnya tetap di pool).
- Kenapa: urutan read/burn menentukan denominator; yang benar adalah share atas supply yang MASIH memuat LP yang mau dibakar.
- Solusi: hitung `amount0/amount1 = lp * r / totalSupply` SEBELUM `_burn` (src/DexPair.sol), floor, guard payout 0 di salah satu sisi (`DexPair__InsufficientLiquidityBurned`) supaya debu gak nyangkut diam-diam. Dikunci `test_RemoveLiquidity_ProportionalExact` (vektor eksak 1999999999999999666 / 4499999999999999250 untuk setengah LP di pool 4/9) dan `test_RemoveLiquidity_DustReverts` (burn 1000 LP di pool (1e6, 1e18) di-reject karena sisi token0 floor ke 0).
- Pelajaran: di operasi burn/mint, "snapshot state sebelum mutasi" adalah aturan pembacaan, bukan detail gaya.

### CEI vs pola optimistic transfer v2

- Masalah: v2 asli update reserves SETELAH transfer (optimistic, mengandalkan saldo aktual). Apakah disalin mentah?
- Kenapa: dengan API explicit-amount, jumlah in/out sudah diketahui SEBELUM transfer; menunda update state hanya memperpanjang jendela reentrancy tanpa manfaat.
- Solusi: CEI di swap dan remove (reserves final sebelum external call), `lock` modifier tetap ada sebagai defense in depth dengan paritas pola v2. Deviasi ini sudah dijanjikan SPEC (poin 2) dan diimplementasi konsisten.
- Pelajaran: pola keamanan ikut API: API berubah, urutan state/interaction yang optimal ikut berubah, tapi lapisan kedua (lock) jangan dibuang.

## Status jujur

Done:
- `swapExactTokensForTokens` + `removeLiquidity` selesai; suite swap 11 test hijau; vektor eksak dihitung manual (9871580343970612988 untuk 10e18 ke pool 1000/1000).
- Semua edge case E8-E12 dari SPEC punya test eksplisit.

Belum:
- Security review formal + invariant suite (5 Okt); fuzz lintas fungsi menyusul di suite invariant.
- Reentrancy belum diuji dengan mock token jahat end-to-end (dicatat jujur di docs/security-review.md section 9 sebagai gap).
