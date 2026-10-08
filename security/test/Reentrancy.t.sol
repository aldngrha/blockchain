// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/VulnerableVault.sol";
import "../src/Attacker.sol";
import "../src/SecureVault.sol";

/**
 * @title ReentrancyTest
 * @notice Test yang DEMO reentrancy attack + fix
 *
 * Flow test:
 * 1. Deploy VulnerableVault + isi 10 ETH
 * 2. Deploy Attacker -> exploit vault (deposit 5 ETH, drain all)
 * 3. Buktikan vault kosong, attacker dapet semua ETH
 * 4. Deploy SecureVault + isi 10 ETH
 * 5. Coba exploit -> GAGAL (reverted)
 */
contract ReentrancyTest is Test {
    VulnerableVault public vulnerableVault;
    SecureVault public secureVault;
    Attacker public attacker;

    address alice = makeAddr("alice");
    address deployer = makeAddr("deployer");

    function setUp() public {
        // Deploy vulnerable vault
        vulnerableVault = new VulnerableVault();

        // Alice deposit 10 ETH (victim)
        vm.deal(alice, 10 ether);
        vm.prank(alice);
        vulnerableVault.deposit{value: 10 ether}();

        // Deploy attacker contract
        vm.prank(deployer);
        attacker = new Attacker(payable(address(vulnerableVault)));

        // Deploy secure vault
        secureVault = new SecureVault();

        // Alice deposit 10 ETH ke secure vault
        vm.deal(alice, 10 ether);
        vm.prank(alice);
        secureVault.deposit{value: 10 ether}();
    }

    // ==========================================
    // TEST 1: REENTRANCY EXPLOIT — vault KOSONG
    // ==========================================

    function test_ReentrancyExploit() public {
        uint256 vaultBefore = vulnerableVault.getVaultBalance();
        uint256 attackerBefore = address(attacker).balance;

        console.log("=== BEFORE EXPLOIT ===");
        console.log("Vault balance:     %s ETH", vaultBefore / 1e18);
        console.log("Attacker balance:  %s ETH", attackerBefore / 1e18);

        // Attacker mulai exploit!
        // Send 5 ETH ke vault, withdraw berkali-kali sampai habis
        vm.deal(deployer, 5 ether);
        vm.prank(deployer);
        attacker.attack{value: 5 ether}();

        uint256 vaultAfter = vulnerableVault.getVaultBalance();
        uint256 attackerContractBalance = address(attacker).balance;
        uint256 attackCount = attacker.getAttackCount();

        console.log("\n=== AFTER EXPLOIT ===");
        console.log("Vault balance:     %s ETH", vaultAfter / 1e18);
        console.log("Attacker balance:  %s ETH", attackerContractBalance / 1e18);
        console.log("Re-enter count:    %s times", attackCount);

        // Vault harus KOSONG
        assertEq(vaultAfter, 0, "Vault should be empty after exploit!");

        // Attacker dapet semua ETH (10 dari alice + 5 sendiri = 15, minus gas)
        assertGt(attackerContractBalance, 10 ether, "Attacker should have drained victim ETH!");

        console.log("\n[!!] EXPLOIT BERHASIL! Vault dikuras habis!");
    }

    // ==========================================
    // TEST 2: SECURE VAULT — exploit GAGAL
    // ==========================================

    function test_SecureVaultBlocksReentrancy() public {
        // Deploy attacker baru, target secure vault
        vm.startPrank(deployer);
        Attacker secureAttacker = new Attacker(payable(address(secureVault)));

        // Send 5 ETH buat gas
        vm.deal(deployer, 5 ether);

        // Coba exploit -> harusnya REVERT
        // Error dari require(success) di vault, karena reentrancy revert di-call stack
        vm.expectRevert();
        secureAttacker.attack{value: 5 ether}();
        vm.stopPrank();

        // Vault tetap utuh!
        uint256 vaultBalance = secureVault.getVaultBalance();
        console.log("\n=== SECURE VAULT ===");
        console.log("Vault balance: %s ETH", vaultBalance / 1e18);

        assertEq(vaultBalance, 10 ether, "Secure vault should still have all ETH!");
        console.log("[OK] EXPLOIT GAGAL! Vault tetap aman!");
    }

    // ==========================================
    // TEST 3: Normal withdraw — tetap berfungsi
    // ==========================================

    function test_NormalWithdrawWorks() public {
        // Alice withdraw normal dari secure vault
        vm.prank(alice);
        secureVault.withdraw();

        uint256 aliceBalance = address(alice).balance;
        uint256 vaultBalance = secureVault.getVaultBalance();

        console.log("\n=== NORMAL WITHDRAW ===");
        console.log("Alice balance: %s ETH", aliceBalance / 1e18);
        console.log("Vault balance: %s ETH", vaultBalance / 1e18);

        // Alice dapet 10 ETH balik
        assertEq(aliceBalance, 10 ether, "Alice should get 10 ETH back!");
        assertEq(vaultBalance, 0, "Vault should be empty after normal withdraw!");
        console.log("[OK] Normal withdraw berfungsi!");
    }

    // ==========================================
    // TEST 4: Multiple users — fair withdrawal
    // ==========================================

    function test_MultipleUsersWithdraw() public {
        address bob = makeAddr("bob");

        // Bob deposit 5 ETH
        vm.deal(bob, 5 ether);
        vm.prank(bob);
        secureVault.deposit{value: 5 ether}();

        uint256 vaultBalance = secureVault.getVaultBalance();
        console.log("\n=== MULTI-USER ===");
        console.log("Vault total: %s ETH", vaultBalance / 1e18);

        // Alice withdraw 10 ETH
        vm.prank(alice);
        secureVault.withdraw();

        // Bob withdraw 5 ETH
        vm.prank(bob);
        secureVault.withdraw();

        assertEq(secureVault.getVaultBalance(), 0, "Vault should be empty!");
        console.log("[OK] Both users withdrawn fairly!");
    }
}
