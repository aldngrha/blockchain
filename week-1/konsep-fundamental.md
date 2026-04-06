# Week 1: Fundamental Blockchain & Kriptografi

Dokumen ini merangkum konsep-konsep dasar blockchain dan kriptografi yang diimplementasikan pada file-file di minggu pertama.

## 1. Hashing & SHA-256 (`math_test.ts`)

Fungsi Hash (seperti SHA-256) adalah inti dari keamanan blockchain.

*   **Satu Arah (Deterministic):** Input yang sama akan selalu menghasilkan output (hash) yang persis sama. Namun, mustahil mengembalikan hash menjadi input aslinya.
*   **Avalanche Effect:** Perubahan sekecil apa pun pada input (bahkan hanya 1 karakter) akan mengubah keseluruhan output hash secara drastis. Ini membuat data di blockchain sangat mudah diverifikasi dan mustahil dimanipulasi secara diam-diam.

## 2. Struktur Blockchain (`blockchain.ts`)

Blockchain pada dasarnya adalah struktur data *Linked List* yang sangat aman.

*   **Block:** Setiap blok menyimpan sekumpulan data (seperti transaksi).
*   **Previous Hash:** Setiap blok (kecuali Genesis Block/blok pertama) menyimpan *hash* dari blok sebelumnya. Rantai hash inilah yang menghubungkan seluruh blok.
*   **Tamper-Proof:** Jika seseorang mengubah data di satu blok lama, *hash* blok tersebut akan berubah. Akibatnya, `previousHash` di blok berikutnya menjadi tidak cocok, dan seluruh rantai setelahnya menjadi tidak valid (`isChainValid() === false`).

## 3. Proof of Work & Mining (`blockchain.ts` & `bitcoin_sim.ts`)

Bagaimana cara mencegah orang melakukan spam blok baru atau memanipulasi rantai dengan cepat? Jawabannya adalah **Proof of Work (PoW)**.

*   **Tujuan:** Membuat proses penambahan blok baru menjadi lambat, sulit, dan membutuhkan sumber daya komputasi (CPU/Listrik).
*   **Nonce & Difficulty:** Sistem menetapkan target *Difficulty* (misal: hash baru harus diawali dengan empat angka nol `"0000"`). Penambang (Miner) harus mencari angka acak yang disebut **Nonce**.
*   **Proses Mining:** Miner menggabungkan data blok dengan Nonce secara berulang-ulang, menghitung hash-nya satu per satu secara *brute-force* sampai menemukan hash yang memenuhi syarat *Difficulty*.
*   **Penyesuaian (Difficulty Adjustment):** Seperti disimulasikan di `bitcoin_sim.ts`, jaringan bisa mengatur tingkat kesulitan secara otomatis. Jika blok ditemukan terlalu cepat, *difficulty* dinaikkan, dan sebaliknya, agar waktu pembuatan blok tetap stabil (misal: Bitcoin 10 menit, simulasi kita 2 detik).

## 4. Wallet & Identitas (`wallet.ts`)

Di blockchain, identitas tidak menggunakan sistem *username/password* tradisional.

*   **Mnemonic (Seed Phrase):** Kumpulan kata acak (biasanya 12-24 kata) yang berfungsi sebagai kunci utama pemulihan seluruh asetmu.
*   **Private Key & Address:** Dari Mnemonic, diturunkan Private Key rahasia. Dari Private Key, diturunkan Address (Alamat Publik) yang berawalan `0x`. Proses ini berjalan satu arah berkat Kriptografi Kurva Eliptik (Elliptic Curve Cryptography).
*   **Keamanan Ekstrem:** Tidak ada fitur "Lupa Password" atau "Customer Service". Siapa pun yang mengetahui Mnemonic atau Private Key akan memiliki kendali penuh atas akun tersebut secara permanen.
