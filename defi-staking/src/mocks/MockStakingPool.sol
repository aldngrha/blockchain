// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IMintable {
    function mint(address to, uint256 amount) external;
}

/// @notice Mock pool untuk test — satu-satunya caller sah dari RewardToken.mint().
/// Dipakai ulang di test StakingPool (Min 13 Sep).
contract MockStakingPool {
    IMintable public immutable rewardToken;

    constructor(IMintable rewardToken_) {
        rewardToken = rewardToken_;
    }

    function mintReward(address to, uint256 amount) external {
        rewardToken.mint(to, amount);
    }
}
