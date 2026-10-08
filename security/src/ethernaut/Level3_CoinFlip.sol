// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title CoinFlip (Ethernaut Level 3)
 * @notice Vulnerable: coin flip bisa diprediksi pakai block.timestamp
 *
 * EXPLOIT:
 * - Contract pakai block.timestamp sebagai seed random
 * - Tapi block.timestamp bisa diprediksi!
 * - Attacker tinggal hitung: block.timestamp * 57896044618658097711785492504343953926634992332820282019728792003956564819968
 * - Kalau hash = random hash → menang
 * - Ulangi 10x → solve!
 *
 * Kenapa predictable?
 * - block.timestamp = waktu block di-mine (dalam detik)
 * - Miner bisa manipulasi ±15 detik
 * - Tapi di Foundry/Corwbank: semua block = 1 timestamp
 * - Jadi sangat mudah diprediksi
 */
contract CoinFlip {
    uint256 public consecutiveWins;
    uint256 lastHash;
    uint256 FACTOR = 57896044618658097711785492504343953926634992332820282019728792003956564819968;

    function flip(bool _guess) public returns (bool) {
        uint256 blockValue = uint256(keccak256(abi.encodePacked(block.timestamp, lastHash)));
        uint256 coinFlip = blockValue / FACTOR;
        bool side = coinFlip == 1 ? true : false;

        if (side == _guess) {
            consecutiveWins++;
            if (consecutiveWins == 10) {
                consecutiveWins = 0;
                return true; // Solved!
            }
        } else {
            consecutiveWins = 0;
        }

        lastHash = blockValue;
        return false;
    }
}
