# Catatan Materi Cyfrin Solidity Section 2: Simple Storage

## 1. Tipe Data Dasar (Basic Data Types)
- **boolean**: bool (true/false).
- **uint**: uint256 (unsigned integer, tidak bisa negatif).
- **int**: int256 (bisa positif atau negatif).
- **address**: Alamat wallet atau kontrak.
- **bytes**: Data mentah (bytes32, bytes1, dll).

## 2. Visibilitas (Visibility)
- **public**: Bisa diakses siapa saja.
- **private**: Hanya di dalam kontrak tersebut.
- **external**: Hanya dari luar kontrak.
- **internal**: Di dalam kontrak dan turunannya.

## 3. Struktur Data Kompleks
- **Struct**: Tipe data custom (kumpulan variabel).
- **Arrays**: List data (Fixed atau Dynamic).
- **Mappings**: Key-Value pair (seperti dictionary).

## 4. State Mutability
- **view**: Baca data saja (Tanpa Gas jika eksternal).
- **pure**: Tidak baca/tulis data blockchain.

## 5. Memory vs Storage vs Calldata
- **storage**: Permanen di blockchain.
- **memory**: Sementara (bisa diubah).
- **calldata**: Sementara (tidak bisa diubah).

## 6. Perintah Forge
- `forge compile`: Kompilasi.
- `forge test`: Testing.
- `forge script`: Deployment.
