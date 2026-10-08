# Week 2 — Ethereum Fundamental & Digital Signatures
**Tanggal:** 6–12 April 2026  
**Status:** Done

---

## Yang dipelajari minggu ini

### 1. Digital Signatures (ECDSA)
Bagaimana kita membuktikan kepemilikan tanpa membocorkan Private Key.
*   **Sign:** Menggunakan Private Key + Pesan untuk menghasilkan Signature (0x...).
*   **Verify:** Menggunakan Public Address + Pesan + Signature untuk menghasilkan boolean (True/False).
*   **Keamanan:** Signature unik per pesan. Mengubah satu huruf di pesan akan membuat signature tidak valid.

### 2. Ethereum vs Bitcoin (Whitepaper Insight)
Ethereum diciptakan sebagai "World Computer" yang memperbaiki keterbatasan Bitcoin:
*   **Turing-Complete:** Ethereum mendukung *looping* dan logika kompleks, sedangkan Bitcoin sengaja dibatasi.
*   **State-Awareness:** Bitcoin hanya tahu UTXO (sudah dipakai atau belum). Ethereum tahu "State" (semua saldo, data storage, dan kode kontrak di seluruh dunia).
*   **Value-Awareness:** Smart contract Ethereum bisa mengatur aliran dana secara presisi (misal: "kirim 0.5 ETH saja"), bukan sistem *all-or-nothing* seperti UTXO.

### 3. Ethereum sebagai State Machine
Ethereum bukan sekadar buku kas, tapi **Spreadsheet Raksasa Dunia**.
*   **State Lama + Transaksi → [EVM] → State Baru.**
*   EVM (Ethereum Virtual Machine) adalah mesin yang memproses semua perubahan ini dan memastikan ribuan komputer di dunia menghasilkan angka yang sama persis.

### 4. EOA vs Contract Account
| Fitur | EOA (Externally Owned Account) | Contract Account |
|---|---|---|
| **Kendali** | Private Key (Manusia) | Kode (Smart Contract) |
| **Inisiasi Transaksi** | Bisa | Tidak Bisa (Hanya Bereaksi) |
| **Punya Kode?** | Tidak | Ya |
| **Contoh** | MetaMask Wallet | Uniswap, Aave, Token ERC-20 |

### 5. Proof of Stake (PoS) Deep Dive
Ethereum beralih sepenuhnya ke PoS melalui **The Merge (2022)** untuk efisiensi energi (hemat 99.95%) dan keamanan yang lebih baik.

*   **Validator Lifecycle:**
    1.  **Deposit:** Stake 32 ETH ke *deposit contract*.
    2.  **Activation:** Masuk antrian (queue) sampai status *Active*.
    3.  **Duties:** Menjalankan tugas *Propose* dan *Attest*.
    4.  **Exit & Withdraw:** Keluar secara sukarela (*voluntary exit*) dan menarik kembali ETH + rewards.

*   **Tugas Utama Validator:**
    *   **Propose (Mengusulkan):** Terpilih secara acak untuk menyusun blok baru dari mempool.
    *   **Attest (Memvalidasi):** Memberikan suara (*vote*) untuk menyetujui validitas sebuah blok. Jika 2/3 validator setuju, blok menjadi *Finalized*.

*   **Finality & Slashing:**
    *   **Deterministic Finality:** Setelah ~12.8 menit (2 epoch), blok bersifat permanen dan tidak bisa diubah tanpa biaya yang sangat mahal.
    *   **Slashing:** Hukuman bagi validator nakal (seperti *double voting*). Pelaku akan kehilangan sebagian ETH-nya dan dikeluarkan paksa dari jaringan.

### 6. Solidity Data Types & Visibility
Dasar-dasar penulisan Smart Contract menggunakan bahasa Solidity.

*   **Data Types Dasar:**
    *   `uint256`: Integer positif (paling umum, 0 sampai 2^256-1).
    *   `int256`: Integer yang bisa negatif.
    *   `address`: Tipe khusus 20-byte untuk alamat wallet/kontrak.
    *   `bool`: Nilai true/false.
    *   `bytes32` vs `string`: `bytes32` lebih hemat gas untuk data pendek tetap, sedangkan `string` dinamis dan mahal di storage.

