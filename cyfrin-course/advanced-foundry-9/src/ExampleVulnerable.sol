// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title ExampleVulnerable
 * @notice INTENTIONALLY VULNERABLE contract untuk security auditing practice
 * @dev Setiap fungsi punya vulnerability yang berbeda — cari dan fix semua!
 *
 * Vulnerabilities:
 * 1. withdraw() → Reentrancy
 * 2. authorize() → Missing access control
 * 3. calculateReward() → Front-running
 * 4. isDepositRecent() → Timestamp dependence
 * 5. receive() → No event emission
 */
contract ExampleVulnerable {
    mapping(address => uint256) public balances;
    uint256 public totalDeposits;
    uint256 public lastDepositTime;

    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);

    /// @notice Deposit ETH ke contract
    function deposit() external payable {
        balances[msg.sender] += msg.value;
        totalDeposits += msg.value;
        lastDepositTime = block.timestamp;
        emit Deposited(msg.sender, msg.value);
    }

    /**
     * @notice Withdraw ETH dari contract
     * @dev VULNERABILITY: Reentrancy — state updated SETELAH external call
     *      Hacker bisa re-enter withdraw() sebelum balance dikurangi
     */
    function withdraw(uint256 amount) external {
        require(balances[msg.sender] >= amount, "Insufficient balance");

        // ❌ INTERACTION sebelum EFFECTS — REENTRANCY!
        (bool success,) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");

        // ❌ STATE UPDATE terlalu telat
        balances[msg.sender] -= amount;
        totalDeposits -= amount;
        emit Withdrawn(msg.sender, amount);
    }

    /**
     * @notice Hitung reward untuk user
     * @dev VULNERABILITY: Front-running — formula bisa diprediksi
     *      Attacker bisa front-run deposit besar untuk dapet reward lebih
     */
    function calculateReward(address user) external view returns (uint256) {
        return balances[user] * 2; // ❌ Predictable = front-runnable
    }

    /**
     * @notice Cek apakah deposit masih baru
     * @dev VULNERABILITY: Timestamp dependence — miner bisa manipulasi ~15 detik
     */
    function isDepositRecent() public view returns (bool) {
        return block.timestamp - lastDepositTime < 1 hours; // ❌ Block.timestamp
    }

    /// @notice Terima ETH tanpa data
    receive() external payable {
        balances[msg.sender] += msg.value;
        totalDeposits += msg.value;
        // ❌ No event emitted — off-chain monitoring tidak bisa track
    }
}
