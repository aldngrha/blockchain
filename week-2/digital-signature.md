# Week 2: Digital Signature & Kriptografi Asimetris

Dokumen ini merangkum konsep **Digital Signature** (Tanda Tangan Digital) yang diimplementasikan pada file `signature.ts`. Konsep ini adalah fondasi utama keamanan di seluruh sistem blockchain (seperti Ethereum atau Bitcoin).

## Konsep Dasar

Digital Signature bekerja mirip dengan tanda tangan di dunia nyata, namun menggunakan perhitungan matematis (Kriptografi Asimetris) yang membuatnya jauh lebih aman dan mustahil dipalsukan.

### 1. Identitas: Private Key & Address
Di Web3, identitas kita tidak menggunakan *username* dan *password*, melainkan pasangan kunci kriptografi.

*   **Private Key (Kunci Rahasia):**
    Ibarat **PIN ATM** atau stempel rahasia. Ini adalah angka acak yang sangat panjang (umumnya 64 karakter heksadesimal). Siapa pun yang mengetahui Private Key, dialah yang menguasai aset di dalamnya.
    *Contoh:* `0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80`

*   **Public Key & Address (Kunci Publik & Alamat):**
    Ibarat **Nomor Rekening**. Address adalah turunan langsung dari Private Key melalui proses matematika satu arah.
    *   **Proses Penurunan:** `Private Key` -> (Elliptic Curve Cryptography) -> `Public Key` -> (Keccak-256 Hash, ambil 20 byte terakhir) -> `Address`.
    *   **Sifat Satu Arah:** Sangat mudah mengubah Private Key menjadi Address, namun **mustahil** menebak Private Key jika hanya mengetahui Address-nya.
    *Contoh:* `0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266`

### 2. Kenapa Selalu Menggunakan Awalan `0x`?
Di ekosistem Web3 (Ethereum, Polygon, dll), awalan `0x` adalah standar yang menunjukkan bahwa data tersebut berformat **Heksadesimal (Basis 16)**.
*   Angka `0` menandakan ini adalah sebuah nilai, dan `x` berarti *hexadecimal*.
*   Heksadesimal (0-9 dan a-f) digunakan karena ini adalah cara paling rapi dan padat untuk merangkum data biner panjang yang digunakan oleh komputer dan blockchain.
*   Private Key, Address, Hash Transaksi, hingga Signature selalu diawali dengan `0x`.

## Alur Kerja Digital Signature (`signature.ts`)

Berikut adalah cara kerja penandatanganan transaksi di blockchain:

### Langkah 1: Sign Message (Menandatangani Pesan)
```typescript
const message = "Aldi authorize: kirim 1 ETH ke Alice";
const signature = await account.signMessage({ message });
```
*   Kita membuat sebuah "pesan" (instruksi transaksi).
*   Kita menggunakan **Private Key** untuk memproses pesan tersebut secara matematis (`signMessage`).
*   Hasilnya adalah **Signature** (Tanda Tangan Digital) yang unik. Jika pesannya diubah sedikit saja, atau menggunakan Private Key yang berbeda, hasil Signature-nya akan berubah total.

### Langkah 2: Verify Signature (Memverifikasi Tanda Tangan)
```typescript
const isValid = await publicClient.verifyMessage({
  address: account.address,
  message,
  signature,
});
```
*   Ini adalah simulasi bagaimana jaringan blockchain memvalidasi transaksi.
*   Blockchain **TIDAK TAHU** Private Key kita. Mereka hanya memiliki 3 data publik: **Address (Pengirim)**, **Pesan**, dan **Signature**.
*   Fungsi `verifyMessage` menggunakan perhitungan matematika untuk memastikan: *"Apakah Signature ini benar-benar dibuat oleh pemilik Private Key dari Address tersebut, khusus untuk Pesan ini?"*
*   Jika `true`, transaksi dianggap sah dan dieksekusi.

### Langkah 3: Keamanan (Anti-Pemalsuan)
```typescript
const fakeSignatureRaw = "0x" + "a".repeat(130);
const fakeSignature = isHex(fakeSignatureRaw) ? fakeSignatureRaw : "0x";
// Hasil verifikasi: false
```
*   Jika ada pihak yang mencoba memalsukan Signature secara acak, fungsi verifikasi akan langsung mengembalikan nilai `false`.
*   Secara matematis, mustahil bagi komputer mana pun saat ini untuk menciptakan atau menebak Signature yang valid tanpa memiliki Private Key aslinya.

---
**Kesimpulan:**
Digital Signature adalah bukti kriptografis tak terbantahkan yang menggantikan peran pihak ketiga (seperti Bank) dalam memverifikasi persetujuan transaksi oleh pengguna.