*   **Function Visibility:**
    *   `public`: Bisa dipanggil dari mana saja (dalam, luar, child contract).
    *   `private`: Hanya bisa dipanggil dari dalam kontrak itu sendiri.
    *   `internal`: Seperti private, tapi bisa diakses oleh kontrak turunan (inheritance).
    *   `external`: Hanya bisa dipanggil dari luar kontrak (lebih hemat gas untuk input besar).

*   **State Mutability:**
    | Keyword | Baca State? | Ubah State? | Terima ETH? | Gas Cost (Call) |
    |---|---|---|---|---|
    | `pure` | Tidak | Tidak | Tidak | Gratis (Off-chain) |
    | `view` | Ya | Tidak | Tidak | Gratis (Off-chain) |
    | `payable`| Ya | Ya | **Ya** | Bayar Gas |
    | (default)| Ya | Ya | Tidak | Bayar Gas |

### 7. CryptoZombies Lesson 1: Making the Zombie Factory
Membangun pabrik zombie untuk memahami struktur data kompleks dan interaksi dasar.

*   **Structs & Arrays:**
    *   **Struct:** Digunakan untuk membuat tipe data kustom (misal: `Zombie` punya `name` dan `dna`).
    *   **Dynamic Array:** `Zombie[] public zombies;` untuk menyimpan data yang jumlahnya bisa terus bertambah.
*   **Keccak256 & Typecasting:**
    *   Menggunakan `keccak256(abi.encodePacked(_str))` untuk menghasilkan angka acak (pseudo-random) dari sebuah string (misal untuk menentukan DNA zombie).
    *   **Typecasting:** Mengonversi antar tipe data (misal: `uint8(a + b)`) jika diperlukan untuk kecocokan tipe.
*   **Private Functions & Events:**
    *   **Private:** Fungsi yang hanya bisa dipanggil di dalam kontrak (konvensi nama: `_functionName`).
    *   **Events:** Cara kontrak berkomunikasi ke aplikasi luar (frontend). Contoh: `emit NewZombie(id, name, dna);` agar aplikasi tahu ada zombie baru yang dibuat.

**Contoh Kode (ZombieFactory.sol):**
```solidity
pragma solidity >=0.5.0 <0.6.0;

contract ZombieFactory {
    event NewZombie(uint zombieId, string name, uint dna);

    uint dnaDigits = 16;
    uint dnaModulus = 10 ** dnaDigits;

    struct Zombie {
        string name;
        uint dna;
    }

    Zombie[] public zombies;

    function _createZombie(string memory _name, uint _dna) private {
        uint id = zombies.push(Zombie(_name, _dna)) - 1;
        emit NewZombie(id, _name, _dna);
    }

    function _generateRandomDna(string memory _str) private view returns (uint) {
        uint rand = uint(keccak256(abi.encodePacked(_str)));
        return rand % dnaModulus;
    }

    function createRandomZombie(string memory _name) public {
        uint randDna = _generateRandomDna(_name);
        _createZombie(_name, randDna);
    }
}
```

### 8. CryptoZombies Lesson 2: Zombies Attack Their Victims
Mempelajari interaksi antar kontrak, manajemen memori, dan kontrol akses tingkat lanjut.

*   **Mappings & Addresses (`msg.sender`):**
    *   **Mapping:** *Key-value store* untuk menyimpan hubungan data (misal: ID Zombie ke Alamat Pemilik).
    *   **`msg.sender`:** Variabel global yang berisi alamat pengirim transaksi saat ini.
*   **Require (Error Handling):** Digunakan untuk validasi kondisi (misal: memastikan hanya pemilik yang bisa memberi makan zombienya). Jika gagal, transaksi dibatalkan (*revert*).
*   **Inheritance (`is`) & Imports:** Membagi kode ke dalam beberapa file dan menggunakan pewarisan untuk menjaga modularitas (`contract B is A`).
*   **Storage vs Memory:**
    *   **Storage:** Data permanen di blockchain (seperti HDD).
    *   **Memory:** Data sementara selama eksekusi fungsi (seperti RAM).
