// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Telephone (Ethernaut Level 4)
 * @notice Vulnerable: ganti owner pakai tx.origin check
 *
 * EXPLOIT:
 * - changeOwner() check: tx.origin != msg.sender
 * - Attacker deploy contract → panggil changeOwner(attacker)
 * - Di dalam attacker contract:
 *   msg.sender = attacker contract
 *   tx.origin = attacker EOA
 *   → tx.origin != msg.sender → check PASS!
 * - Owner berubah jadi attacker!
 */
contract Telephone {
    address public owner;

    constructor() {
        owner = msg.sender;
    }

    function changeOwner(address _newOwner) public {
        if (tx.origin != msg.sender) {
            owner = _newOwner;
        }
    }
}
