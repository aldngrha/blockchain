// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

/**
 * @title Modifiers & Access Control
 * @dev Belajar membatasi akses fungsi (keamanan).
 */
contract Modifiers {
    address public owner;
    bool    public paused;
    uint256 public price = 0.01 ether;

    constructor() {
        // msg.sender adalah orang yang men-deploy kontrak ini
        owner = msg.sender;
    }

    // --- Custom Modifiers ---
    // Modifier adalah potongan kode yang bisa ditempelkan ke fungsi lain.
    // Simbol '_;' berarti "lanjutkan ke sisa kode fungsi".

    // HANYA owner yang boleh lewat
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner!");
        _;
    }

    // HANYA boleh jalan kalau kontrak tidak di-pause
    modifier whenNotPaused() {
        require(!paused, "Contract is paused!");
        _;
    }

    // Harus bayar sejumlah minimal ETH tertentu
    modifier costs(uint256 _price) {
        require(msg.value >= _price, "Not enough ETH!");
        _;
    }

    // --- Fungsi dengan Modifiers ---

    function pause() public onlyOwner {
        paused = true;
    }

    function unpause() public onlyOwner {
        paused = false;
    }

    // Fungsi ini punya 2 syarat: Tidak di-pause DAN harus bayar
    function doSomething() public payable whenNotPaused costs(price) {
        // Logika bisnis di sini...
    }

    function sensitiveAction() public onlyOwner whenNotPaused {
        // Aksi rahasia owner di sini...
    }

    /**
     * @dev Fungsi tarik dana dari kontrak.
     * Menggunakan pola .call{} yang aman untuk standar modern.
     */
    function withdraw() public onlyOwner {
        (bool success, ) = payable(owner).call{value: address(this).balance}("");
        require(success, "Transfer failed.");
    }
}