*   **Internal & External Visibility:**
    *   **Internal:** Hanya bisa diakses di dalam kontrak dan kontrak turunannya.
    *   **External:** Hanya bisa dipanggil dari luar kontrak (seringkali lebih hemat gas).
*   **Interacting with Other Contracts (Interfaces):** Cara berkomunikasi dengan kontrak lain (misal: CryptoKitties) tanpa perlu memiliki seluruh kodenya, cukup definisikan *function header*-nya saja.
*   **Multiple Return Values:** Fungsi di Solidity bisa mengembalikan banyak nilai sekaligus, ditangkap menggunakan *tuple*.

**Contoh Kode (ZombieFeeding.sol):**
```solidity
pragma solidity >=0.5.0 <0.6.0;

import "./zombiefactory.sol";

// Interface untuk berinteraksi dengan kontrak luar
contract KittyInterface {
  function getKitty(uint256 _id) external view returns (
    bool isGestating, bool isReady, uint256 cooldownIndex, uint256 nextActionAt,
    uint256 siringWithId, uint256 birthTime, uint256 matronId, uint256 sireId,
    uint256 generation, uint256 genes
  );
}

// Inheritance dari ZombieFactory
contract ZombieFeeding is ZombieFactory {

  KittyInterface kittyContract;

  function setKittyContractAddress(address _address) external {
    kittyContract = KittyInterface(_address);
  }

  // Internal: bisa diakses oleh kontrak turunan nantinya
  function _feedAndMultiply(uint _zombieId, uint _targetDna, string memory _species) internal {
    require(msg.sender == zombieToOwner[_zombieId]);
    
    // Menggunakan pointer 'storage' untuk memodifikasi state variable
    Zombie storage myZombie = zombies[_zombieId];
    
    _targetDna = _targetDna % dnaModulus;
    uint newDna = (myZombie.dna + _targetDna) / 2;
    
    // Fitur DNA spesial jika memakan kucing
    if (keccak256(abi.encodePacked(_species)) == keccak256(abi.encodePacked("kitty"))) {
      newDna = newDna - newDna % 100 + 99;
    }
    
    _createZombie("NoName", newDna);
  }

  function feedOnKitty(uint _zombieId, uint _kittyId) public {
    uint kittyDna;
    // Mengambil nilai return ke-10 (genes) menggunakan tuple
    (,,,,,,,,,kittyDna) = kittyContract.getKitty(_kittyId);
    _feedAndMultiply(_zombieId, kittyDna, "kitty");
  }
}
```

---

## Yang dibangun minggu ini

- **Digital Signature Tool** (`signature.ts`) — Implementasi `viem` untuk sign & verify pesan secara programmatik.
- **Hex Type Guard** — Menggunakan `isHex` dari `viem` untuk memastikan validitas data secara *type-safe* di TypeScript.

---

## Statistik Beacon Chain (Live Stats Explorer)
- **Active Validators:** ~1,095,000+
- **Total ETH Staked:** ~35,000,000 ETH (±29% dari total supply)
- **Validator APR:** ~3.0% - 3.5%

---

## 3 Inovasi Utama Ethereum vs Bitcoin

1.  **Smart Contracts (Programmable Money):** Kemampuan menjalankan kode otomatis tanpa perantara (autonomous agents).
2.  **Turing-Completeness:** Bahasa pemrograman yang bisa melakukan apa pun yang bisa dilakukan komputer (termasuk loop & logika kompleks).
3.  **Unified Foundation Layer:** Satu blockchain untuk ribuan aplikasi (DeFi, DAO, NFT) agar bisa saling berinteraksi (Composability), daripada membuat blockchain baru untuk tiap aplikasi.

---

## Insight Penting
- **Private Key** hanya digunakan di langkah paling awal (untuk *Sign*). Setelah itu, jaringan hanya butuh **Public Key** untuk verifikasi. Private key tidak pernah meninggalkan *device* kita.
- **Contract Account** punya alamat (0x...) dan bisa pegang aset, tapi mereka "pasif". Mereka butuh "pelatuk" (trigger) dari manusia (EOA) untuk mulai bergerak.
