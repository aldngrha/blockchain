// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title SecureAuth
 * @notice Contract yang pakai msg.sender buat authentication — AMAN!
 * @dev msg.sender = siapa yang LANGSUNG panggil fungsi ini
 *      tx.origin = siapa yang MEMULAI transaksi pertama
 *
 * PERBEDAAN KRITIS:
 *   msg.sender:
 *     owner -> attacker's contract -> vulnerableContract.transferOwnership()
 *     msg.sender = attacker's contract (bukan owner!)
 *     → check FAILS ✅
 *
 *   tx.origin:
 *     owner -> attacker's contract -> vulnerableContract.transferOwnership()
 *     tx.origin = owner (yang approve transaksi)
 *     → check PASSES ❌ (VULNERABLE!)
 */
contract SecureAuth {
    address public owner;

    constructor() {
        owner = msg.sender;
    }

    // AMAN: pakai msg.sender buat auth
    function transferOwnership(address newOwner) external {
        require(msg.sender == owner, "Not owner!");  // ← SECURE!
        owner = newOwner;
    }

    // AMAN: withdraw juga pakai msg.sender
    function withdraw() external {
        require(msg.sender == owner, "Not owner!");  // ← SECURE!
        (bool success,) = owner.call{value: address(this).balance}("");
        require(success, "Transfer failed");
    }

    receive() external payable {}
}
