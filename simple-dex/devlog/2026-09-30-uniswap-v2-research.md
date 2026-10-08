# 30 Sep 2026 - AMM Research: Uniswap v2

> Task roadmap: "Baca Uniswap v2 whitepaper + core contracts. Pahami x*y=k formula secara mendalam. Simulasikan di spreadsheet: apa yang terjadi ke price dan liquidity saat ada swap besar? Pahami impermanent loss math."

## Apa yang dikerjakan

- Baca Uniswap v2 whitepaper + kontrak core yang relevan (`UniswapV2Pair.sol` untuk mint/burn/swap, `UniswapV2Library.sol` untuk getAmountOut/In). Fokus bukan di api surface, tapi di satu persamaan: `(x + dx) * (y - dy) = x * y`.
- Turunkan rumus amountOut dari konstanta produk, langkah per langkah, termasuk versi berfee 0.3%: `out = (in * 997 * rOut) / (rIn * 1000 + in * 997)`.
- Simulasi swap besar (pengganti spreadsheet, pakai python integer math yang identik dengan pembagian EVM): pool 100/100, swap 1%, 10%, 25%, 50% dari pool, lengkap dengan harga eksekusi, price impact, dan harga marginal setelah swap. Vektor 10% menghasilkan 9066108938801491315 wei, cocok persis dengan yang nanti dipakai sebagai vektor test.
- Turunkan impermanent loss `IL = 2*sqrt(r)/(1+r) - 1` dari definisi (bandingkan nilai posisi LP vs HODL) dan hitung tabel r = 1.25, 1.5, 2, 3, 4, 5.
- Pelajari kenapa MINIMUM_LIQUIDITY (1000 wei LP terkunci) dan kenapa first provision pakai `sqrt(a0*a1)`.
- Semua hasil dituang ke `docs/uniswap-v2-research.md`.

## Masalah & Solusi

### Fee dipotong di sisi mana: input atau output

- Masalah: pertama kali menurunkan rumus berfee, gw sempat bingung fee 0.3% harus masuk sebagai faktor di mana. Menaruhnya di output bikin rumus dua langkah dan pembulatannya rawan bocor ke trader.
- Kenapa: konstanta produk yang murni `(x + dx)*(y - dy) = x*y` gak punya tempat untuk fee; fee harus masuk sebagai penyesuaian salah satu sisi sebelum persamaan dipakai.
- Solusi: ikut konvensi v2, fee dipotong dari INPUT: yang ikut persamaan produk cuma `dx*997/1000`, tapi pool menerima `dx` penuh. Efek sampingnya menguntungkan: `k` tumbuh tiap swap dan itu persis pendapatan LP. Bukti aljabar + angka nyata (pool 100/100 swap 10, k naik dari 1e40 ke 1.0002728e40) ada di docs/uniswap-v2-research.md section 3.
- Pelajaran: fee-on-input bukan sekadar konvensi, ia yang bikin fee otomatis mengendap di pool tanpa transfer tambahan.

### Dua angka "price impact" untuk swap yang sama

- Masalah: simulasi swap 10% ke pool 100/100 menghasilkan dua angka dampak yang beda jauh: 9.34% dan 17.33%. Mana yang benar?
- Kenapa: dua definisi berbeda. Harga eksekusi = out/in = 0.906611, dibanding spot awal 1.0 memberi dampak 9.34%. Harga marginal SESUDAH swap = (y - out)/(x + in) = 0.826672, turun 17.33% dari spot awal. Marginal selalu lebih jelek dari eksekusi karena kurva makin curam sepanjang swap.
- Solusi: definisikan dua-duanya eksplisit di tabel (kolom terpisah) dan pilih harga eksekusi sebagai "price impact" yang ditampilkan ke user, karena itu harga rata-rata yang benar-benar dia bayar. Angka 9.34% jadi acuan konsisten dengan vektor test 10% pool.
- Pelajaran: angka dampak tanpa definisi itu setengah informasi; tulis rumusnya di sebelah angkanya.

### Tabel IL yang beredar dikutip tanpa rumus

- Masalah: angka IL yang beredar di artikel (1.25 -> 0.6%, 2 -> 5.7%, dst) dikutip bolak-balik tanpa derivasi, jadi gak bisa diverifikasi dan gak bisa dihitung untuk r lain.
- Kenapa: banyak sumber lompat langsung ke tabel final; derivasi `V_LP = 2*sqrt(r)`-nya di-skip.
- Solusi: turunkan sendiri dari definisi: pool rebalance ke `x = 1/sqrt(r)`, `y = sqrt(r)` (cek `x*y = k` dan `y/x = r`), nilai LP = `2*sqrt(r)`, nilai HODL = `1 + r`, jadi `IL = 2*sqrt(r)/(1+r) - 1`. Hitung tiap baris tabel di python, cocok dengan angka umum yang beredar.
- Pelajaran: tabel yang gak bisa diturunkan ulang pembacanya gak layak dikutip; rumus dulu, tabel kemudian.

### Kenapa first provision pakai sqrt, bukan rata-rata

- Masalah: mula-mula terlihat arbitrer kenapa LP pertama = `sqrt(a0*a1)`; rata-rata aritmetika `(a0+a1)/2` kelihatan lebih intuitif.
- Kenapa: geometric mean satu-satunya yang simetris terhadap urutan deposit DAN konsisten dengan formula share depositor berikutnya (`amount * totalSupply / reserve`).
- Solusi: catat dua properti itu di docs (section 7) plus contoh eksak dari pool (4e18, 9e18) yang memberi 6e18 LP; dua properti ini nanti dikunci test `test_FirstProvision_GeometricMeanIsDepositOrderIndependent`.
- Pelajaran: pilihan formula LP pertama menentukan fairness semua depositor setelahnya, bukan cuma kasus hari pertama.

## Status jujur

Done:
- Riset selesai: turunan rumus, simulasi swap, IL, MINIMUM_LIQUIDITY, geometric mean. Semua angka dihitung sendiri dengan rumus yang ditampilkan.
- `docs/uniswap-v2-research.md` berisi materi lengkap.

Catatan jujur:
- Dokumen final dirampungkan 6 Okt saat sesi dokumentasi (catch-up task 30 Sep). Materi inti sudah dipelajari dan divalidasi sejak 30 Sep, vektornya sudah dipakai test sejak 2 Okt.
- Hari ini belum ada kode; implementasi mulai Jum 2 Okt.
