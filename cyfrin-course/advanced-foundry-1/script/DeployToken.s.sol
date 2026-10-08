// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {Token} from "../src/Token.sol";

contract DeployToken is Script {
    function run() public returns (Token) {
        string memory name = "CodebuffToken";
        string memory symbol = "CBT";
        uint256 initialSupply = 100_000 * 10 ** 18; // 100k tokens

        vm.startBroadcast();
        Token token = new Token(name, symbol, initialSupply);
        vm.stopBroadcast();

        console.log("Token deployed at:", address(token));
        console.log("Name:", token.name());
        console.log("Symbol:", token.symbol());
        console.log("Total Supply:", token.totalSupply());

        return token;
    }
}
