// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title VulnerableAuth
 * @notice Contract yang pakai tx.origin buat authentication — VULNERABLE!
 * @dev JANGAN deploy ini ke mainnet!
 *
 * MASALAH:
 *   msg.sender = siapa yang LANGSUNG panggil fungsi ini (bisa contract)
 *   tx.origin = siapa yang MEMULAI transaksi pertama (selalu EOA/wallet)
 *
 *   Kalau attacker bikin contract berbahaya, dan owner ACCIDENTALLY
 *   panggil contract itu (misal klik link phising), maka:
 *   → tx.origin = owner (karena owner mulai transaksi)
 *   → msg.sender = attacker's contract
 *   → attacker's contract panggil transferOwnership()
 *   → Karena tx.origin == owner, check PASS!
 *   → Ownership BERHASIL diambil!
 */
contract VulnerableAuth {
    address public owner;

    constructor() {
        owner = msg.sender;
    }

    // ⚠️ VULNERABLE: pakai tx.origin buat auth
    function transferOwnership(address newOwner) external {
        require(tx.origin == owner, "Not owner!");  // ← BUG!
        owner = newOwner;
    }

    // ⚠️ VULNERABLE: withdraw juga pakai tx.origin
    function withdraw() external {
        require(tx.origin == owner, "Not owner!");  // ← BUG!
        (bool success,) = owner.call{value: address(this).balance}("");
        require(success, "Transfer failed");
    }

    // Accept ETH
    receive() external payable {}
}
