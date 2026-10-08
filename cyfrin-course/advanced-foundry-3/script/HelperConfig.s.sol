// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {DecentralizedStableCoin} from "../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../src/DSCEngine.sol";
import {MockV3Aggregator} from "../src/mocks/MockV3Aggregator.sol";

contract HelperConfig is Script {
    struct NetworkConfig {
        address ethUsdPriceFeed;
        uint8 priceFeedDecimals;
        address dscToken;
        address dsceEngine;
    }

    uint8 public constant PRICE_FEED_DECIMALS = 8;
    int256 public constant INITIAL_PRICE = 2000e8; // $2000 ETH/USD

    function getConfig() public returns (NetworkConfig memory) {
        return getConfigByChainId(block.chainid);
    }

    function getConfigByChainId(uint256 chainId) public returns (NetworkConfig memory) {
        if (chainId == 11155111) {
            return getSepoliaEthConfig();
        } else {
            return getAnvilEthConfig();
        }
    }

    function getSepoliaEthConfig() public pure returns (NetworkConfig memory) {
        // Sepolia ETH/USD price feed
        address ethUsdPriceFeed = 0x694AA1769357215DE4FAC081bf1f309aDC325306;
        return NetworkConfig({
            ethUsdPriceFeed: ethUsdPriceFeed,
            priceFeedDecimals: PRICE_FEED_DECIMALS,
            dscToken: address(0),
            dsceEngine: address(0)
        });
    }

    function getAnvilEthConfig() public returns (NetworkConfig memory) {
        // Deploy mock price feed for local testing
        vm.startBroadcast();
        MockV3Aggregator mockPriceFeed = new MockV3Aggregator(PRICE_FEED_DECIMALS, INITIAL_PRICE);
        vm.stopBroadcast();

        return NetworkConfig({
            ethUsdPriceFeed: address(mockPriceFeed),
            priceFeedDecimals: PRICE_FEED_DECIMALS,
            dscToken: address(0),
            dsceEngine: address(0)
        });
    }
}
