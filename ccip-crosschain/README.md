# CCIP Cross-Chain Message

Project Foundry buat task roadmap 25 Okt 2026: kirim data lintas chain lewat Chainlink CCIP, dan terima dengan aman di sisi tujuan.

## Isi

| File | Keterangan |
|---|---|
| `src/CrossChainSender.sol` | Kirim data-only message, hitung fee, refund kelebihan `msg.value` |
| `src/MessageReceiver.sol` | Terima message, validasi router dan sumber, simpan message terakhir |
| `src/interfaces/IRouterClient.sol` | Subset interface router CCIP yang dibutuhkan |
| `src/interfaces/IAny2EVMMessageReceiver.sol` | Interface yang dicek CCIP sebelum mengirim payload |
| `src/libraries/Client.sol` | Struct wire-format CCIP (message, token amount, extraArgs) |
| `test/mocks/MockRouter.sol` | Router tiruan yang bisa deliver message dalam satu transaksi |
| `test/CrossChain.t.sol` | 24 test, termasuk 3 fuzz test |

Dokumen: **[`docs/ccip-architecture.md`](docs/ccip-architecture.md)** (cara kerja CCIP: komponen, alur pesan, fee, pesan gagal, bridge risk), `SPEC.md` (desain, invariants, edge cases), `devlog/` (catatan harian).

## Kenapa interface-nya di-vendor

`Client`, `IRouterClient`, dan `IAny2EVMMessageReceiver` di `src/` ditulis ulang mengikuti **Chainlink CCIP v1.5.1 API reference** (docs.chain.link), bukan diimpor dari paket resmi. Alasannya: project jadi bisa di-build dan di-test tanpa dependency eksternal selain OpenZeppelin dan forge-std.

Yang di-vendor cuma **interface dan struct**, bukan implementasi protokol. Struct `Client` adalah wire-format, jadi urutan field dan tipenya tidak boleh diubah.

**Kalau mau deploy sungguhan**, lebih baik pakai paket resmi supaya selalu sinkron dengan protokol:

```bash
npm install @chainlink/contracts-ccip
# lalu remap: @chainlink/contracts-ccip/=node_modules/@chainlink/contracts-ccip/
```

Dan `MessageReceiver` sebaiknya inherit `CCIPReceiver` dari paket itu, bukan mengimplementasikan interface-nya sendiri seperti di sini.

## Jalanin

```bash
forge build
forge test
```

Dependency (`lib/forge-std`, `lib/openzeppelin-contracts`) tidak di-commit. Setelah clone:

```bash
forge install foundry-rs/forge-std
git clone --depth 1 --branch v5.1.0 https://github.com/OpenZeppelin/openzeppelin-contracts.git lib/openzeppelin-contracts
```

## Deploy lokal (sudah diverifikasi)

Anvil di port khusus supaya tidak tabrakan dengan project lain:

```bash
anvil -p 8549
```

Lalu:

```bash
PRIVATE_KEY=<anvil key> ROUTER=<router address> \
forge script script/DeployCCIP.s.sol:DeployCCIP \
  --rpc-url http://127.0.0.1:8549 --broadcast
```

`ROUTER` sengaja dibaca dari env, bukan di-hardcode, karena address router beda per chain dan bisa berubah. Ambil dari CCIP directory resmi.

Hasil verifikasi lokal: `deployments/31337.json` tertulis, `getRouter()` mengembalikan address yang diberikan, `supportsInterface(0x85572ffb)` mengembalikan `true`.

## Deploy ke Sepolia dan Arbitrum Sepolia (BELUM dijalankan)

Ini **langkah manual**, butuh dana testnet dan key. Yang perlu disiapkan:

1. RPC untuk Sepolia dan Arbitrum Sepolia.
2. Address Router CCIP di masing-masing chain, dari CCIP directory resmi Chainlink.
3. Chain selector tujuan, juga dari directory resmi. **Jangan pakai EVM chain id**, selector itu angka berbeda.
4. Dana gas. Fee bisa dibayar native gas (`feeToken = address(0)`) atau LINK.
5. Private key khusus deploy, jangan key yang isinya dana besar.

Urutan yang benar:

1. Deploy `MessageReceiver` di **Arbitrum Sepolia** (sisi tujuan).
2. Deploy `CrossChainSender` di **Sepolia** (sisi asal).
3. Di receiver, panggil `setTrustedSender(<selector Sepolia>, <address CrossChainSender di Sepolia>, true)`. **Tanpa langkah ini, semua message bakal revert `UntrustedSender`.** Ini yang paling sering kelupaan.
4. Cek fee: `sender.getFee(<selector Arb Sepolia>, <address receiver>, "hello")`.
5. Kirim: `sender.sendMessage{value: fee}(<selector Arb Sepolia>, <address receiver>, "hello")`.
6. Cek `receiver.lastData()` di Arbitrum Sepolia.

Tidak ada address kontrak, tx hash, atau angka fee yang ditulis di dokumen ini, karena deploy-nya belum dijalankan. Kalau nanti dijalankan, baru diisi.

## Yang dipelajari

Dua properti keamanan yang wajib ada di receiver CCIP, dan keduanya diuji:

1. **`onlyRouter`.** Tanpa ini, siapa pun bisa memanggil `ccipReceive` langsung dengan message karangan.
2. **Validasi `(sourceChainSelector, sender)`.** Walaupun router benar, router menyampaikan message dari chain dan kontrak mana pun. Tanpa allowlist, attacker cukup deploy kontrak di chain lain lalu mengirim ke receiver kita.

Detail lengkap plus jebakan lain ada di `SPEC.md` section 6 dan 7, dan di `devlog/`.
