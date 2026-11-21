// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {FlashLoanReceiver} from "../src/FlashLoanReceiver.sol";
import {RecordAction} from "../src/actions/RecordAction.sol";

/// @notice Deploy receiver + action demo, lalu tulis deployments/<chainId>.json
/// @dev POOL dibaca dari env, bukan di-hardcode, karena beda chain beda Pool:
///      POOL=0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2 PRIVATE_KEY=... forge script ...
contract DeployFlashLoan is Script {
    function run() external returns (FlashLoanReceiver receiver, RecordAction action) {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address pool = vm.envAddress("POOL");
        address deployer = vm.addr(pk);

        vm.startBroadcast(pk);
        action = new RecordAction();
        receiver = new FlashLoanReceiver(pool, deployer);
        receiver.setActionAllowed(address(action), true);
        vm.stopBroadcast();

        console.log("Pool        :", pool);
        console.log("Receiver    :", address(receiver));
        console.log("RecordAction:", address(action));

        string memory obj = "deployment";
        vm.serializeUint(obj, "chainId", block.chainid);
        vm.serializeUint(obj, "deployedAt", block.timestamp * 1000);
        vm.serializeAddress(obj, "deployer", deployer);
        vm.serializeAddress(obj, "pool", pool);
        vm.serializeAddress(obj, "receiver", address(receiver));
        string memory json = vm.serializeAddress(obj, "recordAction", address(action));

        vm.createDir("deployments", true);
        vm.writeJson(json, string.concat("deployments/", vm.toString(block.chainid), ".json"));
    }
}
