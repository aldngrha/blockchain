# Cara Kerja Aave v3 dalam Satu Halaman

> Task roadmap: 26 Okt 2026. "Deep dive 1 DeFi protocol: Aave, Compound, atau Uniswap v3. Baca dokumentasi, baca source code, pahami cara kerjanya. Buat summary: 'Cara kerja [protocol] dalam 1 halaman'."
>
> Sumber: dokumentasi resmi Aave (aave.com/docs, aave.dev/help), source code `aave/aave-v3-core` di GitHub, dan **pembacaan langsung kontrak Aave V3 Pool di Ethereum mainnet** pada block 26175066. Angka di section "Data terukur" diambil dari pembacaan itu, bukan dari hafalan atau artikel.

## Intinya

Aave v3 itu protokol likuiditas non-custodial: orang menaruh aset untuk dapat bunga, dan orang lain meminjam aset itu dengan jaminan. Tidak ada pihak yang memegang dana pengguna, semuanya di kontrak. Pinjaman **selalu over-collateralized**, artinya nilai jaminan harus lebih besar dari nilai pinjaman. Karena harga bergerak, posisi dipantau terus lewat satu angka bernama health factor.

## Peran tiap kontrak

| Kontrak | Perannya |
|---|---|
| `Pool` | Pintu utama. `supply`, `borrow`, `repay`, `withdraw`, `liquidationCall`, `flashLoan` |
| `PoolConfigurator` | Ubah parameter risiko per reserve (LTV, liquidation threshold, bonus) |
| `aToken` (mis. aWETH) | Bukti setoran, ERC-20 berbunga. Saldo naik terus seiring waktu |
| `variableDebtToken` | Bukti utang. Saldo naik seiring bunga berjalan |
| `AaveOracle` | Sumber harga. Ini titik terlemah secara desain, karena semua perhitungan risiko bergantung padanya |
| `PoolAddressesProvider` | Registry alamat. Kontrak lain menanyakan alamat Pool lewat sini |

## Alur supply

Setor aset, dapat aToken dengan jumlah 1:1. Bedanya dengan kuitansi biasa: **saldo aToken naik terus** tanpa transaksi apa pun, karena nilainya bertambah dari bunga yang dibayar peminjam. Tarik dana berarti menukar aToken kembali jadi aset asli, plus bunga yang sudah terkumpul. Kalau aset itu dipakai sebagai jaminan, penarikan dibatasi supaya posisi pinjaman tetap aman.

## Alur borrow

Setor jaminan, lalu pinjam aset lain sampai batas LTV. Utang dicatat sebagai variableDebtToken. Bunga berjalan terus, dan saldo utang naik sendiri. Bisa dibayar kapan saja, dan posisi tetap terbuka selama masih over-collateralized.

## Model suku bunga: dua lereng

Suku bunga mengikuti tingkat pemanfaatan (utilization) sebuah reserve, dengan satu titik optimal:

- **Di bawah optimal:** bunga naik pelan mengikuti lereng pertama. Ini fase normal.
- **Di atas optimal:** bunga naik tajam mengikuti lereng kedua. Ini disengaja: kalau hampir semua aset sudah dipinjam, suku bunga melonjak supaya orang terdorong mengembalikan utang atau menambah setoran.

Hasil untuk pemberi pinjaman = bunga dari peminjam dikurangi reserve factor (potongan protokol).

## Health factor: satu angka yang menentukan semuanya

```
Health Factor = (Total Nilai Jaminan x Rata-rata Tertimbang Liquidation Threshold)
                -------------------------------------------------------------------
                                  Total Nilai Utang
```

Semua nilai dinormalkan ke satu mata uang dasar lewat oracle.

Contoh: setor $10.000 ETH dengan liquidation threshold 80%, pinjam $6.000 stablecoin. Health factor = (10.000 x 0,80) / 6.000 = **1,333**.

- **HF > 1:** aman.
- **HF < 1:** posisi masuk daftar likuidasi.
- **HF naik** kalau harga jaminan naik atau utang dibayar.
- **HF turun** kalau harga jaminan jatuh atau bunga menambah utang.

Perhatikan: pembilangnya pakai **liquidation threshold**, bukan LTV. LTV itu batas saat meminjam, liquidation threshold itu batas kapan posisi bisa dilikuidasi, dan angkanya lebih tinggi. Selisih antara keduanya adalah bantalan yang membuat posisi tidak langsung kena begitu harga turun sedikit.

## Likuidasi

Terjadi saat HF jatuh di bawah 1. Mekanismenya:

1. Likuidator membayar sebagian utang peminjam.
2. Likuidator menerima jaminan senilai pembayaran itu **plus liquidation bonus** sebagai imbalan.
3. Semua ini **permissionless**. Siapa pun bisa jadi likuidator, dan itulah kenapa likuidasi di Aave sangat kompetitif dan dijalankan bot.

Batas jumlah yang bisa dilikuidasi:

