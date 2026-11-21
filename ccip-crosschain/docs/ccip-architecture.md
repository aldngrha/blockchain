# Cara Kerja CCIP

> Task roadmap 25 Okt 2026: "Chainlink CCIP intro. Pahami bridge risk, why cross-chain is hard."
>
> Dokumen ini penjelasan konsep. Untuk kode yang dipakai di project ini, lihat `../SPEC.md` dan `../README.md`.
>
> Sumber: docstring resmi kontrak CCIP di repo `smartcontractkit/ccip` (branch `ccip-develop`), API reference CCIP v1.5.1 di docs.chain.link, dan pembacaan langsung kode kontrak. Bagian yang bukan dari sumber itu ditandai sebagai pemahaman umum.

## 1. Masalah yang diselesaikan

Chain itu pulau. Kontrak di Sepolia tidak bisa membaca state di Arbitrum, dan sebaliknya. Tidak ada cara bagi kontrak di chain A untuk memanggil kontrak di chain B dalam satu transaksi, karena keduanya tidak berbagi state maupun mesin eksekusi.

CCIP (Cross-Chain Interoperability Protocol) menjawab itu dengan dua hal:

1. **Pesan data.** Payload sembarang dikirim dari chain asal, diterima dan diproses oleh kontrak di chain tujuan.
2. **Transfer token.** Aset berpindah antar chain.

Yang penting dipahami sejak awal: **tidak ada atomicity antar chain.** Kirim sukses di chain A tidak menjamin eksekusi sukses di chain B. Ini perbedaan fundamental dari transaksi biasa, dan semua kerumitan CCIP lahir dari situ.

## 2. Model lane

CCIP bekerja dengan model **lane**: satu lane adalah jalur satu arah dari satu chain asal ke satu chain tujuan. Sepolia ke Arbitrum Sepolia itu satu lane. Arbitrum Sepolia ke Sepolia itu lane yang berbeda.

Tiap lane punya konfigurasi sendiri: OnRamp dan OffRamp sendiri, rate limit sendiri, fee sendiri, dan konfigurasi verifikasi sendiri. Konsekuensinya: dukungan satu arah tidak berarti dukungan arah sebaliknya, dan limit di satu lane tidak berlaku di lane lain.

## 3. Komponen on-chain

Dari struktur kontrak resminya:

| Kontrak | Perannya |
|---|---|
| `Router` | Pintu masuk. Docstring resminya: "the entry point for the end user wishing to send data across chains". Melayani on-ramp dan off-ramp |
| `OnRamp` | Sisi asal. "Handles lane-specific fee logic". Memvalidasi pesan, mengurus fee, dan meneruskan |
| `OffRamp` | Sisi tujuan. "Enables OCR networks to execute multiple messages in an OffRamp in a single transaction" |
| `CommitStore` | Menyimpan hasil komit pesan (bagian dari arsitektur commit dan execute) |
| `FeeQuoter` | Hitung fee. Menyimpan harga gas dalam USD per chain tujuan dan harga token dalam USD |
| `RMN` | Risk Management Network. Kontraknya "owned by RMN" |
| `ARMProxy` | Proxy ke ARM, jalur kontak ke jaringan RMN |
| `pools/` (TokenPool) | Lock atau burn di sisi asal, mint atau release di sisi tujuan |
| `NonceManager` | Urutan pesan per pengirim |
| `AggregateRateLimiter` | Batas laju agregat, pengaman nilai |

Dua kontrak terakhir di tabel itu yang sering luput dibahas orang, padahal keduanya pengaman penting: nonce mencegah pesan diulang atau dijalankan di luar urutan, dan rate limiter membatasi berapa nilai yang boleh keluar dari sebuah lane dalam jendela waktu tertentu.

Detail yang menarik dari docstring `OnRamp` dan `OffRamp`: keduanya disebut sebagai **"xchain upgradeable unit"**. Artinya OnRamp dan OffRamp itu satu unit yang harus sinkron, dan mengubah salah satunya berarti meng-upgrade keduanya. Ini konsisten dengan model lane: satu lane, satu pasangan, satu versi.

## 4. Komponen off-chain

Yang menjalankan pekerjaan di luar chain:

- **DON (Decentralized Oracle Network), berbasis OCR.** Ada dua peran. Plugin **commit** mengamati event di chain asal dan menyetujui root pesan, dan plugin ini dikonfigurasi **dengan** verifikasi tanda tangan. Plugin **execute** menjalankan pesan di chain tujuan, dan dikonfigurasi **tanpa** verifikasi tanda tangan. Pemisahan ini dijelaskan langsung di docstring `OffRamp`.
- **RMN (Risk Management Network).** Jaringan independen dari DON. Tugasnya mengawasi dan bisa menghentikan sebuah lane kalau ada anomali. Independen dari DON itu kuncinya: kalau verifikasinya cuma satu jaringan, satu jaringan itu jadi titik kegagalan tunggal.

## 5. Alur satu pesan, dari awal sampai akhir

1. **Client** memanggil `Router.ccipSend(selectorTujuan, pesan)` di chain asal. Kalau fee dibayar pakai native gas, `msg.value` dibawa di sini.
2. **Router** meneruskan ke **OnRamp** lane yang sesuai. OnRamp memvalidasi, mengurus fee, menetapkan nonce, dan memancarkan event pesan.
3. **DON commit plugin** mengamati event itu, menyetujui root pesan, lalu **CommitStore** menyimpannya di sisi tujuan.
4. **DON execute plugin** mengeksekusi pesan yang sudah di-commit.
5. **OffRamp** memvalidasi dan memanggil **Router** di chain tujuan.
6. **Router** memanggil kontrak penerima, lewat `ccipReceive(message)`.

