// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {Box} from "../src/Box.sol";
import {BoxV2} from "../src/BoxV2.sol";
import {BadBox} from "../src/BadBox.sol";
import {SimpleProxy} from "../src/SimpleProxy.sol";

/// @title UpgradeTest
/// @notice Tests for proxy upgrade pattern, storage layout, and delegatecall
contract UpgradeTest is Test {
    Box public box;
    BoxV2 public boxV2;
    BadBox public badBox;
    SimpleProxy public proxy;

    address admin;

    event ValueChanged(uint256 indexed oldValue, uint256 indexed newValue);
    event Incremented(uint256 indexed newValue);
    event Upgraded(address indexed oldImpl, address indexed newImpl);

    function setUp() public {
        admin = makeAddr("admin");

        // Deploy Box v1 implementation
        box = new Box();

        // Deploy proxy as admin so admin = proxy.getAdmin()
        vm.startPrank(admin);
        proxy = new SimpleProxy(address(box));
        vm.stopPrank();
    }

    // =====================================================
    // SECTION 1: Storage Layout — Why It Matters
    // =====================================================

    function test_storageLayout_boxV1() public {
        Box b = new Box();
        vm.prank(admin);
        b.initialize(42);

        assertEq(b.getValue(), 42);
        assertEq(b.getOwner(), admin);
    }

    function test_storageLayout_boxV2_matchesV1() public {
        // BoxV2 MUST have same first 2 slots as Box when used behind proxy
        // slot 0: s_value (uint256) — same as Box
        // slot 1: s_owner (address) — same as Box
        // slot 2: s_initialized (bool) — NEW, at the end
        //
        // Initialize v1 via proxy, upgrade to v2, verify state is preserved
        vm.prank(admin);
        (bool ok1, ) = address(proxy).call(
            abi.encodeWithSelector(Box.initialize.selector, uint256(42))
        );
        assertTrue(ok1);

        // Verify v1 reads correctly
        (bool ok2, bytes memory ret1) = address(proxy).call(
            abi.encodeWithSelector(Box.getValue.selector)
        );
        assertTrue(ok2);
        assertEq(abi.decode(ret1, (uint256)), 42);

        // Upgrade to v2
        boxV2 = new BoxV2();
        vm.prank(admin);
        proxy.upgradeTo(address(boxV2));

        // v2 should read the SAME value — proving layout compatibility
        (bool ok3, bytes memory ret2) = address(proxy).call(
            abi.encodeWithSelector(BoxV2.getValue.selector)
        );
        assertTrue(ok3);
        assertEq(abi.decode(ret2, (uint256)), 42);
    }

    function test_storageLayout_badBox_collision() public {
        // BadBox has REORDERED storage — this causes collision!
        badBox = new BadBox();

        // Initialize Box v1 via proxy: s_value=100, s_owner=admin
        vm.prank(admin);
        (bool ok1, ) = address(proxy).call(
            abi.encodeWithSelector(Box.initialize.selector, uint256(100))
        );
        assertTrue(ok1);

        // Verify Box v1 works correctly through proxy
        (bool ok2, bytes memory ret1) = address(proxy).call(
            abi.encodeWithSelector(Box.getValue.selector)
        );
        assertTrue(ok2);
        assertEq(abi.decode(ret1, (uint256)), 100);

        (bool ok3, bytes memory ret2) = address(proxy).call(
            abi.encodeWithSelector(Box.getOwner.selector)
        );
        assertTrue(ok3);
        assertEq(abi.decode(ret2, (address)), admin);

        // Now upgrade to BadBox — storage collision!
        vm.prank(admin);
        proxy.upgradeTo(address(badBox));

        // BadBox thinks slot 0 = s_owner (address), but Box stored s_value=100 here
        // So BadBox.reads s_owner as address(100) — CORRUPTED!
        (bool ok4, bytes memory ret3) = address(proxy).call(
            abi.encodeWithSelector(BadBox.getOwner.selector)
        );
        assertTrue(ok4);
        address corruptedOwner = abi.decode(ret3, (address));
        console.log("Real admin:", admin);
        console.log("Corrupted admin:", corruptedOwner);
        assertTrue(corruptedOwner != admin);
    }

    // =====================================================
    // SECTION 2: Basic Proxy — Delegatecall
    // =====================================================

    function test_proxy_basicDelegatecall() public {
        boxV2 = new BoxV2();

        // Initialize Box v1 first (sets s_owner via proxy)
        vm.prank(admin);
        (bool ok0, ) = address(proxy).call(
            abi.encodeWithSelector(Box.initialize.selector, uint256(42))
        );
        assertTrue(ok0);

        // Upgrade proxy to v2
        vm.prank(admin);
        proxy.upgradeTo(address(boxV2));

        // Read through proxy — should return 42
        (bool ok2, bytes memory ret) = address(proxy).call(
            abi.encodeWithSelector(BoxV2.getValue.selector)
        );
        assertTrue(ok2);
        assertEq(abi.decode(ret, (uint256)), 42);
    }

    function test_proxy_preservesState() public {
        boxV2 = new BoxV2();

        // Initialize Box v1 via proxy
        vm.prank(admin);
        (bool ok1, ) = address(proxy).call(
            abi.encodeWithSelector(Box.initialize.selector, uint256(100))
        );
        assertTrue(ok1);

        // Read value via proxy
        (bool ok2, bytes memory ret) = address(proxy).call(
            abi.encodeWithSelector(Box.getValue.selector)
        );
        assertTrue(ok2);
        assertEq(abi.decode(ret, (uint256)), 100);

        // Upgrade to v2
        vm.prank(admin);
        proxy.upgradeTo(address(boxV2));

        // Value should be PRESERVED after upgrade
        (bool ok3, bytes memory ret2) = address(proxy).call(
            abi.encodeWithSelector(BoxV2.getValue.selector)
        );
        assertTrue(ok3);
        assertEq(abi.decode(ret2, (uint256)), 100);
    }

    function test_proxy_newFunctionAfterUpgrade() public {
        boxV2 = new BoxV2();

        // Initialize Box v1
        vm.prank(admin);
        (bool ok1, ) = address(proxy).call(
            abi.encodeWithSelector(Box.initialize.selector, uint256(10))
        );
        assertTrue(ok1);

        // increment() doesn't exist in v1 — would revert via delegatecall
        vm.prank(admin);
        (bool ok2, ) = address(proxy).call(
            abi.encodeWithSelector(BoxV2.increment.selector)
        );
        assertFalse(ok2);

        // Upgrade to v2
        vm.prank(admin);
        proxy.upgradeTo(address(boxV2));

        // NOW increment() works!
        vm.prank(admin);
        (bool ok3, ) = address(proxy).call(
            abi.encodeWithSelector(BoxV2.increment.selector)
        );
        assertTrue(ok3);

        // Value should be 11 (10 + 1)
        (bool ok4, bytes memory ret) = address(proxy).call(
            abi.encodeWithSelector(BoxV2.getValue.selector)
        );
        assertTrue(ok4);
        assertEq(abi.decode(ret, (uint256)), 11);
    }

    function test_proxy_multipleIncrements() public {
        boxV2 = new BoxV2();

        vm.prank(admin);
        (bool ok1, ) = address(proxy).call(
            abi.encodeWithSelector(Box.initialize.selector, uint256(5))
        );
        assertTrue(ok1);

        vm.prank(admin);
        proxy.upgradeTo(address(boxV2));

        // Increment 3 times
        for (uint256 i = 0; i < 3; i++) {
            vm.prank(admin);
            (bool okInc, ) = address(proxy).call(
                abi.encodeWithSelector(BoxV2.increment.selector)
            );
            assertTrue(okInc);
        }

        (bool ok, bytes memory ret) = address(proxy).call(
            abi.encodeWithSelector(BoxV2.getValue.selector)
        );
        assertTrue(ok);
        assertEq(abi.decode(ret, (uint256)), 8); // 5 + 3
    }

    // =====================================================
    // SECTION 3: Access Control — Only Admin Can Upgrade
    // =====================================================

    function test_proxy_onlyAdminCanUpgrade() public {
        address user = makeAddr("user");
        boxV2 = new BoxV2();
        vm.prank(user);
        vm.expectRevert(SimpleProxy.SimpleProxy__NotAdmin.selector);
        proxy.upgradeTo(address(boxV2));
    }

    function test_proxy_onlyAdminCanSetValues() public {
        address user = makeAddr("user");

        vm.prank(admin);
        (bool ok, ) = address(proxy).call(
            abi.encodeWithSelector(Box.initialize.selector, uint256(42))
        );
        assertTrue(ok);

        // User tries to set value — should revert
        vm.prank(user);
        (bool ok2, ) = address(proxy).call(
            abi.encodeWithSelector(Box.setValue.selector, uint256(99))
        );
        assertFalse(ok2);
    }

    function test_proxy_upgradeEmitsEvent() public {
        address newImpl = makeAddr("newImpl");

        vm.prank(admin);
        vm.expectEmit(true, true, false, true);
        emit Upgraded(address(box), newImpl);
        proxy.upgradeTo(newImpl);
    }

    // =====================================================
    // SECTION 4: Storage Collision Deep Dive
    // =====================================================

    function test_storageCollision_demonstrate() public {
        badBox = new BadBox();

        // Step 1: Deploy proxy with Box v1 (as admin so admin matches)
        vm.startPrank(admin);
        SimpleProxy testProxy = new SimpleProxy(address(box));
        vm.stopPrank();

        // Step 2: Initialize Box v1 through proxy
        vm.prank(admin);
        (bool ok1, ) = address(testProxy).call(
            abi.encodeWithSelector(Box.initialize.selector, uint256(999))
        );
        assertTrue(ok1);

        // Verify: proxy reads Box v1 correctly
        (bool ok2, bytes memory ret1) = address(testProxy).call(
            abi.encodeWithSelector(Box.getValue.selector)
        );
        assertTrue(ok2);
        assertEq(abi.decode(ret1, (uint256)), 999);

        (bool ok3, bytes memory ret2) = address(testProxy).call(
            abi.encodeWithSelector(Box.getOwner.selector)
        );
        assertTrue(ok3);
        assertEq(abi.decode(ret2, (address)), admin);

        // Step 3: Upgrade to BadBox (WRONG layout!)
        vm.prank(admin);
        testProxy.upgradeTo(address(badBox));

        // Step 4: Read through BadBox — CORRUPTED!
        // BadBox slot 0 = s_owner (address), but Box stored s_value=999 here
        (bool ok4, bytes memory ret3) = address(testProxy).call(
            abi.encodeWithSelector(BadBox.getOwner.selector)
        );
        assertTrue(ok4);
        address corrupted = abi.decode(ret3, (address));
        console.log("Real admin:", admin);
        console.log("Corrupted admin:", corrupted);
        assertTrue(corrupted != admin);

        // BadBox slot 1 = s_value (uint256), but Box stored s_owner here
        (bool ok5, bytes memory ret4) = address(testProxy).call(
            abi.encodeWithSelector(BadBox.getValue.selector)
        );
        assertTrue(ok5);
        uint256 corruptedValue = abi.decode(ret4, (uint256));
        console.log("Corrupted value:", corruptedValue);
    }

    // =====================================================
    // SECTION 5: Upgrade State Preservation
    // =====================================================

    function test_upgrade_preservesOwner() public {
        vm.prank(admin);
        (bool ok1, ) = address(proxy).call(
            abi.encodeWithSelector(Box.initialize.selector, uint256(1))
        );
        assertTrue(ok1);

        (bool ok2, bytes memory ret) = address(proxy).call(
            abi.encodeWithSelector(Box.getOwner.selector)
        );
        assertTrue(ok2);
        assertEq(abi.decode(ret, (address)), admin);

        // Upgrade to v2
        boxV2 = new BoxV2();
        vm.prank(admin);
        proxy.upgradeTo(address(boxV2));

        // Owner should be PRESERVED
        (bool ok3, bytes memory ret2) = address(proxy).call(
            abi.encodeWithSelector(BoxV2.getOwner.selector)
        );
        assertTrue(ok3);
        assertEq(abi.decode(ret2, (address)), admin);
    }

    function test_upgrade_multipleUpgrades() public {
        vm.prank(admin);
        (bool ok1, ) = address(proxy).call(
            abi.encodeWithSelector(Box.initialize.selector, uint256(10))
        );
        assertTrue(ok1);

        boxV2 = new BoxV2();
        vm.prank(admin);
        proxy.upgradeTo(address(boxV2));

        // Increment (v2 feature)
        vm.prank(admin);
        (bool ok2, ) = address(proxy).call(
            abi.encodeWithSelector(BoxV2.increment.selector)
        );
        assertTrue(ok2);

        // Verify: value should be 11
        (bool ok3, bytes memory ret) = address(proxy).call(
            abi.encodeWithSelector(BoxV2.getValue.selector)
        );
        assertTrue(ok3);
        assertEq(abi.decode(ret, (uint256)), 11);
    }

    // =====================================================
    // SECTION 6: Edge Cases
    // =====================================================

    function test_proxy_reInitializePrevents() public {
        // BoxV2 reInitialize: first call sets s_initialized=true, second call reverts
        // Note: Box v1 initialize doesn't set s_initialized (slot 2), so reInitialize
        // is allowed after v1→v2 upgrade. The guard prevents DOUBLE reInitialize.
        boxV2 = new BoxV2();

        // Upgrade directly to v2 (no v1 initialize)
        vm.prank(admin);
        proxy.upgradeTo(address(boxV2));

        // First reInitialize — should succeed
        vm.prank(admin);
        (bool ok1, ) = address(proxy).call(
            abi.encodeWithSelector(BoxV2.reInitialize.selector, uint256(10))
        );
        assertTrue(ok1);

        // Second reInitialize — should revert (s_initialized = true)
        vm.prank(admin);
        (bool ok2, ) = address(proxy).call(
            abi.encodeWithSelector(BoxV2.reInitialize.selector, uint256(999))
        );
        assertFalse(ok2);

        // Value should still be 10, not 999
        (bool ok3, bytes memory ret) = address(proxy).call(
            abi.encodeWithSelector(BoxV2.getValue.selector)
        );
        assertTrue(ok3);
        assertEq(abi.decode(ret, (uint256)), 10);
    }

    function test_proxy_zeroAddressReverts() public {
        vm.prank(admin);
        vm.expectRevert(SimpleProxy.SimpleProxy__ZeroAddress.selector);
        proxy.upgradeTo(address(0));
    }

    function test_proxy_stateBetweenMultipleUsers() public {
        address user = makeAddr("user");

        vm.prank(admin);
        (bool ok1, ) = address(proxy).call(
            abi.encodeWithSelector(Box.initialize.selector, uint256(50))
        );
        assertTrue(ok1);

        boxV2 = new BoxV2();
        vm.prank(admin);
        proxy.upgradeTo(address(boxV2));

        // Admin increments
        vm.prank(admin);
        (bool ok2, ) = address(proxy).call(
            abi.encodeWithSelector(BoxV2.increment.selector)
        );
        assertTrue(ok2);

        // User tries to set value — should fail (not admin)
        vm.prank(user);
        (bool ok3, ) = address(proxy).call(
            abi.encodeWithSelector(BoxV2.setValue.selector, uint256(0))
        );
        assertFalse(ok3);

        // Verify value still 51 (50 + 1), not changed by user
        (bool ok4, bytes memory ret) = address(proxy).call(
            abi.encodeWithSelector(BoxV2.getValue.selector)
        );
        assertTrue(ok4);
        assertEq(abi.decode(ret, (uint256)), 51);
    }

    // =====================================================
    // SECTION 7: Fuzz Tests
    // =====================================================

    function testFuzz_setValue_preservesThroughUpgrade(uint256 _value) public {
        vm.assume(_value > 0 && _value < type(uint128).max);

        vm.prank(admin);
        (bool ok1, ) = address(proxy).call(
            abi.encodeWithSelector(Box.initialize.selector, _value)
        );
        assertTrue(ok1);

        boxV2 = new BoxV2();
        vm.prank(admin);
        proxy.upgradeTo(address(boxV2));

        // Value should be preserved
        (bool ok2, bytes memory ret) = address(proxy).call(
            abi.encodeWithSelector(BoxV2.getValue.selector)
        );
        assertTrue(ok2);
        assertEq(abi.decode(ret, (uint256)), _value);
    }

    function testFuzz_increment_alwaysAddsOne(uint256 _start, uint256 _count) public {
        vm.assume(_start > 0 && _start < type(uint128).max);
        vm.assume(_count > 0 && _count < 100);

        vm.prank(admin);
        (bool ok1, ) = address(proxy).call(
            abi.encodeWithSelector(Box.initialize.selector, _start)
        );
        assertTrue(ok1);

        boxV2 = new BoxV2();
        vm.prank(admin);
        proxy.upgradeTo(address(boxV2));

        for (uint256 i = 0; i < _count; i++) {
            vm.prank(admin);
            (bool okInc, ) = address(proxy).call(
                abi.encodeWithSelector(BoxV2.increment.selector)
            );
            assertTrue(okInc);
        }

        (bool ok2, bytes memory ret) = address(proxy).call(
            abi.encodeWithSelector(BoxV2.getValue.selector)
        );
        assertTrue(ok2);
        assertEq(abi.decode(ret, (uint256)), _start + _count);
    }
}
