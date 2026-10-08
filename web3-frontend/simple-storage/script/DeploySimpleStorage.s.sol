// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/SimpleStorage.sol";

contract DeploySimpleStorage is Script {
    function run() external returns (SimpleStorage) {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(privateKey);
        SimpleStorage simpleStorage = new SimpleStorage();
        vm.stopBroadcast();
        console.log("SimpleStorage deployed at:", address(simpleStorage));
        return simpleStorage;
    }
}