- Sampai **50% dari total utang**, kalau HF masih di atas 0,95 dan nilai jaminan maupun utang masing-masing minimal $2.000.
- Sampai **100%**, kalau HF sudah 0,95 atau di bawahnya, atau kalau salah satu dari nilai jaminan atau utang di bawah $2.000.
- Likuidasi sebagian harus menyisakan minimal $1.000 di jaminan dan utang. Kalau tidak cukup, posisinya harus dibersihkan penuh.

Aturan terakhir itu mencegah debu (dust): sisa posisi yang terlalu kecil untuk dilikuidasi lagi akan menggantung selamanya.

## Fitur yang membedakan v3 dari v2

- **E-Mode (Efficiency Mode).** Aset yang harganya berkorelasi (misal sesama stablecoin) bisa dikelompokkan, dan di dalam kelompok itu LTV-nya jauh lebih tinggi. Efeknya, leverage tinggi jadi efisien modal.
- **Isolation Mode.** Aset baru atau volatil bisa didaftarkan sebagai jaminan tanpa membahayakan protokol: hanya bisa dipakai meminjam sekumpulan aset tertentu (biasanya stablecoin) dan dibatasi debt ceiling.
- **Siloed Borrowing.** Flag per reserve. Kalau diaktifkan, orang yang meminjam aset itu tidak boleh punya utang lain di pool yang sama.
- **Aave Earn Vaults.** Vault berbunga sesuai ERC-4626, jadi posisi supply bisa dibungkus dan dikelola dengan struktur kepemilikan dan fee sendiri.

## Flash loan

Pinjam tanpa jaminan, dengan syarat **dikembalikan di transaksi yang sama**. Kalau tidak kembali, seluruh transaksi revert, jadi tidak ada risiko bagi protokol.

Alurnya:

1. Panggil `Pool.flashLoanSimple(receiverAddress, asset, amount, params, referralCode)`.
2. Pool mengirim aset ke `receiverAddress`, lalu memanggil `executeOperation(asset, amount, premium, initiator, params)`.
3. Di situ lo pakai dananya, lalu **approve** Pool untuk menarik `amount + premium`.
4. Pool menarik kembali `amount + premium`. Kalau gagal, semuanya batal.

Receiver wajib mengimplementasikan `IFlashLoanSimpleReceiver`, yang isinya `executeOperation(...)`, `ADDRESSES_PROVIDER()`, dan `POOL()`.

Kegunaan yang sah: arbitrase, tukar jaminan (collateral swap), likuidasi sendiri posisi yang mau ditutup, dan refinancing. Yang penting dipahami: flash loan bukan celah keamanan, tapi **amplifier**. Kalau ada bug lain di protokol, flash loan bikin bug itu bisa dieksploitasi tanpa modal awal.

## Data terukur dari mainnet

Dibaca langsung dari `Pool` Aave V3 di Ethereum mainnet, `0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2`, pada block **26175066**:

| Yang dibaca | Hasil |
|---|---|
| `FLASHLOAN_PREMIUM_TOTAL()` | `5` (dua desimal) = **0,05%** |
| `FLASHLOAN_PREMIUM_TO_PROTOCOL()` | `10000` dari `10000` = **100% dari premium masuk ke protokol** |
| `getReservesList()` | **67 reserve** |

Konfigurasi reserve WETH, dibaca lewat `getConfiguration(address)` lalu di-decode sesuai layout bitmap `ReserveConfiguration`:

| Parameter | Nilai |
|---|---|
| LTV | 8050 = **80,50%** |
| Liquidation threshold | 8300 = **83,00%** |
| Liquidation bonus | 10500 = **105,00%** (likuidator dapat 5%) |
| Decimals | 18 |
| isActive / isFrozen | true / false |
| borrowingEnabled | true |

Dua hal yang langsung kelihatan dari angka itu:

1. **Bantalan antara LTV dan liquidation threshold itu 2,5 poin persentase** (80,50% ke 83,00%). Kecil. Artinya harga WETH turun sekitar 3% saja dari titik pinjam maksimal sudah cukup mendekatkan posisi ke batas likuidasi. Ini kenapa E-Mode dan pemantauan health factor itu penting, bukan teori.
2. **Liquidation bonus 5% itu insentif yang cukup besar** buat bot. Untuk posisi $100.000, hadiahnya $5.000, dan itu sebabnya likuidasi terjadi dalam hitungan blok, bukan jam.

Cara mereproduksi:

```bash
RPC=https://ethereum-rpc.publicnode.com
POOL=0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2
cast call $POOL "FLASHLOAN_PREMIUM_TOTAL()(uint128)" --rpc-url $RPC
cast call $POOL "getConfiguration(address)(uint256)" 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2 --rpc-url $RPC
```

Angka-angka ini bisa berubah kapan saja lewat governance. Kalau mau dipakai, baca ulang, jangan pakai angka di tabel ini.

## Yang belum dikerjakan

- Simulasi skenario likuidasi di spreadsheet (bagian dari task 30 Okt), termasuk menghitung berapa penurunan harga yang bikin HF jatuh di bawah 1 untuk beberapa komposisi jaminan.
- Baca source code `Pool.sol` dan `LiquidationLogic.sol` sampai level alur eksekusi.
- Implementasi flash loan receiver: itu deliverable 31 Okt, project terpisah.
