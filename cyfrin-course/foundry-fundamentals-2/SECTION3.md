# Documentation: Cyfrin Solidity Section 3 - FundMe

Dokumentasi ini merangkum semua materi dan implementasi teknis yang telah dipelajari dalam Section 3 kursus Cyfrin (Patrick Collins).

## 1. Ringkasan Proyek
Proyek **FundMe** adalah smart contract crowdfunding yang memungkinkan pengguna mengirimkan ETH dengan batasan nilai minimal dalam USD. Kontrak ini menggunakan Oracle untuk mendapatkan data harga dunia nyata.

## 2. Fitur Utama
- **Funding**: Pengguna dapat mengirim ETH melalui fungsi `fund()`.
- **Minimal Donasi**: Batas minimal adalah $5 USD (dihitung secara real-time).
- **Withdrawal**: Hanya pemilik kontrak (Owner) yang bisa menarik dana.
- **Gas Optimized**: Menggunakan teknik terbaru untuk menekan biaya transaksi.

## 3. Implementasi Teknis & Materi Pelajari

### A. Chainlink Price Feeds (Oracle)
- **Problem**: Blockchain bersifat deterministik dan tidak bisa memanggil API luar.
- **Solusi**: Menggunakan interface `AggregatorV3Interface` dari Chainlink.
- **Library**: Logika konversi dipisahkan ke `PriceConverter.sol` agar kode utama tetap bersih.

### B. Optimasi Gas (Efficiency)
Beberapa teknik yang diterapkan:
1. **Constant & Immutable**: Variabel yang tidak berubah disimpan langsung dalam bytecode kontrak (`MINIMUM_USD`, `i_owner`).
2. **Custom Errors**: Mengganti `require(..., "pesan")` dengan `error FundMe__NotOwner()` untuk menghemat gas saat revert.
3. **Naming Convention**: Menggunakan awalan `s_` untuk variabel Storage (mahal) dan `i_` untuk Immutable (murah).
4. **Cheaper Withdraw**: Memindahkan array dari Storage ke **Memory** sebelum melakukan looping untuk mengurangi operasi `SLOAD`.

### C. Modular Deployment (HelperConfig)
Satu script deploy (`DeployFundMe.s.sol`) dapat digunakan untuk berbagai jaringan tanpa mengubah kode:
- **Sepolia**: Menggunakan alamat Price Feed asli.
- **Anvil (Lokal)**: Secara otomatis men-deploy **MockV3Aggregator** jika tidak ada jaringan yang terdeteksi.

### D. Advanced Testing (Foundry)
Menggunakan cheatcodes sakti dari Forge:
- `vm.prank(address)`: Simulasi pengirim transaksi.
- `vm.deal(address, amount)`: Memberikan saldo ETH ke alamat tertentu.
- `hoax(address, amount)`: Gabungan prank dan deal.
- `vm.expectRevert()`: Memastikan fungsi gagal saat kondisi tertentu terpenuhi.
- `gas-report`: Menganalisis konsumsi gas setiap fungsi.

## 4. Cara Menjalankan Proyek

### Kompilasi
```bash
forge build
```

### Menjalankan Test
```bash
forge test
```

### Melihat Laporan Gas
```bash
forge test --gas-report
```

## 5. Kesimpulan
Section 3 telah diselesaikan 100%. Fokus utama adalah pada keamanan, efisiensi gas, dan interaksi dengan data luar (Oracle). Proyek sekarang siap untuk dilanjutkan ke **Section 4: Smart Contract Lottery (VRF & Automation)**.
