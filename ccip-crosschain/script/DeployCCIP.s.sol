// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {CrossChainSender} from "../src/CrossChainSender.sol";
import {MessageReceiver} from "../src/MessageReceiver.sol";

/// @title DeployCCIP
/// @notice Deploys CrossChainSender and MessageReceiver against a given CCIP Router.
/// @dev Usage:
///      ROUTER=0x... forge script script/DeployCCIP.s.sol:DeployCCIP \
///        --rpc-url <RPC> --broadcast --private-key <KEY>
///
///      The Router address is read from the ROUTER env var and is NOT hardcoded, because
///      Router addresses differ per chain and change over time. Take it from the official
///      Chainlink CCIP directory for the chain you are deploying to.
///
///      Deployer identity comes from vm.addr(PRIVATE_KEY), not msg.sender: in a script frame
///      msg.sender is the default Foundry sender, while the broadcast is signed by the key.
contract DeployCCIP is Script {
  function run() external {
    uint256 deployerKey = vm.envUint("PRIVATE_KEY");
    address deployer = vm.addr(deployerKey);
    address router = vm.envAddress("ROUTER");

    console.log("Chain id:", block.chainid);
    console.log("Deployer:", deployer);
    console.log("Router:", router);

    vm.startBroadcast(deployerKey);

    CrossChainSender sender = new CrossChainSender(router);
    MessageReceiver receiver = new MessageReceiver(router);

    vm.stopBroadcast();

    console.log("CrossChainSender:", address(sender));
    console.log("MessageReceiver:", address(receiver));

    _writeDeployment(router, address(sender), address(receiver));
  }

  /// @dev Same shape as the other projects: chainId, deployedAt (epoch ms), deployer, contracts.
  function _writeDeployment(address router, address sender, address receiver) internal {
    string memory key = "deployment";
    vm.serializeUint(key, "chainId", block.chainid);
    vm.serializeString(key, "deployedAt", vm.toString(block.timestamp * 1000));
    vm.serializeAddress(key, "deployer", vm.addr(vm.envUint("PRIVATE_KEY")));
    vm.serializeAddress(key, "router", router);

    string memory contractsKey = "contracts";
    vm.serializeAddress(contractsKey, "CrossChainSender", sender);
    string memory contractsJson = vm.serializeAddress(contractsKey, "MessageReceiver", receiver);

    string memory json = vm.serializeString(key, "contracts", contractsJson);

    string memory path = string.concat("deployments/", vm.toString(block.chainid), ".json");
    vm.createDir("deployments", true);
    vm.writeFile(path, json);
    console.log("Wrote", path);
  }
}
