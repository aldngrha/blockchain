// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Privacy
 * @dev Ethernaut Level 12
 * 
 * VULNERABILITY:
 * "private" variables are NOT actually private on blockchain!
 * ALL storage slots are publicly readable.
 * 
 * The password is stored in a bytes32 array in slot 2.
 * Anyone can read it directly from storage.
 * 
 * STORAGE LAYOUT:
 * Slot 0: bool public locked
 * Slot 1: uint256 public ID
 * Slot 2: bytes32[3] private data  ← password is data[2]
 * Slot 3: bytes32 private key      ← this is NOT the password!
 * 
 * LESSON:
 * NEVER store secrets on blockchain
 * "private" only prevents other contracts from reading
 * But anyone can read storage directly!
 */
contract Privacy {
    bool public locked;
    uint256 public ID;
    bytes32[3] private data;
    bytes32 private key;
    
    constructor(bytes32[3] memory _data) {
        locked = true;
        ID = 1;
        data = _data;
        key = _data[0];
    }
    
    function unlock(bytes32 _key) external {
        require(_key == key, "Wrong key!");
        locked = false;
    }
    
    // Helper to see storage layout
    function getData(uint256 index) external view returns (bytes32) {
        return data[index];
    }
    
    function getKey() external view returns (bytes32) {
        return key;
    }
}
