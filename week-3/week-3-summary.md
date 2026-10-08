# Week 3 — Advanced Solidity: Modifiers, Inheritance, & Gas Optimization
**Tanggal:** 13–19 April 2026  
**Status:** In Progress 🚧

---

## 📘 Penjelasan Materi Lengkap

### 1. Function Modifiers: Sang "Penjaga Pintu"
Modifier adalah blok kode yang digunakan untuk mengubah perilaku fungsi secara deklaratif. Biasanya digunakan untuk menjalankan pengecekan validasi sebelum isi fungsi utama dieksekusi.

*   **Analogi:** Seperti satpam yang mengecek KTP sebelum kamu diizinkan masuk ke sebuah ruangan rahasia.
*   **Key Concept `_` (Underscore):** Simbol ini adalah instruksi khusus kepada compiler Solidity. Ia berfungsi sebagai *placeholder* yang mengatakan: "Jalankan kode di dalam fungsi utama di posisi ini." Jika diletakkan setelah `require`, maka validasi dilakukan dulu, baru fungsinya jalan.
*   **Pentingnya Modifier:** Mencegah pengulangan kode (**DRY - Don't Repeat Yourself**). Kamu hanya perlu menulis logika keamanan sekali (misal: `onlyOwner`) dan bisa menggunakannya di puluhan fungsi berbeda.

```solidity
// Contoh Modifier Dasar
modifier onlyOwner() {
    require(msg.sender == owner, "Not owner!");
    _; // Placeholder: jalankan isi fungsi utama di sini
}

// Fungsi yang menggunakan modifier
function pause() public onlyOwner {
    paused = true;
}
```

---

### 2. Inheritance: Membangun di Atas Fondasi
Inheritance (Pewarisan) memungkinkan sebuah kontrak (`child`) mengambil semua fungsi dan variabel dari kontrak lain (`parent`). Ini adalah kunci dari modularitas di Solidity.

*   **Keyword `is`:** Digunakan untuk mendeklarasikan hubungan pewarisan (contoh: `contract Dog is Animal`).
*   **Virtual & Override:** 
    *   `virtual`: Tanda di parent contract bahwa fungsi ini "boleh diubah" oleh kontrak turunannya.
    *   `override`: Tanda di child contract bahwa fungsi ini secara sengaja menggantikan fungsi milik parent.
*   **Manfaat:** Memungkinkan penggunaan library standar seperti **OpenZeppelin**. Kamu tidak perlu membuat kode keamanan dari nol; cukup *inherit* kontrak yang sudah diaudit seperti `Ownable` atau `Pausable`.

```solidity
contract Animal {
    // virtual = boleh di-override
    function speak() public virtual returns (string memory) { return "..."; }
}

contract Dog is Animal {
    // override = menggantikan fungsi parent
    function speak() public pure override returns (string memory) { return "Woof!"; }
}
```

---

### 3. Gas Optimization & Struct Packing
Setiap operasi di Ethereum memakan biaya (*Gas*). Optimasi gas adalah pembeda antara developer pemula dan senior.

*   **EVM Storage Slots:** Blockchain menyimpan data dalam slot sebesar 256-bit (32 byte). 
*   **Struct Packing:** Jika kamu meletakkan tipe data kecil (seperti `uint32`, `uint16`, `bool`) secara berurutan di dalam sebuah **Struct**, Solidity akan mencoba "mengemas" mereka ke dalam satu slot 256-bit yang sama. Ini jauh lebih murah daripada menggunakan slot baru untuk setiap variabel.
*   **Catatan Penting:** Di luar struct, Solidity selalu menggunakan slot 256-bit penuh. Jadi, menggunakan `uint8` di luar struct tidak akan menghemat gas (malah bisa lebih mahal karena butuh konversi).

```solidity
struct Optimized {
    uint32 a;  // 32 bit
    uint32 b;  // 32 bit (dikemas bersama 'a' dalam satu slot 256-bit)
    uint256 c; // 256 bit (butuh slot baru)
}

struct NotOptimized {
    uint32 a;  // Slot 1
    uint256 c; // Slot 2 (karena 'c' terlalu besar, ia butuh slot baru)
    uint32 b;  // Slot 3 (slot baru lagi, 'a' dan 'b' terpisah jauh)
}
```

---

### 4. Immutability & External Dependencies
Smart contract bersifat permanen setelah di-deploy. Ini memberikan keamanan, tapi juga tantangan jika ada kontrak eksternal yang berubah.

*   **Immutability:** Sekali kontrak berada di Mainnet, kodenya tidak bisa diubah selamanya.
*   **External Addresses:** Jangan pernah melakukan *hardcode* alamat kontrak pihak ketiga (misal: alamat CryptoKitties).
*   **Solusi:** Gunakan fungsi "setter" dengan modifier `onlyOwner` agar kamu bisa memperbarui alamat kontrak eksternal tersebut jika mereka bermigrasi ke versi baru.

```solidity
address public externalContract;

// Memungkinkan owner mengupdate alamat jika diperlukan
function setExternalAddress(address _address) external onlyOwner {
    externalContract = _address;
}
```

---

### 5. Time Units & block.timestamp
Solidity memiliki dukungan bawaan untuk satuan waktu yang sangat memudahkan logika durasi atau *cooldown*.

*   **Unit Waktu:** `seconds`, `minutes`, `hours`, `days`, `weeks`. Semuanya otomatis dikonversi ke satuan detik (uint).
*   **block.timestamp:** Memberikan waktu saat ini (Unix timestamp) dari blok yang sedang diproses.
*   **Kegunaan:** Sangat vital untuk fitur seperti periode vesting, *cooldown* serangan di game, atau durasi voting di DAO.

```solidity
uint lastUpdated;
uint cooldown = 1 days;

function update() public {
    require(block.timestamp >= lastUpdated + cooldown, "Belum waktunya!");
    lastUpdated = block.timestamp;
}
```

---

### 6. Error Handling Modern Solidity
Penanganan error yang baik menjaga dana tetap aman dan memberikan pengalaman user yang jelas.

*   **Require vs Revert:** Keduanya mengembalikan sisa gas ke user. `Require` untuk validasi sederhana, `Revert` untuk logika `if/else` yang kompleks.
*   **Assert:** Hanya untuk mengecek kondisi yang **seharusnya tidak pernah salah** (bug internal). Jika `assert` gagal, semua gas hangus sebagai "hukuman" atas adanya bug fatal.
*   **Custom Errors (`error`):** Fitur modern (Solidity 0.8.4+). Jauh lebih murah daripada string pesan error karena tidak menyimpan teks panjang di bytecode kontrak.

| Keyword | Baca State? | Ubah State? | Gas Refund? | Use Case |
|---|---|---|---|---|
| `require` | Ya | Tidak | Ya | Validasi Input |
| `revert` | Ya | Tidak | Ya | Logika Kompleks |
| `assert` | Ya | Tidak | **Tidak** | Invariant/Bug Internal |

```solidity
error NotOwner(address caller);

function mint() public {
    if (msg.sender != owner) revert NotOwner(msg.sender);
    // ... logic
}
```

---

## 🧟 CryptoZombies Deep Dive (Lesson 3-5)

### Lesson 3: Advanced Solidity Concepts
Fokus pada kontrol akses dan manajemen kontrak yang sudah dideploy.

*   **Ownable Pattern:** Menggunakan library OpenZeppelin untuk memberikan hak eksklusif kepada pembuat kontrak.
*   **Passing Structs as Arguments:** Memahami perbedaan performa antara `storage` (mengedit data asli di blockchain) dan `memory` (bekerja dengan salinan sementara).

```solidity
// Contoh Cooldown Logic & Ownable
import "./ownable.sol";

contract ZombieHelper is Ownable {
    uint cooldownTime = 1 days;

    modifier aboveLevel(uint _level, uint _zombieId) {
        require(zombies[_zombieId].level >= _level);
        _;
    }

    // Hanya owner yang bisa mengubah biaya atau alamat penting
    function setWithdrawalAddress(address _newAddress) external onlyOwner {
        withdrawalAddress = _newAddress;
    }

    function _triggerCooldown(Zombie storage _zombie) internal {
        _zombie.readyTime = uint32(block.timestamp + cooldownTime);
    }
}
```

### Lesson 4: Zombie Battle System
Menambahkan interaksi antar user, fungsi berbayar, dan keamanan angka acak.

*   **Payable Functions:** Fungsi yang ditandai `payable` dapat menerima Ether dari pengirim transaksi. Dana ini otomatis tersimpan di saldo kontrak.
*   **Withdrawal:** Pemilik kontrak harus menyediakan fungsi untuk menarik Ether yang terkumpul di kontrak agar tidak "terjebak" selamanya.
*   **Randomness (Keccak256):** Membuat angka acak semu dengan hashing. Sangat penting diingat bahwa miner bisa memanipulasi ini, jadi jangan gunakan untuk nilai taruhan tinggi.

```solidity
contract ZombieBattle is ZombieHelper {
    uint randNonce = 0;
    uint attackVictoryProbability = 70;

    // Fungsi berbayar untuk naik level instan
    function levelUp(uint _zombieId) external payable {
        require(msg.value == 0.001 ether);
        zombies[_zombieId].level++;
    }

    // Menarik saldo kontrak ke wallet owner
    function withdraw() external onlyOwner {
        address _owner = owner();
        payable(_owner).transfer(address(this).balance);
    }

    // Logika angka acak sederhana
    function randMod(uint _modulus) internal returns(uint) {
        randNonce++;
        return uint(keccak256(abi.encodePacked(block.timestamp, msg.sender, randNonce))) % _modulus;
    }
}
```

### Lesson 5: ERC721 & Crypto-collectibles
Menerapkan standar token NFT agar zombie bisa dikoleksi dan diperdagangkan.

*   **ERC721 Standard:** Menetapkan fungsi standar seperti `balanceOf`, `ownerOf`, dan `transferFrom` agar dompet digital (seperti MetaMask) atau marketplace (seperti OpenSea) bisa mengenali asetmu.
*   **SafeMath:** Library untuk mencegah bug *overflow* (angka melewati batas maksimal lalu kembali ke 0). Pada Solidity 0.8+, fitur ini sudah bawaan, namun penting untuk memahami sejarahnya.
*   **Transfer Logic:** Proses transfer biasanya melibatkan dua tahap: `approve` (pemilik mengizinkan orang lain mengambil aset) dan `transferFrom` (orang yang diizinkan mengambil aset tersebut).

```solidity
import "./safemath.sol";

contract ZombieOwnership is ZombieBattle, ERC721 {
    using SafeMath for uint256; // Mencegah overflow/underflow

    mapping (uint => address) zombieApprovals;

    function balanceOf(address _owner) public view returns (uint256 _balance) {
        return ownerZombieCount[_owner];
    }

    function ownerOf(uint256 _tokenId) public view returns (address _owner) {
        return zombieToOwner[_tokenId];
    }

    // Mekanisme persetujuan transfer (Approval)
    function approve(address _to, uint256 _tokenId) public onlyOwnerOf(_tokenId) {
        zombieApprovals[_tokenId] = _to;
        emit Approval(msg.sender, _to, _tokenId);
    }

    function transferFrom(address _from, address _to, uint256 _tokenId) external payable {
        require (zombieToOwner[_tokenId] == msg.sender || zombieApprovals[_tokenId] == msg.sender);
        _transfer(_from, _to, _tokenId);
    }
}
```

### Lesson 6: App Front-ends & Web3.js
Menghubungkan *smart contract* dengan antarmuka pengguna (Frontend) menggunakan Web3.js.

*   **Web3.js & Providers:** Perpustakaan JavaScript untuk berinteraksi dengan node Ethereum. **Providers** (seperti MetaMask atau Infura) bertindak sebagai jembatan antara browser dan jaringan blockchain.
*   **ABI & Contract Address:** Untuk berbicara dengan kontrak, frontend membutuhkan dua hal: **Alamat Kontrak** (lokasi di blockchain) dan **ABI** (Application Binary Interface - daftar fungsi dan parameternya dalam format JSON).
*   **Call vs Send:**
    *   `.call()`: Digunakan untuk fungsi `view` atau `pure`. **GRATIS**, instan, dan tidak mengubah data di blockchain.
    *   `.send()`: Digunakan untuk fungsi yang mengubah data (*state change*). Membutuhkan **GAS**, tanda tangan user (MetaMask popup), dan waktu untuk masuk ke blok.
*   **Events & Filtering:** Frontend bisa mendengarkan (*subscribe*) kejadian tertentu di blockchain (misal: `NewZombie`). Gunakan **indexed filters** untuk hanya mendengarkan kejadian yang relevan bagi user tertentu.

**Contoh Kode (index.html / app.js):**
```javascript
// 1. Inisialisasi Kontrak
var cryptoZombies;
var userAccount;

function startApp() {
  var cryptoZombiesAddress = "YOUR_CONTRACT_ADDRESS";
  cryptoZombies = new web3js.eth.Contract(cryptoZombiesABI, cryptoZombiesAddress);

  // Cek akun yang aktif di MetaMask
  var accountInterval = setInterval(function() {
    web3.eth.getAccounts().then(accounts => {
      if (accounts[0] !== userAccount) {
        userAccount = accounts[0];
        getZombiesByOwner(userAccount).then(displayZombies);
      }
    });
  }, 100;
}

// 2. Memanggil Fungsi (CALL) - GRATIS
function getZombieDetails(id) {
  return cryptoZombies.methods.zombies(id).call();
}

// 3. Memanggil Fungsi (SEND) - BAYAR GAS
function createRandomZombie(name) {
  $("#txStatus").text("Creating new zombie on the blockchain. This may take a while...");
  return cryptoZombies.methods.createRandomZombie(name)
    .send({ from: userAccount })
    .on("receipt", function(receipt) {
      $("#txStatus").text("Successfully created " + name + "!");
      getZombiesByOwner(userAccount).then(displayZombies);
    })
    .on("error", function(error) {
      $("#txStatus").text(error.message);
    });
}

// 4. Mendengarkan Event (Listen)
cryptoZombies.events.NewZombie({ filter: { _to: userAccount } })
  .on("data", function(event) {
    let zombie = event.returnValues;
    console.log("Zombiemu lahir!", zombie.name);
  });
```

---

## ✅ Checklist Minggu Ini
- [x] Paham konsep `_` di Modifier.
- [x] Bisa membedakan kapan memakai `virtual` dan `override`.
- [x] Mengerti cara menghemat gas dengan Struct Packing.
- [x] Bisa mengimplementasikan `Custom Error` untuk hemat gas.
- [x] Menyelesaikan CryptoZombies Lesson 3-5 ✓
- [x] Paham risiko manipulasi angka acak di `keccak256`.
- [x] Paham alur transfer 2-tahap (`approve` -> `transferFrom`) pada ERC721.
- [x] Menyelesaikan CryptoZombies Lesson 6 ✓
- [x] Bisa membedakan penggunaan `.call()` dan `.send()` di Frontend.
- [x] Paham cara mendengarkan *Events* dari Web3.js.

---

## 🏗️ Weekend Build: Advanced Storage System
Ini adalah proyek konsolidasi yang menggabungkan semua materi *Advanced Solidity* minggu ini ke dalam satu kontrak yang solid dan siap produksi.

### Fitur Utama Kontrak:
1.  **Complex Data Structure:** Menggunakan `Struct` di dalam `Mapping` untuk menyimpan data entri.
2.  **Double Mapping:** Melacak entri berdasarkan ID (`uint256 => Entry`) dan berdasarkan kepemilikan user (`address => uint256[]`).
3.  **Modern Error Handling:** Menggunakan `Custom Errors` untuk penghematan gas yang signifikan.
4.  **Advanced Access Control:** Menggunakan `Modifiers` untuk pengecekan kepemilikan (`onlyOwner`), pengecekan status kontrak (`whenNotPaused`), dan validasi keberadaan data (`entryExists`).
5.  **State Management:** Fitur untuk menambah, mengambil, dan menghapus (`delete`) data, serta fitur darurat untuk menghentikan fungsi kontrak (`pause`/`unpause`).

### Contoh Kode (AdvancedStorage.sol):
```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

contract AdvancedStorage {
    // ── State Variables ────────────────────────────────
    address public owner;
    bool public paused;
    uint256 public entryCount;

    struct Entry {
        uint256 id;
        string data;
        address creator;
        uint256 timestamp;
    }

    mapping(uint256 => Entry) public entries;
    mapping(address => uint256[]) public userEntries;

    event EntryCreated(uint256 indexed id, address indexed creator, string data);
    event EntryDeleted(uint256 indexed id, address indexed deletedBy);
    event ContractPaused(address indexed by);
    event ContractUnpaused(address indexed by);

    error NotOwner(address caller);
    error NotCreator(address caller, uint256 entryId);
    error ContractIsPaused();
    error EmptyData();
    error EntryNotFound(uint256 id);

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner(msg.sender);
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert ContractIsPaused();
        _;
    }

    modifier entryExists(uint256 _id) {
        if (entries[_id].creator == address(0)) revert EntryNotFound(_id);
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function createEntry(string memory _data) public whenNotPaused {
        if (bytes(_data).length == 0) revert EmptyData();
        uint256 newId = ++entryCount;
        entries[newId] = Entry({
            id: newId,
            data: _data,
            creator: msg.sender,
            timestamp: block.timestamp
        });
        userEntries[msg.sender].push(newId);
        emit EntryCreated(newId, msg.sender, _data);
    }

    function deleteEntry(uint256 _id) public entryExists(_id) {
        if (entries[_id].creator != msg.sender && msg.sender != owner) {
            revert NotCreator(msg.sender, _id);
        }
        emit EntryDeleted(_id, msg.sender);
        delete entries[_id];
    }

    function getEntry(uint256 _id) public view entryExists(_id) returns (Entry memory) {
        return entries[_id];
    }

    function getUserEntries(address _user) public view returns (uint256[] memory) {
        return userEntries[_user];
    }

    function pause() public onlyOwner {
        paused = true;
        emit ContractPaused(msg.sender);
    }

    function unpause() public onlyOwner {
        paused = false;
        emit ContractUnpaused(msg.sender);
    }
}
```

---

## 🚀 Workflow Deployment & Verification

### 1. Pre-Deployment Test (Remix VM)
Sebelum mengeluarkan gas asli di testnet, pastikan 10 skenario ini lulus di lingkungan lokal:
*   [x] Buat entri normal (Cek data & event).
*   [x] Coba entri kosong (Harus revert `EmptyData`).
*   [x] Verifikasi kepemilikan di `userEntries`.
*   [x] Pause kontrak dan pastikan fungsi tulis tertutup.
*   [x] Hapus entri oleh pemilik vs orang asing (Cek izin).

### 2. Deploy ke Sepolia Testnet
*   **Environment:** Gunakan `Injected Provider - MetaMask`.
*   **Network:** Pastikan MetaMask berada di **Sepolia Test Network**.
*   **Gas:** Pastikan memiliki Sepolia ETH dari faucet.
*   **Action:** Klik Deploy dan konfirmasi di popup MetaMask.

### 3. Verifikasi di Etherscan (Standard Industri)
Kontrak yang sudah di-deploy wajib di-verifikasi agar *source code*-nya transparan dan bisa berinteraksi langsung via Etherscan UI.
*   Buka [sepolia.etherscan.io](https://sepolia.etherscan.io).
*   Pilih **Verify and Publish**.
*   Pilih **Single File** & versi compiler yang sesuai (misal 0.8.18).
*   Paste kode sumber kontrak dan submit.
*   **Hasil:** Kontrak akan mendapatkan tanda centang hijau ✅.

---

## 🚩 Milestone Akhir Minggu 3
- [x] Berhasil menggabungkan Modifiers, Custom Errors, dan Structs dalam satu kontrak.
- [x] Berhasil melakukan deployment ke testnet publik (Sepolia).
- [x] Kontrak terverifikasi di Etherscan.
- [x] Menamatkan seluruh dasar-dasar pengembangan DApp (Solidity + Web3.js).
- [x] Implementasi 3 Kontrak Latihan Tambahan (Auction, Whitelist, Splitter).
- [x] Paham "Pull over Push" pattern & "Checks-Effects-Interactions".

---

## 🛠️ Additional Practice Contracts

### 1. Simple Auction (Lelelang Sederhana)
Kontrak lelang di mana user bisa memberikan penawaran (bid) ETH. Menggunakan pola *Pull over Push* untuk pengembalian dana bidder yang kalah.

**Test Scenarios:**
1. Deploy dengan `_durationSeconds = 3600` (1 jam).
2. Address A: `bid()` dengan 0.01 ETH → Berhasil.
3. Address B: `bid()` dengan 0.005 ETH → Revert `BidTooLow`.
4. Address B: `bid()` dengan 0.02 ETH → Berhasil, B jadi tertinggi.
5. Address A: `withdraw()` → Mendapatkan kembali 0.01 ETH.
6. `endAuction()` sebelum waktu habis → Revert `AuctionNotYetEnded`.

```solidity
// Lihat SimpleAuction.sol untuk kode lengkap
```

### 2. Whitelist Minter
Kontrak pencetakan (minting) token dengan sistem daftar putih (whitelist) dan kontrol akses (Ownable + Pausable).

**Test Scenarios:**
1. Deploy `maxSupply=100`, `mintPrice=0.01 ETH`.
2. `mint(1)` dari address non-whitelist → Revert `NotWhitelisted`.
3. `addToWhitelist(addressA)` → Berhasil.
4. `mint(1)` dari addressA (0.01 ETH) → Berhasil.
5. `pause()` oleh owner → Berhasil.
6. `mint(1)` saat paused → Revert `ContractPaused`.
7. `addBatchToWhitelist([B, C, D])` → Berhasil.

```solidity
// Lihat WhitelistMinter.sol untuk kode lengkap
```

### 3. Split Payment (Pembayaran Bagi Hasil)
Menerima ETH dan otomatis membaginya ke beberapa penerima berdasarkan persentase yang ditentukan (menggunakan basis points).

**Test Scenarios:**
1. Deploy dengan 3 address & persentase `[5000, 3000, 2000]` (50%, 30%, 20%).
2. Kirim 1 ETH ke kontrak.
3. Cek `balances[A]` → 0.5 ETH.
4. `withdraw()` dari A → Berhasil.
5. `updateSplit([A,B], [6000, 4000])` oleh owner → Berhasil.

```solidity
// Lihat SplitPayment.sol untuk kode lengkap
```

---

## 💡 Hal Penting yang Perlu Dipahami

1.  **Pull over Push Pattern:** Digunakan di `SimpleAuction` dan `SplitPayment`. Jangan langsung kirim ETH ke penerima (*push*), biarkan mereka menariknya sendiri (*pull*). Ini mencegah serangan *reentrancy* dan masalah gas limit pada loop.
2.  **Checks-Effects-Interactions:** Urutan aman dalam fungsi:
    *   **Checks:** Validasi (require/revert).
    *   **Effects:** Update state (reset balance ke 0).
    *   **Interactions:** Kirim dana atau panggil kontrak lain.
3.  **Basis Points:** Menggunakan skala 10000 untuk 100% agar bisa menangani persentase desimal (misal 12.5% = 1250 bps).
4.  **receive() function:** Fungsi khusus untuk menerima ETH yang dikirim langsung ke alamat kontrak tanpa memanggil fungsi tertentu. Tanpa ini, kiriman ETH mentah akan ditolak.
