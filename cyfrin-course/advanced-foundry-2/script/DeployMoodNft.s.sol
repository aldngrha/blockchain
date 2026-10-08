// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {MoodNft} from "../src/MoodNft.sol";

contract DeployMoodNft is Script {
    function run() public returns (MoodNft) {
        vm.startBroadcast();
        MoodNft moodNft = new MoodNft();
        vm.stopBroadcast();

        console.log("MoodNft deployed at:", address(moodNft));
        return moodNft;
    }
}
