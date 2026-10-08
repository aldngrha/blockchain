# Cara Implement AMM dari Scratch: Pelajaran dari Build SimpleDex

*Bahasa: Indonesia. Ini draft artikel Mirror.xyz, target publish setelah review manual. Semua angka di sini bisa direproduksi: vektor dari test suite di repo simple-dex, counterexample dari devlog, dan jumlah test yang bisa dijalankan ulang.*

## Mulai dari satu persamaan

Bulan lalu gw memutuskan berhenti membaca teori AMM dan menulis sendiri: satu kontrak `DexPair`, dua token, tanpa factory, tanpa oracle, tanpa audit. Nama proyeknya SimpleDex, dan kesederhanaannya memang disengaja: tujuannya memahami setiap baris dari Uniswap v2 yang selama ini gw pakai sebagai black box.

Inti AMM-nya ternyata cuma satu persamaan:

```
(x + dx) * (y - dy) = x * y
```

Pool menyimpan dua token, dan satu-satunya aturan yang dipaksa kontrak adalah produk keduanya tetap konstan. Dari persamaan itu, output swap diturunkan tiga baris aljabar: `dy = y * dx / (x + dx)`. Tidak ada order book, tidak ada matching engine. Harga bergerak karena pool-nya sendiri bergerak di sepanjang kurva.

Fee 0.3% masuk di sisi input, dikodekan 997/1000. Ini keputusan desain yang awalnya gw anggap detail, lalu menyadari konsekuensinya elegan: karena fee dipotong dari input sebelum masuk persamaan, fee otomatis mengendap di pool dalam bentuk token input. `k` tumbuh sedikit setiap swap, dan pertumbuhan itulah pendapatan LP. Tidak perlu akumulasi fee terpisah, tidak perlu klaim. Rumusnya menjadi:

```
amountOut = (amountIn * 997 * reserveOut) / (reserveIn * 1000 + amountIn * 997)
```

Pembagian di atas adalah pembagian integer, dan di situlah pelajaran-pelajaran menarik mulai muncul.

## Fuzz test pertama yang merah: overflow di luar domain

Hari kedua implementasi, gw menulis fuzz test round-trip: `getAmountOut(getAmountIn(x, ...))` harus mengembalikan `x` (dengan toleransi satu wei karena pembulatan). Test-nya gagal dengan panic 0x11, arithmetic overflow. Fuzzer Foundry memberi counterexample yang gw tidak akan temukan manual: `amountOut` sekitar 2^120, `reserveIn` cuma 10756, dan `getAmountIn` menghasilkan input yang diminta sekitar 7.17e39. Round-trip ke `getAmountOut` meledak di perkalian internal, sekitar 9.5e78, melewati batas 2^256.

Reaksi pertama gw adalah mencari cara mem-patch math-nya. Setelah menelusuri kenapa Uniswap v2 memakai `uint112` untuk reserves, gw sadar patch itu tidak perlu: dengan reserves dan input dibatasi 2^112, produk internal paling besar sekitar 2^112 * 2^10 * 2^120, masih di bawah 2^256. Rumusnya benar dalam domainnya; yang hilang adalah kontrak dokumentasi tentang domain itu sendiri.

Solusinya tiga lapis: batasi fuzz test dengan `vm.assume` di dalam domain, tulis dua test eksplisit yang mengunci perilaku di luar domain (panic, failure-safe: revert tanpa perubahan state), dan tulis catatan domain di natspec. Tidak ada satu baris math pun diubah. Pelajaran yang gw bawa: fuzz failure tidak selalu berarti bug yang harus di-patch; kadang ia adalah asumsi yang belum tertulis, dan tugasnya adalah menuliskan asumsi itu, bukan menambal rumus.

## Pembulatan selalu berpihak ke pool

AMM hidup dari pembulatan. Di setiap pembagian integer ada debu, dan keputusan ke mana debu itu jatuh menentukan siapa yang mensubsidi siapa. Konvensi yang gw salin dari v2: output di-floor, input yang dibutuhkan di-ceil dengan +1 wei. Jadi pembulatan selalu menguntungkan pool, tidak pernah trader.

