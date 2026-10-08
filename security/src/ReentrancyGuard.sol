// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title ReentrancyGuard
 * @notice Simple reentrancy guard — cegah re-enter pakai lock
 * @dev Ini versi sederhana. OpenZeppelin punya versi production-ready.
 *
 * Cara kerja:
 * - Setiap fungsi yang pakai nonReentrant:
 *   1. Set locked = true (kunci pintu)
 *   2. Jalankan fungsi
 *   3. Set locked = false (buka pintu)
 *
 * - Kalau attacker coba re-enter:
 *   1. locked masih true
 *   2. require gagal → REVERT
 *   3. Exploit gagal!
 */
abstract contract ReentrancyGuard {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    modifier nonReentrant() {
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }
}
