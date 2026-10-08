// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {GasOptimizationAdvanced} from "../src/GasOptimizationAdvanced.sol";

contract GasOptimizationAdvancedTest is Test {
    GasOptimizationAdvanced public gasContract;

    function setUp() public {
        gasContract = new GasOptimizationAdvanced();
    }

    // ================================================================
    // TECHNIQUE 1: Bitmap
    // ================================================================

    function test_bitmap() public {
        // Set flag 0
        gasContract.setFlag(0, true);
        assertTrue(gasContract.getFlag(0));
        assertFalse(gasContract.getFlag(1));

        // Set flag 128
        gasContract.setFlag(128, true);
        assertTrue(gasContract.getFlag(128));

        // Clear flag 0
        gasContract.setFlag(0, false);
        assertFalse(gasContract.getFlag(0));
        assertTrue(gasContract.getFlag(128)); // Still set
    }

    // ================================================================
    // TECHNIQUE 3: Short-circuit
    // ================================================================

    function test_shortCircuit() public {
        address user = makeAddr("user");

        // Empty balance — expensive check returns false
        assertFalse(gasContract.checkBad(user, 1));
        assertFalse(gasContract.checkGood(user, 1));

        // Zero amount — short-circuit skips expensive check entirely
        // checkBad still calls _expensiveCheck even if amount=0 (wasted gas)
        // checkGood skips _expensiveCheck if amount=0 (saves gas)
        assertFalse(gasContract.checkBad(user, 0));
        assertFalse(gasContract.checkGood(user, 0));
    }

    // ================================================================
    // TECHNIQUE 4: Unchecked math
    // ================================================================

    function test_uncheckedMath() public {
        gasContract.addNaif(5);
        assertEq(gasContract.numbers(0), 0);
        assertEq(gasContract.numbers(4), 4);

        gasContract.addOptimized(5);
        assertEq(gasContract.numbers(5), 0);
        assertEq(gasContract.numbers(9), 4);
    }

    // ================================================================
    // TECHNIQUE 6: Immutable vs Storage
    // ================================================================

    function test_immutableVsStorage() public {
        uint256 immutableVal = gasContract.readImmutable();
        uint256 storageVal = gasContract.readStorage();
        uint256 constantVal = gasContract.readConstant();

        // All should return their initial values
        assertEq(constantVal, 42);
        assertGt(storageVal, 0);
        assertGt(immutableVal, 0);
    }
}
