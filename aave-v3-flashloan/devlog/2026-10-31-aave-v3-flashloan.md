# 31 Okt 2026: Flash Loan Receiver dan Test di Fork Mainnet

> Task roadmap: "Flash loan di Aave v3: cara kerja, fee structure, use cases legitimate (arbitrage, collateral swap). Implement flash loan receiver contract sederhana di Foundry. Test di fork mainnet dengan anvil --fork-url."

## Apa yang dikerjakan

- Tulis `SPEC.md` dulu: invariants I-1..I-6 dan edge cases E1..E9, sebelum satu baris Solidity.
- Implementasi `FlashLoanReceiver` dengan desain plugin: `params` membawa `(action, actionParams)`, action harus ada di allowlist dan dicek dua kali.
- `RecordAction` untuk membuktikan dana benar-benar ada di callback, `MintProfitAction` untuk menguji premium yang dibayar dari profit.
- `MockPool` yang meniru urutan Aave: transfer, callback, `transferFrom` sebesar `amount + premium`, cek saldo.
- 10 test lokal (termasuk 1 fuzz test) dan 2 test fork mainnet lawan Pool Aave v3 asli.
- `script/DeployFlashLoan.s.sol` plus verifikasi deploy di anvil fork port 8550.

## Masalah & Solusi

### 1. Mock pool tidak menarik pembayaran, jadi test hijau tanpa menguji apa pun

- Masalah: `test_FlashLoan_HappyPath` gagal dengan `NotEnoughRepaid(10000000500000, 9999000000000)`. Selisihnya tepat sebesar `amount`.
- Kenapa: `MockPool` mengirim dana dan memanggil callback, lalu hanya **membaca** saldo untuk dicek. `transferFrom` untuk menarik `amount + premium` belum ditulis. Jadi saldo pool turun sebesar `amount` dan tidak pernah kembali.
- Solusi: tambahkan `token.safeTransferFrom(receiver, address(this), amount + premium)` sebelum pengecekan saldo.
- Pelajaran: mock yang tidak meniru langkah paling penting (penarikan dana) akan membuat test lulus atau gagal karena alasan yang salah. Di sini justru gagal, dan itu bagus, tapi kalau pengecekan saldonya juga tidak ada, test-nya akan hijau padahal mekanismenya bohong.

### 2. MockPool tidak punya `ADDRESSES_PROVIDER()`, constructor receiver revert

- Masalah: seluruh suite gagal di `setUp` dengan `EvmError: Revert`, tanpa petunjuk fungsi mana.
- Kenapa: constructor `FlashLoanReceiver` membaca `IPool(pool_).ADDRESSES_PROVIDER()` untuk menyimpan provider. `MockPool` belum punya fungsi itu, jadi panggilan ke alamat kontrak tanpa fungsi tersebut revert.
- Solusi: tambahkan `ADDRESSES_PROVIDER()` dan `FLASHLOAN_PREMIUM_TOTAL()` di `MockPool`.
- Pelajaran: begitu kontrak asli membaca state dari kontrak lain di constructor, mock-nya harus menyediakan state itu juga. Kalau tidak, kegagalannya muncul sebagai revert tanpa nama fungsi, karena panggilan ke selector yang tidak ada.

### 3. Ekspektasi aritmetika di test yang salah, bukan kontraknya

- Masalah: setelah mock diperbaiki, `test_FlashLoan_HappyPath` gagal di `premium dibayar dari saldo sendiri: 4500000 != 5000000`.
- Kenapa: receiver diberi saldo awal 5 USDC, menerima 1.000 USDC, lalu Pool menarik 1.000,5 USDC. Sisanya 4,5 USDC, bukan 5 USDC. Premium 0,5 USDC memang dipotong dari saldo awal.
- Solusi: ubah ekspektasi jadi `5e6 - premium`, dan untuk pinjaman kedua `5e6 - 2 * premium`.
- Pelajaran: angka "sisa" di test harus diturunkan dari alur, bukan dari tebakan. Selisih 0,5 USDC itu justru bukti bahwa premiurnya benar-benar dibayar.

