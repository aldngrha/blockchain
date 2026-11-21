# SPEC: CCIP Cross-Chain Message

> Task roadmap: 25 Okt 2026. "Chainlink CCIP intro. Buat simple cross-chain message dari Sepolia ke Arbitrum Sepolia pakai CCIP. Pahami bridge risk, why cross-chain is hard."

## 1. Tujuan

Mengirim payload data dari satu chain ke chain lain lewat Chainlink CCIP, dan menerimanya dengan aman di sisi tujuan. Fokusnya bukan fitur, tapi dua properti keamanan yang wajib ada di setiap receiver CCIP.

## 2. Scope

### Masuk scope

- `CrossChainSender`: mengirim data-only message (`tokenAmounts` kosong) dan mengurus fee.
- `MessageReceiver`: menerima message, validasi sumber, simpan message terakhir.
- Test lokal end-to-end pakai mock router.
- Deploy script yang menulis `deployments/<chainId>.json`.

### Di luar scope

- Transfer token lintas chain (`tokenAmounts` tidak kosong). Butuh approve dan fee token, dan itu materi terpisah.
- CCIP programmable token transfer, rate limit, dan RMN.
- Integrasi frontend.

## 3. Kontrak

### 3.1 `CrossChainSender`

| Fungsi | Akses | Keterangan |
|---|---|---|
| `sendMessage(uint64, address, bytes, uint256, bool)` | siapa pun | Kirim data dengan gas limit dan preferensi urutan eksplisit |
| `sendMessage(uint64, address, bytes)` | siapa pun | Pakai `defaultGasLimit` dan urutan berurutan |
| `getFee(...)` | view | Fee dalam native gas, dihitung dari router |
| `buildMessage(...)` | pure | Bangun struct `Client.EVM2AnyMessage` |
| `setDefaultGasLimit(uint256)` | owner | Ubah gas limit default |
| `setPaused(bool)` | owner | Hentikan pengiriman |

Yang penting: **fee dihitung dulu, lalu sisa `msg.value` dikembalikan ke pemanggil.** Ini bukan kerapian, ini kebutuhan, karena router CCIP menerima kelebihan bayar dan **tidak** mengembalikannya (didokumentasikan di API reference: "the overpayment is accepted with no refund").

### 3.2 `MessageReceiver`

| Fungsi | Akses | Keterangan |
|---|---|---|
| `ccipReceive(Client.Any2EVMMessage)` | **hanya router** | Entry point dari CCIP |
| `supportsInterface(bytes4)` | view | Wajib `true` untuk `IAny2EVMMessageReceiver` |
| `setTrustedSender(uint64, address, bool)` | owner | Allowlist per chain selector |
| `getRouter()` | view | Address router yang divalidasi |

State: `messageCount`, `lastMessageId`, `lastSourceChainSelector`, `lastSender`, `lastData`.

## 4. Invariants

- **I-1:** `ccipReceive` tidak bisa dipanggil siapa pun selain `i_ccipRouter`. Kalau tidak, siapa pun bisa memalsukan message.
- **I-2:** Message diterima hanya kalau pasangan `(sourceChainSelector, sender)` ada di allowlist. Kalau tidak, revert `UntrustedSender`.
- **I-3:** `supportsInterface(type(IAny2EVMMessageReceiver).interfaceId)` selalu `true`. Kalau `false`, CCIP hanya mentransfer token dan payload-nya dibuang tanpa error.
- **I-4:** `messageCount` naik tepat satu untuk setiap message yang diterima.
- **I-5:** Pemanggil `sendMessage` hanya kehilangan sebesar fee. Kelebihan `msg.value` kembali.
- **I-6:** `sendMessage` revert kalau `msg.value < fee`, tidak pernah mengirim dengan fee kurang.

## 5. Edge cases

| # | Kasus | Perilaku |
|---|---|---|
| E1 | `receiver == address(0)` | revert `ZeroAddress` |
| E2 | `msg.value < fee` | revert `FeeNotCovered(required, provided)` |
| E3 | `msg.value > fee` | kelebihan dikembalikan, emit `FeeRefunded` |
| E4 | Pengiriman saat `paused` | revert `IsPaused` |
| E5 | Router di-deploy dengan `address(0)` | revert `InvalidRouter(address(0))` |
| E6 | `ccipReceive` dipanggil non-router | revert `InvalidRouter(caller)` |
| E7 | Sender tidak ada di allowlist | revert `UntrustedSender(chain, sender)` |
| E8 | Chain selector tujuan tidak didukung | revert `UnsupportedDestinationChain` |
| E9 | Payload kosong | diterima, `lastData` jadi `0x` |
| E10 | `tokenAmounts` tidak kosong | revert di mock (`TokensNotSupported`); di produksi butuh penanganan token |
| E11 | Refund gagal (receiver menolak ETH) | revert `RefundFailed` |

## 6. Keamanan: dua hal yang paling sering salah di receiver CCIP

1. **Tidak ada validasi `msg.sender` di `ccipReceive`.** Tanpa `onlyRouter`, siapa pun bisa memanggil `ccipReceive` langsung dengan message karangan. Ini setara pintu terbuka.
2. **Tidak ada validasi sumber.** Walaupun `onlyRouter` benar, router akan menyampaikan message dari chain mana pun dan dari kontrak mana pun. Kalau receiver tidak memeriksa `(sourceChainSelector, sender)`, attacker cukup deploy kontrak di chain lain, kirim message ke receiver, dan receiver menganggapnya sah. Ini yang diuji `test_Receiver_RevertsWhenSenderIsNotTrusted` dan `test_Receiver_TrustIsPerChain`.

Catatan tambahan: kalau `ccipReceive` revert, **transfer token di message yang sama juga revert**. Jadi fungsi ini harus murah dan deterministik, jangan ada logika yang bisa gagal karena kondisi eksternal.

## 7. Kenapa cross-chain itu susah

Tiga hal yang tidak muncul di single-chain dan muncul di sini:

1. **Tidak ada atomicity antar chain.** Kirim sukses di chain A bukan jaminan eksekusi sukses di chain B. Kalau sisi tujuan revert, message masuk state FAILED dan harus dieksekusi manual.
2. **Trust boundary-nya bergeser.** Di single-chain, `msg.sender` adalah kebenaran. Di cross-chain, `msg.sender` adalah router, dan kebenaran sebenarnya ada di field `sender` yang dikirim dari chain lain. Salah paham soal ini adalah sumber bug paling umum.
3. **Biaya dan waktu tidak deterministik.** Fee bergantung pada kondisi chain tujuan, dan waktu sampai bergantung pada finalitas chain asal plus antrean eksekusi.

## 8. Rencana verifikasi

- `forge build` dan `forge test` hijau di lokal (24 test, sudah diverifikasi).
- Deploy lokal di anvil: memastikan script jalan dan menulis `deployments/31337.json`.
- Deploy testnet Sepolia ke Arbitrum Sepolia: **langkah manual user**, butuh LINK atau native gas, RPC, dan private key. Tidak ada address atau tx hash yang ditulis sebelum benar-benar dijalankan.
