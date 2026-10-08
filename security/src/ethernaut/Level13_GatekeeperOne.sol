// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title GatekeeperOne
 * @dev Ethernaut Level 13
 * 
 * VULNERABILITY:
 * Three gates must be passed:
 * 1. Gate 1: tx.origin != msg.sender
 * 2. Gate 2: uint16(msg.sender) == 0x0000 (last 2 bytes of address are 0)
 * 3. Gate 3: gas remaining must end in 0x0000 (tricky!)
 * 
 * LESSON:
 * Type casting in Solidity can be exploited
 * Gas optimization tricks can bypass checks
 */
contract GatekeeperOne {
    address public gatekeeper;
    
    modifier gateOne() {
        require(tx.origin != msg.sender, "Gate 1 failed");
        _;
    }
    
    modifier gateTwo() {
        require(uint16(uint160(msg.sender)) == 0x0000, "Gate 2 failed");
        _;
    }
    
    modifier gateThree(uint16 _gateKey) {
        require(gasleft() % 8192 == 0, "Gate 3 failed");
        _;
    }
    
    function enter(uint16 _gateKey) public gateOne gateTwo gateThree(_gateKey) returns (bool) {
        gatekeeper = msg.sender;
        return true;
    }
    
    function getGatekeeper() external view returns (address) {
        return gatekeeper;
    }
}
