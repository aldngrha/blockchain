// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Fallback (Ethernaut Level 1)
 * @notice Vulnerable contract: owner bisa dicuri lewat receive()
 *
 * LOGIC:
 * - contribute() → tambah contribution (harus <0.01 ETH)
 * - receive() → kalau msg.value > 0 && < contribution → jadi owner
 * - withdraw() → hanya owner yang bisa tarik semua ETH
 *
 * EXPLOIT:
 * 1. contribute 0.001 ETH → contribution = 0.001 ETH
 * 2. Kirim ETH langsung (via call) → receive() dipanggil
 *    → msg.value > 0 && msg.value < contribution(0.001) → owner = attacker!
 */
contract Fallback {
    mapping(address => uint256) public contributions;
    address public owner;

    constructor() {
        owner = msg.sender;
        contributions[msg.sender] = 1000 * (1 ether);
    }

    function contribute() public payable {
        require(msg.value < 0.01 ether);
        contributions[msg.sender] += msg.value;
        if (contributions[msg.sender] > contributions[owner]) {
            owner = msg.sender;
        }
    }

    function getContribution() public view returns (uint256) {
        return contributions[msg.sender];
    }

    function withdraw() public {
        require(msg.sender == owner);
        payable(owner).transfer(address(this).balance);
    }

    receive() external payable {
        require(msg.value > 0 && msg.value < contributions[msg.sender]);
        owner = msg.sender;
    }
}