### 4. Saldo Pool tidak bertambah, karena underlying dipegang aToken

- Masalah: test fork lulus semua assert receiver, lalu gagal di `pool hanya untung premium: 0 != 500000`.
- Kenapa: di Aave v3, kontrak `Pool` tidak menyimpan underlying. Aset ada di aToken, dan `FlashLoanLogic` memakai `transferUnderlyingTo` dari aToken saat mengirim dana, lalu mengembalikan `amount + premium` ke aToken. Jadi saldo USDC Pool memang tidak bergerak.
- Solusi: assert dipindah ke `aEthUSDC` (`0x98C23E9d8f34FEFb1B7BD6a91B7FF122F4e16F5c`), dengan verifikasi dulu bahwa `UNDERLYING_ASSET_ADDRESS()`-nya USDC dan `POOL()`-nya Pool yang dipakai. Setelah itu delta = premium tepat.
- Pelajaran: mengukur fee protokol lewat saldo kontrak logika adalah kesalahan model, bukan kesalahan angka. Ini juga menjelaskan kenapa premium masuk ke supplier: yang bertambah adalah klaim mereka.

### 5. `getTreasury()` revert di PoolAddressesProvider mainnet

- Masalah: `IPoolAddressesProvider(provider).getTreasury()` revert dengan data kosong, padahal fungsi itu ada di dokumentasi Aave v3.
- Kenapa: kontrak yang ter-deploy di mainnet menjalankan versi Aave v3 yang lebih baru, dan pengelolaan treasury dipindah. `getCollector()` juga revert di provider ini. Artinya asumsi "v3 = satu versi interface" salah.
- Solusi: jangan bergantung pada `getTreasury()`. Assert dipindah ke aToken, yang tetap stabil antar versi karena itu tempat aset benar-benar berada.
- Pelajaran: alamat kontrak mainnet hidup, interface-nya tidak beku. Kalau test bergantung pada satu fungsi governance, test itu bisa mati bukan karena kode kita rusak.

### 6. Premium harus disiapkan sebelum transaksi

- Masalah: `test_Fork_RevertsWhenPremiumCannotBePaid` awalnya terasa seperti test yang aneh, karena memang mengharapkan revert.
- Kenapa: flash loan bukan pinjaman gratis. Pool menarik `amount + premium`, dan kalau action tidak menghasilkan profit, dana premium harus sudah ada.
- Solusi: di fork test, premium disiapkan dengan `deal(USDC, receiver, premium + 1)`, dan test kedua sengaja tidak menyiapkannya untuk membuktikan seluruh transaksi batal tanpa dana hilang.
- Pelajaran: ini bagian yang paling sering dilewatkan orang saat membaca "flash loan". Yang dipinjam bukan modal untuk profit, tapi modal untuk **satu transaksi**, dan biayanya tetap harus dibayar.

## Status jujur

Done dan terverifikasi sendiri:

- `forge build` hijau.
- `forge test` lokal: **10/10 hijau**, termasuk `testFuzz_PremiumIsPriceOfLoan` (257 run).
- Fork mainnet: **2/2 hijau** dengan `FORK_RPC_URL=https://ethereum-rpc.publicnode.com`, flash loan 1.000 USDC dari Pool Aave v3 asli, premium 500.000 unit (0,5 USDC) terverifikasi pindah ke aToken.
- Deploy lokal di anvil fork port 8550: script jalan, `deployments/31337.json` tertulis, receiver meng-allowlist `RecordAction`.

Belum / butuh aksi manual:

- Deploy testnet (Sepolia) belum. Butuh RPC, gas, private key, dan address Pool Aave v3 di chain itu. Tidak ada address testnet yang dikarang di dokumen ini.
- Verifikasi di explorer belum.
- Strategi profit nyata belum ada. `MintProfitAction` mencetak token, jadi hanya valid untuk test lokal.
