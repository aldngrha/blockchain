// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {RewardToken} from "../src/RewardToken.sol";
import {StakingPool} from "../src/StakingPool.sol";

/// @title DeployStaking - deployment Sepolia/anvil sesuai SPEC §9.
/// @notice Urutan wajib: RewardToken -> StakingPool -> setStakingPool (sekali) -> setRewardRate.
///         Reward period 7 hari MULAI saat setRewardRate, jadi jalankan sekaligus dengan deploy
///         dan segera stake kalau mau reward periode pertama gak hangus (lihat E10 SPEC).
contract DeployStaking is Script {
    // Bootstrap stake pool (SPEC §3): tanpa pre-mint tidak ada yang bisa stake,
    // karena mint() di-gate ke StakingPool.
    uint256 public constant INITIAL_SUPPLY = 1_000_000e18;
    // Sepolia demo rate: 1 RWT/detik (SPEC §9). Keckasongannya: 604_800 RWT per periode 7 hari.
    uint256 public constant REWARD_RATE = 1e18;

    function run() external returns (RewardToken rewardToken, StakingPool stakingPool) {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        // msg.sender di konteks script = default sender cheatcode, BUKAN address dari
        // PRIVATE_KEY. Untuk metadata deployer yang akurat, derive dari key.
        address deployer = vm.addr(deployerKey);

        vm.startBroadcast(deployerKey);

        rewardToken = new RewardToken("Reward Token", "RWT", INITIAL_SUPPLY);
        stakingPool = new StakingPool(address(rewardToken));
        // Wire sekali, irreversible (guard StakingPoolAlreadySet di kontrak).
        rewardToken.setStakingPool(address(stakingPool));
        // Terakhir: periodFinish = now + 7 days supaya reward window gak bocor waktu.
        stakingPool.setRewardRate(REWARD_RATE);

        vm.stopBroadcast();

        _writeDeploymentJson(deployer, address(rewardToken), address(stakingPool));

        console.log("RewardToken:", address(rewardToken));
        console.log("StakingPool: ", address(stakingPool));
        console.log("RewardRate:", REWARD_RATE, "wei/sec | period: 604800 sec (7 days)");
    }

    /// @dev Tulis deployments/<chainId>.json sebagai sumber address buat frontend
    ///      (dibaca vite.config, override via .env VITE_STAKING_POOL_ADDRESS dst).
    function _writeDeploymentJson(address deployer, address token, address pool) internal {
        vm.createDir("deployments", true);

        string memory json = "root";
        vm.serializeUint(json, "chainId", block.chainid);
        // DeployedAt: epoch milidetik (Solidity gak punya formatter ISO; frontend gak
        // depends ke format ini).
        vm.serializeString(json, "deployedAt", vm.toString(vm.unixTime()));
        vm.serializeAddress(json, "deployer", deployer);

        string memory contracts = "contracts";
        vm.serializeAddress(contracts, "RewardToken", token);
        string memory contractsJson = vm.serializeAddress(contracts, "StakingPool", pool);
        string memory finalJson = vm.serializeString(json, "contracts", contractsJson);

        vm.writeFile(string.concat("deployments/", vm.toString(block.chainid), ".json"), finalJson);
    }
}
