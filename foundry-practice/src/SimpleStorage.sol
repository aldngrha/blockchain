// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

/**
 * @title SimpleStorage
 * @dev Kontrak paling dasar untuk belajar menyimpan dan mengambil data.
 * Fokus: State variables, Events, dan Fungsi dasar.
 */
contract SimpleStorage {
    // uint256 = unsigned integer 256 bit (angka bulat positif saja)
    // private = variabel ini hanya bisa dibaca oleh kode di dalam kontrak ini.
    uint256 private storedNumber;

    // Event = cara kontrak "berteriak" ke dunia luar (frontend/DApp).
    // Sangat berguna untuk tracking perubahan data tanpa harus polling saldo/status.
    event NumberUpdated(uint256 oldNumber, uint256 newNumber);

    /**
     * @dev Menyimpan angka ke blockchain.
     * Mengubah state = memakan biaya Gas.
     */
    function store(uint256 _number) public {
        emit NumberUpdated(storedNumber, _number); // Emit event sebelum data berubah
        storedNumber = _number; // Simpan ke variabel state
    }

    /**
     * @dev Mengambil angka dari blockchain.
     * view = fungsi ini cuma baca data, TIDAK mengubah apapun (Gratis jika dipanggil dari luar).
     * returns (uint256) = tipe data yang dikembalikan fungsi ini.
     */
    function retrieve() public view returns (uint256) {
        return storedNumber;
    }
}
