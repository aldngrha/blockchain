// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IStakingPoolEvents {
    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 amount);
    event RewardRateSet(uint256 newRate);
    event RewardPaid(address indexed user, uint256 amount);
}
