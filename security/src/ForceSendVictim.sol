// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title ForceSendVictim
 * @notice Contract yang RUSAK karena force-send ETH
 *
 * MASALAH:
 *   totalDeposited dipakai buat track berapa ETH yang di-deposit
 *   Tapi attacker bisa force-send ETH ke contract ini
 *   → address(this).balance > totalDeposited
 *   → ETH "tiba-tiba muncul" tanpa deposit
 *   → Kalau withdraw pakai balance, owner bisa withdraw lebih dari deposit
 *   → Kalau withdraw pakai totalDeposited, ETH bisa stuck di contract
 */
contract ForceSendVictim {
    address public owner;
    mapping(address => uint256) public deposits;
    uint256 public totalDeposited;

    constructor() {
        owner = msg.sender;
    }

    // Deposit normal
    function deposit() external payable {
        require(msg.value > 0, "Must send ETH");
        deposits[msg.sender] += msg.value;
        totalDeposited += msg.value;
    }

    // Withdraw — pakai balance (TAPI BALANCE BISA DIMANIPULASI!)
    function withdraw() external {
        uint256 amount = deposits[msg.sender];
        require(amount > 0, "No deposit");

        deposits[msg.sender] = 0;
        totalDeposited -= amount;

        (bool success,) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");
    }

    // Helper: cek apakah balance == totalDeposited
    // Kalau gak sama → ada force-send!
    function isBalanceConsistent() external view returns (bool) {
        return address(this).balance == totalDeposited;
    }

    // Helper: get balances
    function getBalances() external view returns (uint256 balance, uint256 deposited) {
        balance = address(this).balance;
        deposited = totalDeposited;
    }

    receive() external payable {}
}
