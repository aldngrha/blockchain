# 3 Okt 2026 - AMM: addLiquidity + LP Tokens

> Task roadmap: "Implement addLiquidity(): calculate LP tokens to mint, handle first liquidity provision. LP token adalah ERC-20 yang represent share of pool. Test: add liquidity, cek LP balance, verifikasi ratio."

## Apa yang dikerjakan

- Implement `addLiquidity` di `src/DexPair.sol` dengan dua cabang: first provision (totalSupply == 0: `liquidity = sqrt(a0*a1)`, mint 1000 MINIMUM_LIQUIDITY ke pair + sisanya ke caller) dan provision berikutnya (snap ke rasio pool via `quote`, `liquidity = min(a0*ts/r0, a1*ts/r1)`, kelebihan gak ditarik).
- Urutan CEI: reserves di-update dan LP di-mint SEBELUM `transferFrom` input.
- `test/DexPairLiquidity.t.sol`: first provision sqrt eksak (4/9 -> 6e18 LP), MINIMUM_LIQUIDITY terkunci selamanya, provision terlalu kecil revert, proportional + unbalanced + refund, min-formula fuzz, constructor sorting + guards, fee-on-transfer di-reject, events. Suite liquidity hijau (17 test).

## Masalah & Solusi

### Nilai return first provision: apakah 1000 wei terkunci ikut dihitung

- Masalah: first provision mint `liquidity = sqrt(a0*a1)` total, tapi 1000 di antaranya masuk ke pair, bukan ke caller. Pertanyaan desain: fungsi return berapa, `liquidity` penuh atau `liquidity - 1000` yang benar-benar diterima caller?
- Kenapa: kalau return dipotong 1000, formula share (`amount * totalSupply / reserve`) untuk kasus SELANJUTnya jadi gak konsisten dengan apa yang di-return, dan caller yang memakai return value untuk akuntansi bisa salah hitung share-nya sendiri. v2 meng-emit/menghitung liquidity penuh dan mem-bagi mint-nya.
- Solusi: ikut v2, return value adalah LP PENUH termasuk porsi terkunci; caller menerima `liquidity - MINIMUM_LIQUIDITY` di balance-nya (src/DexPair.sol, cabang first provision). Dokumentasi eksplisit malah muncul di handler invariant (test/invariant/DexPairHandler.t.sol): "on the first provision the RETURNED liquidity is the FULL mint (locked 1000 included); the caller receives liquidity - 1000", dan ghost_lpMinted di-seed dengan nilai penuh itu.
- Pelajaran: satu konvensi (full mint vs net payout) harus dipilih sekali dan diulang konsisten di return value, balance, dan ghost accounting, kalau tidak, setiap pemakai return value salah satu sisi.

### Deposit tidak seimbang: tarik semua lalu refund, atau tidak ditarik sama sekali

- Masalah: user menawarkan (10e18, 5e18) ke pool 1:1. Pool hanya butuh (5e18, 5e18). Dua opsi: tarik `desired` lalu transfer balik kelebihannya, atau hitung dulu dan cukup tidak menarik kelebihannya.
- Kenapa: opsi tarik-refund menambah dua transfer ekstra dan satu kondisi failure baru (refund bisa gagal kalau token jahat), padahal informasi kebutuhan pool sudah ada SEBELUM transfer pertama.
- Solusi: refund by not pulling (src/DexPair.sol): hitung `amount1Optimal = quote(...)`, bandingkan dengan budget caller, tarik CUMA sisi optimal, kelebihan tidak pernah meninggalkan dompet caller. Klaim `amount0Optimal <= amount0Desired` pada cabang kedua dijaga `assert(...)` karena terjamin secara math (budget token1 yang menjadi sisi pengikat). Dikunci test `test_AddLiquidity_Unbalanced_Token0ExcessNotPulled` dan `test_AddLiquidity_Unbalanced_Token1BindingSide` dengan saldo eksak sebelum/sesudah, plus fuzz min-formula.
- Pelajaran: transfer yang tidak perlu bukan cuma boros gas, ia permukaan error tambahan; efektivitas terbaik adalah tidak melakukan transfernya.

### LP pertama terlalu kecil: di mana garis revert

- Masalah: first provision dengan deposit winy (mis. 1000+1000) menghasilkan `sqrt(a0*a1) = 1000 == MINIMUM_LIQUIDITY`, caller dapat 0 LP. Revert di mana dan dengan error apa?
- Kenapa: kalau dibiarkan, caller menerima 0 LP sementara 1000 LP terkunci dibayar penuh oleh depositnya; itu pemborosan senyap.
- Solusi: guard eksplisit `liquidity <= MINIMUM_LIQUIDITY` revert `DexPair__InsufficientLiquidityMinted` SEBELUM transfer apapun (src/DexPair.sol). Dikunci `test_FirstProvision_TooSmallReverts` (dua config: 1000+1000 dan 1+1) plus assert tambahan bahwa totalSupply dan reserves tetap 0 setelah revert.
- Pelajaran: revert lebih awal yang bisa dijelaskan (custom error) lebih baik daripada sukses yang membingungkan.

### Mirror deposit harus memberi LP yang sama persis

- Masalah: cara membuktikan geometric mean benar-benar simetris, bukan hanya "kelihatannya simetris".
- Kenapa: kalau LP minted bergantung urutan parameter, depositor bisa diuntungkan/dirugikan cuma dengan urutan argumen, dan formula share selanjutnya jadi bias.
- Solusi: `test_FirstProvision_GeometricMeanIsDepositOrderIndependent`: pool yang sama di-seed dua kali, (4, 9) dan (9, 4), LP minted harus identik (6e18). Simetri `sqrt(a*b)` jadi properti yang dijaga test, bukan asumsi.
- Pelajaran: properti matematis yang jadi dasar fairness sebaiknya dikunci sebagai test terpisah, sekecil apapun ketergantungannya pada implementasi.

## Status jujur

Done:
- `addLiquidity` dua cabang selesai dengan CEI; suite liquidity 17 test hijau; MINIMUM_LIQUIDITY terkunci terverifikasi test (sisa reserves 667/1500 wei setelah alice burn semua LP-nya di pool 4/9).
- Semua angka vektor (6e18, 4444444444444444444, 6666666666666666666, dst) dihitung manual, bukan dikutip dari run kontrak.

Belum:
- `removeLiquidity` penuh dan `swap` menyusul besok (4 Okt); test liquidity yang menyentuh remove (proportional, dust revert) sudah ditulis hari ini sebagai kontrak dengan implementasi besok.
- Invariant suite belum jalan (5 Okt).
