// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Vault
 * @dev Ethernaut Level 8
 * 
 * VULNERABILITY:
 * "private" in Solidity only prevents OTHER contracts from reading
 * But ALL storage is public on blockchain!
 * 
 * Anyone can read private variables:
 * - ethers.js: await ethers.provider.getStorageAt(contractAddress, slotNumber)
 * - Foundry: vm.load(address, bytes32(slot))
 * 
 * LESSON:
 * "private" = access control at CONTRACT level, not BLOCKCHAIN level
 * Never store secrets on-chain!
 */
contract Vault {
    // This is "private" but actually readable from blockchain storage
    bytes32 private password;
    
    bool public locked;
    
    constructor(bytes32 _password) {
        password = _password;
        locked = true;
    }
    
    function unlock(bytes32 _password) external {
        if (_password == password) {
            locked = false;
        }
    }
    
    // This function is irrelevant - password is in slot 0
    function getPassword() external view returns (bytes32) {
        return password;
    }
}
