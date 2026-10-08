// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/MintNFT.sol";

contract DeployMintNFT is Script {
    function run() external returns (MintNFT) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        MintNFT nft = new MintNFT();

        vm.stopBroadcast();

        console.log("MintNFT deployed at:", address(nft));
        console.log("Deployer:", vm.addr(deployerPrivateKey));

        return nft;
    }
}
