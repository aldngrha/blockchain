# Week 1 — Blockchain Fundamentals
**Tanggal:** 1–5 April 2026  
**Status:** Selesai ✓

---

## Yang dipelajari minggu ini

### 1. Hash & SHA-256
Hash adalah fungsi satu arah — input data apapun, output selalu 64 karakter hex dengan panjang sama. Tidak bisa dibalik. Perubahan 1 huruf saja di data asli akan menghasilkan hash yang sama sekali berbeda.

```
"Aldi" → SHA256 → a3f8c2d1...
"aldi" → SHA256 → 9f2b71e4...  ← beda total
```

### 2. Cara kerja Blockchain
Blockchain adalah linked list di mana tiap blok menyimpan hash dari blok sebelumnya (`previousHash`). Jika data di blok lama diubah, hash blok itu berubah — dan `previousHash` di semua blok setelahnya jadi tidak cocok. Itulah yang bikin blockchain tamper-proof.

### 3. Proof of Work (PoW)
Miner berlomba mencari **nonce** — angka yang kalau digabung dengan data blok menghasilkan hash dengan syarat tertentu (misal dimulai `"00..."`). Siapa pertama menemukan → broadcast ke network → dapat reward. Nonce yang ditemukan disimpan di dalam blok sebagai bukti kerja keras yang bisa diverifikasi siapapun.

### 4. Proof of Stake (PoS)
Validator bekerja seperti satpam — mereka menstake aset sebagai jaminan kejujuran. Setiap transaksi baru divalidasi oleh node-node ini. Jujur → dapat reward. Tidak jujur → aset di-slash (hilang). Lebih hemat energi dari PoW karena tidak butuh komputasi besar.

### 5. EVM — 3 Jenis Memory
| Memory | Sifat | Analogi | Gas Cost |
|---|---|---|---|
| **Stack** | Sementara, selama eksekusi | Kalkulator | Paling murah |
| **Memory** | Sementara, selama transaksi | Kertas oret-oretan | Murah |
| **Storage** | Permanen, di blockchain | Buku permanen | Paling mahal |

`SSTORE` mahal karena menulis ke storage = memberitahu semua node di seluruh dunia untuk update database mereka masing-masing secara permanen.

### 6. Gas
Satuan ukur komputasi di EVM. Setiap opcode punya harga gas berbeda — `ADD` = 3 gas, `SSTORE` = 20.000 gas. Yang membayar adalah **user yang kirim transaksi**, bukan developer.

> Analogi: ojek online. Jarak = gas limit, harga per km = gas price.

### 7. Wallet & Cryptography
Hubungan private key → public key → address bersifat **one-way** — tidak bisa dibalik:

```
Private key  →  (Elliptic Curve)  →  Public key
Public key   →  (Keccak-256)      →  Address (0x...)
```

Siapapun yang pegang private key = pegang semua aset. Tidak ada reset, tidak ada customer service. Private key hilang = aset hilang selamanya.

### 8. EOA vs Contract Account
| | EOA | Contract Account |
|---|---|---|
| Dikontrol oleh | Private key (manusia) | Kode (smart contract) |
| Bisa inisiasi transaksi? | Ya | Tidak |
| Punya kode? | Tidak | Ya |
| Contoh | MetaMask wallet | Uniswap, Aave |

---

## Yang dibangun minggu ini

- **Mini blockchain** di TypeScript dengan SHA-256 dari Node.js `crypto` built-in
- **Proof of Work** — nonce mining dengan difficulty adjustable
- **Tamper test** — buktikan `isChainValid()` return false setelah data diubah
- **MetaMask** setup di Sepolia testnet + claim testnet ETH
- **Wallet generator** via `viem` — generate mnemonic + address via code

---

## Insight paling menarik

- Blockchain bukan teknologi yang rumit secara konsep — basically cuma linked list dengan hash. Yang jenius adalah kombinasinya dengan incentive mechanism (reward + slashing).
- `SSTORE` mahal bukan karena teknis semata, tapi karena implikasinya: ribuan komputer di seluruh dunia harus update state mereka selamanya. Gas fee = biaya desentralisasi.
- Private key adalah identitas di blockchain. Tidak ada backup, tidak ada recovery. Ini yang paling beda dari sistem tradisional.

---

## Yang masih perlu diperdalam

- [ ] Detail matematis Elliptic Curve Cryptography (bagaimana private key → public key)
- [ ] Cara kerja Merkle Tree di dalam blok
- [ ] Bedanya PoS implementation di Ethereum vs chain lain (Solana, Cosmos)

---

## Minggu depan

**Topik:** Digital Signatures — bagaimana private key bisa membuktikan kepemilikan tanpa mengekspos private key itu sendiri. Ini fondasi dari "hanya pemilik wallet yang bisa kirim transaksi."