Kontrak penerima harus mengimplementasikan interface yang benar, kalau tidak, payload-nya dibuang. Detail persisnya ada di `../SPEC.md` section 6.

Penting: langkah 1 sampai 6 itu **tidak satu transaksi**. Ada jeda antara kirim dan eksekusi, dan jeda itu tidak bisa diprediksi dengan tepat.

## 6. Chain selector, bukan chain id

CCIP memakai **chain selector**, sebuah angka 64-bit, untuk mengidentifikasi chain. Ini **bukan** EVM chain id. Sepolia punya chain id 11155111, tapi chain selector-nya angka yang sama sekali berbeda.

Ini salah satu kesalahan paling umum pemula, dan gejalanya menjebak: pakai chain id, dan transaksinya bisa revert dengan `UnsupportedDestinationChain`, atau lebih buruk, lolos ke lane yang salah. Chain selector harus diambil dari CCIP directory resmi, bukan dari dokumentasi lama atau hafalan.

## 7. Fee

Fee dihitung oleh `FeeQuoter` berdasarkan harga gas di chain tujuan dan harga token. Bisa dibayar dengan:

- **Native gas.** Set `feeToken = address(0)` dan kirim `msg.value`.
- **LINK.** Set `feeToken` ke address LINK.

Jebakan yang sudah didokumentasikan resmi dan sudah gue tangani di project ini: **kelebihan `msg.value` tidak dikembalikan.** Kalau lo kirim 1 ETH untuk fee yang cuma 0,001 ETH, 0,999 ETH-nya hangus. Karena itu `CrossChainSender` di project ini menghitung fee dulu lewat `getFee`, lalu mengembalikan sisanya ke pemanggil.

## 8. Kalau pesannya gagal

Kalau `ccipReceive` di sisi tujuan revert, pesannya **tidak hilang**. Pesan masuk state FAILED, dan bisa dieksekusi manual.

Yang harus dipahami dari perilaku ini:

- Kalau receiver revert, **transfer token di pesan yang sama juga revert**. Jadi receiver harus murah dan deterministik, jangan ada logika yang bisa gagal karena kondisi eksternal.
- Pesan yang gagal berarti **dana bisa tertahan** sampai ada yang mengeksekusi manual. Kalau receiver-nya punya bug yang selalu bikin revert, dananya nyangkut permanen sampai kontraknya di-upgrade.

Ini bagian yang paling sering diremehkan: cross-chain bukan cuma soal mengirim, tapi soal siapa yang bertanggung jawab kalau sisi tujuan gagal.

## 9. Kenapa cross-chain itu susah

Tiga hal yang tidak ada di single-chain dan muncul di sini:

1. **Tidak ada atomicity.** Transaksi di chain A dan chain B tidak bisa dibatalkan bersama. Kalau sisi tujuan gagal, sisi asal sudah terlanjur jalan.
2. **Trust boundary-nya bergeser.** Di single-chain, `msg.sender` adalah kebenaran mutlak. Di cross-chain, `msg.sender` di receiver adalah Router, dan kebenaran sebenarnya ada di field `sender` yang datang dari chain lain. Salah paham soal ini adalah sumber bug paling umum di aplikasi cross-chain.
3. **Biaya dan waktu tidak deterministik.** Fee bergantung pada kondisi chain tujuan saat pesan diproses. Waktu sampai bergantung pada finalitas chain asal plus antrean eksekusi.

## 10. Bridge risk

Yang membedakan CCIP dari bridge buatan sendiri atau bridge pihak ketiga bukan cuma fitur, tapi **siapa yang menjamin**.

| Aspek | Bridge pihak ketiga | CCIP |
|---|---|---|
| Verifikasi | Sering multisig atau validator set milik operator | DON untuk komit dan eksekusi, plus RMN independen |
| Asumsi keamanan | Percaya operator tidak nakal dan tidak kena hack | Percaya dua jaringan independen tidak kompromi bersamaan |
| Batas kerugian | Tergantung desain | Rate limit per lane membatasi berapa yang bisa keluar |
| Kalau gagal | Tergantung operator, sering tidak ada jalur manual | Pesan masuk state FAILED dan bisa dieksekusi manual |

Pola yang berulang di insiden bridge: yang jebol bukan konsensus chain-nya, tapi **kontrak bridge atau kunci yang dicuri**. Angka kerugiannya biasanya besar karena bridge mengumpulkan likuiditas dari banyak pengguna di satu titik. Itu sebabnya rate limit penting: batas kerugian maksimum yang bisa terjadi dalam satu jendela waktu, walaupun verifikasinya jebol.

Aturan praktisnya: **bridge kanonik untuk jumlah besar, bridge pihak ketiga cuma kalau memang tidak bisa menunggu.**

## 11. Yang sudah diuji di project ini, dan yang belum

Sudah diuji, 24 test hijau:

- Validasi `msg.sender` di `ccipReceive` (I-1). Tanpa ini, siapa pun bisa mengirim pesan palsu.
- Allowlist `(sourceChainSelector, sender)` (I-2). Tanpa ini, attacker cukup deploy kontrak di chain lain.
- `supportsInterface` mengembalikan `true` (I-3). Kalau `false`, payload dibuang tanpa error.
- Refund kelebihan `msg.value` (I-5).

Belum, dan ini batas pemahaman yang jujur:

- Semua yang di luar `src/` project ini: OCR, RMN, token pool, rate limit. Itu infrastruktur Chainlink, dan di sini cuma dipahami dari dokumentasi dan source-nya, bukan dijalankan.
- Transfer token lintas chain. Project ini data-only.
- Deploy testnet sungguhan. Belum dijalankan, dan tidak ada address atau angka fee yang ditulis sebelum dijalankan.
