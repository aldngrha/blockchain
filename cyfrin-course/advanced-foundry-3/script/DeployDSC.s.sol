// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {DecentralizedStableCoin} from "../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../src/DSCEngine.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployDSC is Script {
    function run() public returns (DecentralizedStableCoin, DSCEngine) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory networkConfig = helperConfig.getConfig();

        address[] memory priceFeedAddresses = new address[](1);
        priceFeedAddresses[0] = networkConfig.ethUsdPriceFeed;

        address[] memory collateralAddresses = new address[](1);
        collateralAddresses[0] = address(0); // ETH

        vm.startBroadcast();
        DecentralizedStableCoin dsc = new DecentralizedStableCoin(address(0));
        DSCEngine engine = new DSCEngine(address(dsc), priceFeedAddresses, collateralAddresses);
        vm.stopBroadcast();

        console.log("DecentralizedStableCoin deployed at:", address(dsc));
        console.log("DSCEngine deployed at:", address(engine));
        console.log("Price feed used:", networkConfig.ethUsdPriceFeed);

        return (dsc, engine);
    }
}
