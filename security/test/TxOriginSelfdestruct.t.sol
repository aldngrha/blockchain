// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/VulnerableAuth.sol";
import "../src/PhishingAttacker.sol";
import "../src/SecureAuth.sol";
import "../src/ForceSend.sol";
import "../src/ForceSendVictim.sol";

/**
 * @title TxOriginSelfdestructTest
 * @notice Tests for tx.origin phishing + selfdestruct force-send
 *
 * KEY INSIGHT:
 *   tx.origin = Foundry runner EOA (0x1804...)
 *   Deploy VulnAuth from tx.origin => owner = tx.origin
 *   Phishing transfers ownership to attacker EOA (not phishing contract)
 *   Because PhishingAttacker.attacker = msg.sender = attacker EOA
 */
contract TxOriginSelfdestructTest is Test {
    VulnerableAuth public vulnAuth;
    SecureAuth public secureAuth;
    ForceSend public forceSend;
    ForceSendVictim public victim;

    address attacker = makeAddr("attacker");
    address user = makeAddr("user");

    function setUp() public {
        // Deploy VulnAuth from tx.origin => owner = tx.origin
        vm.prank(tx.origin);
        vulnAuth = new VulnerableAuth();
        vm.deal(address(vulnAuth), 5 ether);

        // Deploy SecureAuth from tx.origin => owner = tx.origin
        vm.prank(tx.origin);
        secureAuth = new SecureAuth();
        vm.deal(address(secureAuth), 5 ether);

        forceSend = new ForceSend();
        victim = new ForceSendVictim();
    }

    // ==========================================
    // TEST 1: tx.origin PHISHING — ownership stolen
    // ==========================================

    function test_TxOriginPhishing() public {
        console.log("=== SETUP ===");
        console.log("VulnAuth owner:     %s", vulnAuth.owner());
        console.log("tx.origin:          %s", tx.origin);
        console.log("Attacker EOA:       %s", attacker);
        console.log("Owner == tx.origin:  %s", vulnAuth.owner() == tx.origin);

        // Deploy phishing attacker from attacker address
        vm.prank(attacker);
        PhishingAttacker phishingAttacker = new PhishingAttacker(address(vulnAuth));

        console.log("\n=== BEFORE PHISHING ===");
        console.log("VulnAuth balance:   %s ETH", address(vulnAuth).balance / 1e18);

        // Owner (tx.origin) calls claimFreeTokens (phishing link)
        // Inside: phishingAttacker calls vulnAuth.transferOwnership(attacker)
        // tx.origin = tx.origin (runner EOA = owner) => check PASSES
        phishingAttacker.claimFreeTokens();

        console.log("\n=== AFTER PHISHING ===");
        console.log("VulnAuth owner:     %s", vulnAuth.owner());
        console.log("Attacker EOA:       %s", attacker);

        // Ownership transferred to attacker EOA (not phishing contract)
        assertEq(vulnAuth.owner(), attacker, "Ownership should go to attacker EOA!");

        // Verify the owner is NO LONGER tx.origin
        assertTrue(vulnAuth.owner() != tx.origin, "Original owner lost ownership!");

        console.log("[!!] PHISHING BERHASIL! Ownership jatuh ke attacker!");
        console.log("     Original owner gak sadar udah lose control!");
    }

    // ==========================================
    // TEST 2: SECURE AUTH — phishing GAGAL
    // ==========================================

    function test_SecureAuthBlocksPhishing() public {
        // SecureAuth deployed from tx.origin => owner = tx.origin
        console.log("=== SETUP ===");
        console.log("SecureAuth owner:   %s", secureAuth.owner());
        console.log("tx.origin:          %s", tx.origin);

        vm.prank(attacker);
        PhishingAttacker securePhisher = new PhishingAttacker(address(secureAuth));

        console.log("\n=== PHISHING ATTEMPT ===");
        // Owner (tx.origin) calls claimFreeTokens
        // Inside: securePhisher calls secureAuth.transferOwnership(attacker)
        // msg.sender = phishingContract != owner => REVERT (expected!)
        vm.expectRevert("Not owner!");
        securePhisher.claimFreeTokens();

        // Owner unchanged because msg.sender != owner
        assertEq(secureAuth.owner(), tx.origin, "Owner unchanged!");
        assertEq(address(secureAuth).balance, 5 ether, "ETH safe!");

        console.log("SecureAuth owner:   %s", secureAuth.owner());
        console.log("[OK] PHISHING GAGAL! msg.sender check blocks attack!");
    }

    // ==========================================
    // TEST 3: SELFDSTRUCT FORCE-SEND — balance manipulated
    // ==========================================

    function test_SelfdestructForceSend() public {
        vm.deal(user, 3 ether);
        vm.prank(user);
        victim.deposit{value: 3 ether}();

        console.log("=== BEFORE FORCE-SEND ===");
        (uint256 bal, uint256 dep) = victim.getBalances();
        console.log("Balance:     %s ETH", bal / 1e18);
        console.log("Deposited:   %s ETH", dep / 1e18);
        console.log("Consistent:  %s", victim.isBalanceConsistent());

        vm.deal(attacker, 2 ether);
        vm.prank(attacker);
        forceSend.attack{value: 2 ether}(payable(address(victim)));

        console.log("\n=== AFTER FORCE-SEND ===");
        (uint256 bal2, uint256 dep2) = victim.getBalances();
        console.log("Balance:     %s ETH", bal2 / 1e18);
        console.log("Deposited:   %s ETH", dep2 / 1e18);
        console.log("Consistent:  %s", victim.isBalanceConsistent());

        assertEq(bal2, 5 ether, "Balance = 3+2 ETH!");
        assertEq(dep2, 3 ether, "Deposited unchanged!");
        assertFalse(victim.isBalanceConsistent(), "INCONSISTENT!");

        console.log("[!!] FORCE-SEND BERHASIL! 2 ETH stuck!");
        console.log("     Contract bisa balance != deposit!");
    }

    // ==========================================
    // TEST 4: Normal operations still work
    // ==========================================

    function test_NormalOperationsWork() public {
        vm.deal(user, 3 ether);
        vm.prank(user);
        victim.deposit{value: 3 ether}();

        vm.prank(user);
        victim.withdraw();

        assertEq(address(victim).balance, 0, "Victim empty!");
        assertEq(user.balance, 3 ether, "User got 3 ETH back!");
        console.log("[OK] Normal deposit/withdraw works!");
    }
}
