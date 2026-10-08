// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";
import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";

/// @title RewardToken — ERC-20 reward yang hanya bisa di-mint oleh StakingPool.
/// @notice Pola: ERC20 + Ownable. Minter tunggal = StakingPool (diset sekali, irreversible).
/// @dev Sesuai SPEC §3. Owner = deployer; owner TIDAK punya hak mint (hanya StakingPool).
contract RewardToken is ERC20, Ownable {
    error RewardToken__Unauthorized();
    error RewardToken__StakingPoolAlreadySet();

    event StakingPoolSet(address indexed newStakingPool);

    /// @notice Satu-satunya address yang boleh memanggil mint(). Set sekali, tidak bisa diganti.
    address public stakingPool;

    constructor(
        string memory name_,
        string memory symbol_,
        uint256 initialSupply_
    ) ERC20(name_, symbol_) Ownable(msg.sender) {
        // Bootstrap: tanpa pre-mint, TIDAK ADA yang bisa pegang token (mint gated ke pool,
        // pool butuh token buat distake) -> protocol gak pernah bisa jalan.
        if (initialSupply_ > 0) _mint(msg.sender, initialSupply_);
    }

    /// @notice Set address StakingPool. Hanya owner, hanya SEKALI (guard zero address).
    function setStakingPool(address pool_) external onlyOwner {
        if (stakingPool != address(0)) revert RewardToken__StakingPoolAlreadySet();
        stakingPool = pool_;
        emit StakingPoolSet(pool_);
    }

    /// @notice Mint reward. Hanya StakingPool — dipanggil saat user claimReward().
    function mint(address to, uint256 amount) external {
        if (msg.sender != stakingPool) revert RewardToken__Unauthorized();
        _mint(to, amount);
    }
}
