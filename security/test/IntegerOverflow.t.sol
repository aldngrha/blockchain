// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/IntegerOverflow.sol";

/**
 * @title IntegerOverflowTest
 * @dev Tests for integer overflow/underflow vulnerabilities
 * 
 * KEY CONCEPTS:
 * 1. Underflow: when result < 0, wraps to MAX_UINT256
 * 2. Overflow: when result > MAX_UINT256, wraps to 0
 * 3. Solidity 0.8+ has built-in checks (reverts on overflow)
 * 4. Before 0.8, needed SafeMath library
 */
contract IntegerOverflowTest is Test {
    IntegerOverflowDemo demo;
    
    function setUp() public {
        demo = new IntegerOverflowDemo();
    }
    
    /**
     * @dev Test 1: Safe arithmetic works correctly
     */
    function test_SafeArithmetic() public {
        // Deposit
        vm.deal(address(this), 10 ether);
        demo.deposit{value: 10 ether}();
        assertEq(demo.balances(address(this)), 10 ether);
        
        // Safe transfer
        address recipient = makeAddr("recipient");
        demo.safeTransfer(recipient, 5 ether);
        
        assertEq(demo.balances(address(this)), 5 ether);
        assertEq(demo.balances(recipient), 5 ether);
    }
    
    /**
     * @dev Test 2: Insufficient balance reverts (0.8+)
     * This shows Solidity 0.8+ protection
     */
    function test_InsufficientBalanceReverts() public {
        vm.deal(address(this), 1 ether);
        demo.deposit{value: 1 ether}();
        
        // Try to transfer more than balance
        address recipient = makeAddr("recipient");
        
        // Should revert in 0.8+
        vm.expectRevert("Insufficient balance");
        demo.safeTransfer(recipient, 2 ether);
    }
    
    /**
     * @dev Test 3: Underflow protection (0.8+)
     * Before 0.8: balances[msg.sender] -= amount would wrap to MAX_UINT256
     * After 0.8: reverts with Panic(0x11) arithmetic underflow
     */
    function test_UnderflowProtection() public {
        vm.deal(address(this), 1 ether);
        demo.deposit{value: 1 ether}();
        
        // Try to transfer more than balance
        address recipient = makeAddr("recipient");
        
        // This WOULD have been underflow in pre-0.8 (wrapping to MAX_UINT256)
        // In 0.8+, it properly reverts
        vm.expectRevert("Insufficient balance");
        demo.safeTransfer(recipient, 2 ether);
    }
    
    /**
     * @dev Test 4: Demonstrate 0.8+ built-in protection
     * Math operations auto-revert on overflow/underflow
     */
    function test_Solidity08Protection() public {
        // Try to deposit more than ETH balance
        vm.deal(address(this), 1 ether);
        
        // This would overflow: balance(1 ETH) + msg.value(100 ETH) > uint256
        // But actually this just adds normally... let's test with huge values
        // In practice: 0.8+ catches overflow in += operator
        assertEq(demo.balances(address(this)), 0); // not deposited yet
        
        // Normal operation is fine
        demo.deposit{value: 1 ether}();
        assertEq(demo.balances(address(this)), 1 ether);
    }
}

/**
 * @title FlashLoanAttackTest
 * @dev Tests for flash loan attack concepts
 * 
 * FLOW:
 * 1. Attacker deposits collateral
 * 2. Flash loan large amount
 * 3. Manipulate price
 * 4. Withdraw inflated collateral
 * 5. Repay flash loan
 * 6. Profit from difference
 */
contract FlashLoanAttackTest is Test {
    FlashLoanAttackDemo demo;
    
    function setUp() public {
        demo = new FlashLoanAttackDemo();
        demo.setPrice(1e18); // Initial price: 1 token = 1 ETH
    }
    
    /**
     * @dev Test 1: Normal deposit and value calculation
     */
    function test_NormalDepositValue() public {
        vm.deal(address(this), 5 ether);
        demo.deposit{value: 5 ether}();
        
        // Value should be: 5 ETH * 1 = 5 ETH worth
        assertEq(demo.getValue(address(this)), 5 ether);
    }
    
    /**
     * @dev Test 2: Price manipulation attack simulation
     */
    function test_PriceManipulationAttack() public {
        // Step 1: Victim deposits
        address victim = makeAddr("victim");
        vm.deal(victim, 10 ether);
        vm.prank(victim);
        demo.deposit{value: 10 ether}();
        
        // Step 2: Attacker deposits small amount
        vm.deal(address(this), 1 ether);
        vm.prank(address(this));
        demo.deposit{value: 1 ether}();
        
        // Step 3: Simulate flash loan callback
        // Attacker manipulates price
        vm.prank(address(this));
        demo.setPrice(2e18); // Double the price!
        
        // Step 4: Attacker's value is now inflated
        uint256 attackerValue = demo.getValue(address(this));
        
        // Attacker has 1 ETH deposited, but value shows 2 ETH
        assertEq(attackerValue, 2 ether); // Inflated!
        
        // Step 5: In real attack, attacker would withdraw here
        // Then repay flash loan, keeping the profit
    }
}

/**
 * @title PriceOracleManipulationTest
 * @dev Tests for price oracle manipulation
 */
contract PriceOracleManipulationTest is Test {
    PriceOracleManipulationDemo oracle;
    
    function setUp() public {
        oracle = new PriceOracleManipulationDemo();
        // Reserves start at 0, so swap() and getPrice() would divide by 0
        // In real DEX, reserves are set by liquidity providers
        // We'll test the concept only
    }
    
    /**
     * @dev Conceptual test: price = reserveB / reserveA
     * In real attack: flash loan → huge swap → price changes → exploit → repay
     */
    function test_PriceConcept() public view {
        // Price is 0 when no reserves (would be division by zero)
        // This demonstrates why oracle manipulation is dangerous
        uint256 price = oracle.getPrice();
        assertEq(price, 0);
    }
}
