// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Fallout (Ethernaut Level 2)
 * @notice Vulnerable: constructor di-misspell jadi "Fal1out"
 *
 * EXPLOIT:
 * - Cuma panggil Fal1out() → jadi owner!
 * - Karena Fal1out() bukan constructor, tapi public function
 * - Siapapun bisa panggil → dapet ownership
 */
contract Fallout {
    mapping(address => uint256) public allocations;
    address public owner;

    // ⚠️ MISSPELLED! Harusnya "Fallback" atau "constructor"
    // Karena nama != contract name, ini bukan constructor!
    // Ini public function yang bisa dipanggil siapapun
    function Fal1out() public payable {
        owner = msg.sender;
        allocations[msg.sender] = msg.value;
    }

    function allocate() public payable {
        require(msg.value > 0);
        allocations[msg.sender] += msg.value;
        if (allocations[msg.sender] > allocations[owner]) {
            owner = msg.sender;
        }
    }

    function sendAllocation(address payable addr) public {
        require(allocations[addr] > 0);
        uint256 amount = allocations[addr];
        allocations[addr] = 0;
        addr.transfer(amount);
    }

    function collectAllocations() public {
        require(msg.sender == owner);
        uint256 amount = allocations[msg.sender];
        allocations[msg.sender] = 0;
        payable(msg.sender).transfer(amount);
    }

    function allocatorBalance(address addr) public view returns (uint256) {
        return allocations[addr];
    }
}