Dua keputusan kecil lain yang terasa remeh sampai gw harus mengujinya di boundary:

- Dust input. `getAmountOut` adalah fungsi pure: swap 1 wei ke pool 1000/1000 menghasilkan 0 tanpa revert, karena ia tidak tahu konteks. Kalau pair percaya buta, user membayar 1 wei dan menerima nol. Solusinya guard di pair, bukan di library: `amountOut == 0` di-revert. Pemisahan tanggung jawabnya jelas: library menghitung, kontrak memutuskan.
- Semantik boundary slippage. `amountOut < amountOutMin` atau `<=`? Salah satu operator menolak eksekusi yang persis sesuai toleransi user; yang lain menerimanya. Gw memilih `<` dan mengunci ketiga titiknya di test: min = output + 1 wei harus revert, min jauh lebih tinggi harus revert, min persis sama harus lolos. Bug off-by-one di guard perlindungan dana itu klasik, dan kasus tengah lolos bahkan dengan guard yang salah arah, jadi boundary-nya harus diuji di tepinya.

## Frontend: mirror math, bukan kepercayaan buta

Minggu ini giliran frontend-nya (React + wagmi + viem). Kebutuhannya klasik: user harus melihat estimasi output dan price impact sebelum menandatangani. Cara yang gak bisa dipertanggungjawabkan adalah menampilkan angka dari endpoint eksternal. Cara yang gw pilih: mirror JavaScript dari rumus kontrak, pakai BigInt.

Keputusan ini justru sederhana karena pembagian BigInt di JavaScript truncating, sama seperti EVM. Tidak ada floating point, tidak ada selisih desimal. Gw menguji mirror-nya terhadap 26 vektor eksak dari test suite Solidity, termasuk `getAmountOut(10e18, 100e18, 100e18) = 9066108938801491315` dan swap 10e18 ke pool 1000/1000 yang menghasilkan 9871580343970612988. Semua cocok persis, bit demi bit, lalu satu smoke test on-chain mengonfirmasi reserves pasca-swap sama dengan prediksi mirror. Angka yang ditampilkan ke user sebelum tanda tangan sekarang berasal dari rumus yang sama dengan yang akan dieksekusi kontrak.

Price impact punya jebakan definisi yang gw alami sendiri waktu riset: ada dua angka yang berbeda dan sama-sama benar. Impact eksekusi membandingkan harga rata-rata trade dengan pool price sebelum swap. Impact marginal membandingkan pool price setelah swap dengan sebelum swap, yaitu harga untuk wei berikutnya. Untuk swap 10% pool, eksekusinya sekitar 9.3%, marginalnya sekitar 17.3%. UI yang hanya menampilkan satu angka tanpa definisi diam-diam memilih interpretasi untuk usernya; sekarang keduanya tampil berdampingan dengan penjelasan singkat.

## Yang belum, dan kenapa itu penting ditulis

SimpleDex belum punya: factory, TWAP oracle, dukungan fee-on-transfer, protocol fee switch, dan audit. Test reentrancy end-to-end dengan mock token jahat juga belum ada; mitigasinya (CEI ordering plus lock modifier) baru dinilai dari inspeksi. Gw menuliskan daftar ini di README dan security review, bukan karena jujur itu konten menarik semata, tapi karena siapa pun yang membaca kode ini perlu tahu batas klaimnya.

Yang gw dapat dari seminggu ini bukan cuma AMM yang jalan dengan 53 test hijau (unit, fuzz, dan invariant: k tidak pernah turun, solvency terjaga, LP terbakar proporsional). Yang lebih berharga adalah kebiasaan baru: setiap angka yang muncul di UI bisa dilacak ke rumus kontrak, setiap rumus bisa dilacak ke persamaan satu baris, dan setiap asumsi yang belum tertulis akhirnya tertulis, biasanya karena fuzz test yang merah duluan.

Repo dan devlog per hari ada di GitHub. Kalau lo sedang mengimplement AMM pertama lo, satu saran dari counterexample 7.17e39 itu: jangan percaya rumus lo di luar domainnya, dan biarkan fuzzer yang menemukan domainnya untuk lo.
