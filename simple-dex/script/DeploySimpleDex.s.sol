// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {DexPair} from "../src/DexPair.sol";
import {ERC20Mock} from "../src/mocks/ERC20Mock.sol";

/// @title DeploySimpleDex - deployment anvil/testnet dalam satu run.
/// @notice Urutan: TokenA -> TokenB -> DexPair -> mint ke deployer -> approve ->
///         addLiquidity(1000e18, 1000e18). DexPair mengurutkan token berdasarkan
///         address, jadi label TokenA/TokenB di JSON adalah label DEPLOY, bukan
///         urutan kanonik pair (cek pair.token0() bila perlu urutan kanonik).
contract DeploySimpleDex is Script {
    /// @dev Initial liquidity per token (roadmap Sel 6 Okt): 1000 A + 1000 B.
    uint256 public constant INITIAL_LIQUIDITY = 1000e18;
    /// @dev Mint 10x liquidity supaya deployer masih punya sisa token untuk demo swap.
    uint256 public constant MINT_PER_TOKEN = 10_000e18;

    function run() external returns (ERC20Mock tokenA, ERC20Mock tokenB, DexPair pair) {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        // msg.sender di konteks script = default sender cheatcode, BUKAN address
        // dari PRIVATE_KEY. Untuk metadata deployer yang akurat, derive dari key.
        address deployer = vm.addr(deployerKey);

        vm.startBroadcast(deployerKey);

        tokenA = new ERC20Mock("SimpleDex Token A", "SDA");
        tokenB = new ERC20Mock("SimpleDex Token B", "SDB");
        pair = new DexPair(address(tokenA), address(tokenB));

        tokenA.mint(deployer, MINT_PER_TOKEN);
        tokenB.mint(deployer, MINT_PER_TOKEN);
        tokenA.approve(address(pair), INITIAL_LIQUIDITY);
        tokenB.approve(address(pair), INITIAL_LIQUIDITY);
        (uint256 used0, uint256 used1, uint256 lp) = pair.addLiquidity(
            INITIAL_LIQUIDITY, INITIAL_LIQUIDITY
        );

        vm.stopBroadcast();

        _writeDeploymentJson(deployer, address(tokenA), address(tokenB), address(pair));

        console.log("TokenA:  ", address(tokenA));
        console.log("TokenB:  ", address(tokenB));
        console.log("DexPair: ", address(pair));
        console.log("token0:  ", pair.token0());
        console.log("seeded amount0:", used0);
        console.log("seeded amount1:", used1);
        console.log("LP minted:", lp);
    }

    /// @dev Tulis deployments/<chainId>.json: sumber address untuk tooling
    ///      (frontend, cast script). deployedAt = epoch milidetik sebagai string.
    function _writeDeploymentJson(
        address deployer,
        address tokenA_,
        address tokenB_,
        address pair_
    ) internal {
        vm.createDir("deployments", true);

        string memory json = "root";
        vm.serializeUint(json, "chainId", block.chainid);
        vm.serializeString(json, "deployedAt", vm.toString(vm.unixTime()));
        vm.serializeAddress(json, "deployer", deployer);

        string memory contracts = "contracts";
        vm.serializeAddress(contracts, "TokenA", tokenA_);
        vm.serializeAddress(contracts, "TokenB", tokenB_);
        string memory contractsJson = vm.serializeAddress(contracts, "DexPair", pair_);
        string memory finalJson = vm.serializeString(json, "contracts", contractsJson);

        vm.writeFile(
            string.concat("deployments/", vm.toString(block.chainid), ".json"), finalJson
        );
    }
}
