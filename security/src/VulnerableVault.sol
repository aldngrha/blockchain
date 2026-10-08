// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title VulnerableVault
 * @notice VAULT YANG SENGAJA VULNERABLE TERHADAP REENTRANCY ATTACK
 * @dev JANGAN deploy ini ke mainnet! Ini untuk pembelajaran.
 *
 * REENTRANCY: Saat fungsi withdraw() mengirim ETH ke attacker,
 * attacker bisa "masuk lagi" ke fungsi withdraw() sebelum balance
 * dikurangi — sehingga bisa withdraw berkali-kali.
 */
contract VulnerableVault {
    mapping(address => uint256) public balances;

    // Deposit ETH ke vault
    function deposit() external payable {
        require(msg.value > 0, "Must send ETH");
        balances[msg.sender] += msg.value;
    }

    /**
     * @notice Withdraw semua ETH dari vault
     * @dev ⚠️ VULNERABLE: Balance dikurangi SETELAH transfer
     *
     * Flow normal:
     *   1. Cek balance → 1 ETH
     *   2. Kurangi balance → 0
     *   3. Transfer 1 ETH ke user
     *
     * Flow attack (reentrancy):
     *   1. Cek balance → 1 ETH ✅
     *   2. Kurangi balance → 0
     *   3. Transfer 1 ETH ke attacker
     *   4. Attacker's receive() dipanggil ⚡
     *   5. Attacker panggil withdraw() lagi
     *   6. Cek balance → 0? TIDAK! Karena baru dikurangi di step 2
     *      TAPI attacker balance BELUM dikurangi karena
     *      step 3 belum selesai完全 (CALL belum return)
     *   7. Balance attacker masih ada → withdraw lagi!
     *   8. Ulangi sampai vault kosong
     */
    function withdraw() external {
        uint256 balance = balances[msg.sender];
        require(balance > 0, "No balance");

        // ⚠️ BUG: Balance dikurangi SEBELUM transfer,
        // tapi attacker bisa re-enter SEBELUM balance update
        // Karena send() trigger receive() di attacker contract
        // dan CALL frame attacker belum selesai

        // Yang benar (checks-effects-interactions):
        // balances[msg.sender] = 0;  ← EFFECTS dulu
        // (bool success,) = msg.sender.call{value: balance}("");  ← INTERACTIONS terakhir
        // require(success);

        (bool success,) = msg.sender.call{value: balance}("");
        require(success, "Transfer failed");

        // ⚠️ TERLAMBAT: Balance dikurangi SETELAH transfer
        balances[msg.sender] = 0;
    }

    // Helper: cek balance
    function getBalance(address user) external view returns (uint256) {
        return balances[user];
    }

    // Helper: cek total ETH di vault
    function getVaultBalance() external view returns (uint256) {
        return address(this).balance;
    }

    // Accept ETH (untuk recharge vault)
    receive() external payable {}
}
