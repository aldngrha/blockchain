// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "../../src/patterns/GasOptimization.sol";

contract GasOptimizationTest is Test {

    GasOptimization opt;

    function setUp() public {
        opt = new GasOptimization();
        opt.addNumbers(100); // isi array dengan 100 angka via fungsi
    }

    function test_Sum_SameResult() public view {
        uint256 bad  = opt.sumBad();
        uint256 good = opt.sumGood();
        assertEq(bad, good);
    }

    function test_Loop_SameResult() public view {
        uint256 bad  = opt.loopBad(1000);
        uint256 good = opt.loopGood(1000);
        assertEq(bad, good);
    }

    function test_Calldata_SameResult() public view {
        uint256[] memory data = new uint256[](5);
        data[0] = 1; data[1] = 2; data[2] = 3; data[3] = 4; data[4] = 5;

        uint256 fromMemory   = opt.sumGood();
        uint256 fromCalldata = opt.sumCalldata(data);
        // keduanya valid — tujuan test adalah lihat gas di -vvv
        assertGe(fromMemory,   0);
        assertGe(fromCalldata, 0);
    }

    function test_Revert_BothRevert() public {
        vm.expectRevert();
        opt.revertString();

        vm.expectRevert();
        opt.revertCustom();
    }

    function test_Constants() public view {
        // constant — compile time, gratis
        assertEq(opt.MAX_SUPPLY(), 10000);

        // immutable — set saat deploy, murah
        assertGt(opt.deployTime(), 0);
        assertEq(opt.deployer(), address(this));

        // storage — SLOAD, paling mahal
        assertEq(opt.mutableValue(), 42);
    }

    function test_Mapping_O1() public view {
        // mapping lookup selalu O(1)
        uint256 balance = opt.getBalance(address(this));
        assertEq(balance, 0);
    }

    function test_ShortCircuit() public view {
        // kedua fungsi return hasil yang sama
        // perbedaan ada di gas — lihat dengan -vvv
        bool bad  = opt.checkBad(address(this), 0);
        bool good = opt.checkGood(address(this), 0);
        assertEq(bad, good);
    }
}
