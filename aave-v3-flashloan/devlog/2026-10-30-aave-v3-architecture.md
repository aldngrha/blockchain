# 30 Okt 2026: Aave v3 Architecture dan Simulasi Likuidasi

> Task roadmap: "Baca Aave v3 documentation dan whitepaper. Pahami lending pool, interest rate model, health factor, liquidation. Simulasikan skenario liquidation di spreadsheet: kapan posisi jadi tidak aman?"

## Apa yang dikerjakan

- Baca ulang dokumentasi Aave v3 dengan fokus ke empat hal: alur supply/borrow, interest rate model dua lereng, health factor, dan aturan likuidasi.
- Ganti "spreadsheet" dengan dokumen hitung yang bisa diulang: [`docs/aave-v3-liquidation-sim.md`](../../docs/aave-v3-liquidation-sim.md). Isinya rumus, tabel penurunan harga pemicu likuidasi, tabel HF per skenario, matematika bonus likuidator, dan cara reproduksi di spreadsheet kalau memang mau format itu.
- Semua angka dihitung sendiri dengan Python (`Decimal`, supaya tidak ada galat pembulatan floating point), lalu dicocokkan ulang manual di beberapa baris.

## Temuan yang paling berguna

### 1. Bantalan LTV ke liquidation threshold cuma 2,5 poin

Dengan data WETH yang sudah dibaca on-chain sebelumnya (LTV 80,50%, LT 83,00%), posisi yang dipinjam sampai LTV maksimum cuma butuh penurunan harga **3,01%** untuk masuk zona likuidasi. Ini bukan teori: `f = 8050 / (10000 * 0,83) = 0,9699`.

Yang bikin angka itu makin penting: bunga berjalan menaikkan utang tanpa transaksi apa pun. Jadi HF 1,03 bisa jadi 0,99 dalam beberapa hari walaupun harga diam.

### 2. Semua suku linear, jadi simulasi tidak butuh loop

Karena `HF` linear terhadap nilai jaminan dan terhadap utang, simulasi bisa ditutup dengan satu rumus: `f = utang / (nilai_jaminan * LT)`. Tidak perlu iterasi harga per dolar. Ini juga alasan tabel di dokumen itu bisa dibuat 6 baris tanpa mengambil risiko salah model.

### 3. Aturan likuidasi punya dua ambang, bukan satu

Batas 50% versus 100% ditentukan oleh `HF <= 0,95` **atau** nilai jaminan/utang di bawah $2.000. Ditambah aturan debu minimal $1.000. Efeknya, likuidator yang mau membersihkan posisi kecil harus membersihkannya penuh, dan itu disengaja supaya tidak ada sisa posisi yang tidak bisa dilikuidasi lagi.

## Status jujur

- Dokumen selesai dan angkanya konsisten antar tabel. Baris "utang $6.000 turun 27,8% menghasilkan HF 0,9988" cocok dengan rumus `f = 6000/8300`.
- Parameter interest rate (`baseRate`, `slope1`, `slope2`, `Uoptimal`) masih **ilustratif**. Angka aslinya ada di kontrak interest rate strategy per reserve, dan alamatnya diambil dari `getReserveData`. Belum dibaca karena layout struct `getReserveData` berubah antar versi Aave v3, dan salah decode lebih buruk daripada tidak decode.
- Belum baca `LiquidationLogic.sol` sampai level eksekusi. Itu bahan lanjutan, bukan target hari ini.
- Spreadsheet asli tidak dibuat. Isinya sudah ada sebagai rumus dan tabel di dokumen, plus panduan kolom kalau mau dipindah ke Numbers atau Excel.
