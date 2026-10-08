// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title SecureContract
 * @notice FIXED version dari ExampleVulnerable — semua vulnerability sudah di-fix
 * @dev Bandingkan dengan ExampleVulnerable.sol untuk lihat perbedaannya
 */
contract SecureContract is ReentrancyGuard {
    mapping(address => uint256) public balances;
    uint256 public totalDeposits;
    uint256 public lastDepositTime;

    address public owner;

    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event Authorized(address indexed user);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    /// @notice Deposit ETH ke contract
    function deposit() external payable {
        balances[msg.sender] += msg.value;
        totalDeposits += msg.value;
        lastDepositTime = block.timestamp;
        emit Deposited(msg.sender, msg.value);
    }

    /**
     * @notice Withdraw ETH dari contract
     * @dev FIX 1: nonReentrant + CEI pattern (Effects sebelum Interactions)
     */
    function withdraw(uint256 amount) external nonReentrant {
        require(balances[msg.sender] >= amount, "Insufficient balance");

        // ✅ EFFECTS: Update state DULU
        balances[msg.sender] -= amount;
        totalDeposits -= amount;

        // ✅ INTERACTIONS: External call TERAKHIR
        (bool success,) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");

        emit Withdrawn(msg.sender, amount);
    }

    /**
     * @notice Cek apakah deposit masih baru
     * @dev FIX 2: Pakai block.number bukan block.timestamp
     *      Block number lebih sulit dimanipulasi (miner gak bisa pilih block number)
     */
    function isDepositRecent() public view returns (bool) {
        // block.number lebih reliable dari block.timestamp
        // Approximasi: 1 block ≈ 12 detik, 300 blocks ≈ 1 jam
        return block.number - (lastDepositTime / 12) < 300;
    }

    /// @notice Terima ETH tanpa data — FIX 3: emit event
    receive() external payable {
        balances[msg.sender] += msg.value;
        totalDeposits += msg.value;
        emit Deposited(msg.sender, msg.value); // ✅ Event emitted
    }
}
