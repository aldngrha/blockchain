// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./ReentrancyGuard.sol";

/**
 * @title SecureVault
 * @notice Vault yang AMAN dari reentrancy attack
 * @dev Fixed version: pakai ReentrancyGuard + checks-effects-interactions
 *
 * 2 lapisan proteksi:
 * 1. nonReentrant modifier → cegah re-enter
 * 2. Checks-Effects-Interactions → update state SEBELUM transfer
 */
contract SecureVault is ReentrancyGuard {
    mapping(address => uint256) public balances;

    // Deposit ETH ke vault
    function deposit() external payable {
        require(msg.value > 0, "Must send ETH");
        balances[msg.sender] += msg.value;
    }

    /**
     * @notice Withdraw semua ETH — AMAN dari reentrancy
     * @dev Fixed: balance dikurangi SEBELUM transfer
     *
     * Checks-Effects-Interactions pattern:
     *   CHECKS:    require(balance > 0) — validasi
     *   EFFECTS:   balances[msg.sender] = 0 — update state
     *   INTERACTIONS: call{value} — kirim ETH
     */
    function withdraw() external nonReentrant {
        uint256 balance = balances[msg.sender];
        require(balance > 0, "No balance");

        // EFFECTS dulu: kurangi balance SEBELUM transfer
        balances[msg.sender] = 0;

        // INTERACTIONS terakhir: kirim ETH
        (bool success,) = msg.sender.call{value: balance}("");
        require(success, "Transfer failed");
    }

    // Helper
    function getBalance(address user) external view returns (uint256) {
        return balances[user];
    }

    function getVaultBalance() external view returns (uint256) {
        return address(this).balance;
    }

    receive() external payable {}
}
