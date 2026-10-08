// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

/**
 * @title DataTypes
 * @dev Kamus tipe data dan visibility fungsi di Solidity.
 */
contract DataTypes {
    // --- Tipe Data Dasar ---
    uint256 public bigNumber = 1000;   // Angka positif besar (256 bit)
    int256  public signedNum = -500;   // Bisa positif/negatif
    uint8   public smallNum = 255;     // Maksimal 2^8 - 1 (hemat gas untuk array kecil)
    bool    public isActive = true;    // True atau False
    address public owner = 0x1234567890123456789012345678901234567890; // Alamat dompet/kontrak
    bytes32 public data = "hello";     // Data mentah ukuran tetap (hemat gas daripada string)
    bytes   public dynamicData = "hello"; // Data mentah ukuran dinamis
    string  public name = "Aldi";      // Teks (disimpan sebagai array bytes UTF-8)

    // --- Visibility & Jenis Fungsi ---

    // public = bisa dipanggil dari dalam DAN luar kontrak
    // pure = fungsi murni, tidak baca state, tidak tulis state (cuma logika/itungan)
    function publicFunc() public pure returns (string memory) {
        return "siapapun bisa panggil ini";
    }

    // external = HANYA bisa dipanggil dari luar kontrak (lebih hemat gas untuk input besar)
    function externalFunc() external pure returns (string memory) {
        return "hanya dari luar kontrak";
    }

    // view = baca data dari blockchain (state variables) tapi tidak mengubahnya
    function getOwner() public view returns (address) {
        return owner;
    }

    function add(uint256 a, uint256 b) public pure returns (uint256) {
        return a + b;
    }

    // payable = fungsi ini BISA menerima transfer native coin (ETH/BNB/MATIC)
    function deposit() public payable {}

    // address(this).balance = mengecek berapa koin yang dimiliki kontrak ini sekarang
    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }
}
