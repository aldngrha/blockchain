// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";

interface IMintable {
    function mint(address to, uint256 amount) external;
}
import {ReentrancyGuard} from "openzeppelin-contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";

/// @title StakingPool — core staking (Min 13 Sep). Reward math menyusul Sen 14 Sep (SPEC §4-5).
/// @notice STUB FASE MERAH (TDD): signature & event ada, logika belum.
contract StakingPool is Ownable, ReentrancyGuard {
    error StakingPool__ZeroAmount();
    error StakingPool__InsufficientStake();
    error StakingPool__NothingStaked();
    error StakingPool__NothingToClaim();
    error StakingPool__RewardRateTooHigh();

    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 amount);
    event RewardRateSet(uint256 newRate);
    event RewardPaid(address indexed user, uint256 amount);

    IERC20 public immutable rewardToken;

    uint256 public totalStaked;
    mapping(address user => uint256 amount) internal _stakedBalance;

    // ===== REWARD STATE (stub fase merah, implement Sen 14 Sep) =====
    uint256 public constant MAX_REWARD_RATE = 1e24; // sanity cap (SPEC §4)
    uint256 public constant DURATION = 7 days;

    uint256 public rewardRate;          // stub: 0
    uint256 public periodFinish;
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored; // stub: 0
    mapping(address user => uint256 amount) internal userRewardPerTokenPaid;
    mapping(address user => uint256 amount) internal rewards;

    constructor(address rewardToken_) Ownable(msg.sender) {
        rewardToken = IERC20(rewardToken_);
    }

    /// @notice Stake token: pool narik via transferFrom (approve dulu). CEI: state dulu, transfer belakangan.
    function stake(uint256 amount) external nonReentrant {
        _updateReward(msg.sender);
        if (amount == 0) revert StakingPool__ZeroAmount();

        // effects
        _stakedBalance[msg.sender] += amount;
        totalStaked += amount;

        // interactions
        rewardToken.transferFrom(msg.sender, address(this), amount);
        emit Staked(msg.sender, amount);
    }

    /// @notice Unstake sebagian/all. Cek saldo dulu — jangan biarkan underflow.
    function unstake(uint256 amount) external nonReentrant {
        _updateReward(msg.sender);
        if (amount == 0) revert StakingPool__ZeroAmount();
        uint256 staked = _stakedBalance[msg.sender];
        if (amount > staked) revert StakingPool__InsufficientStake();

        // effects
        _stakedBalance[msg.sender] = staked - amount;
        totalStaked -= amount;

        // interactions
        rewardToken.transfer(msg.sender, amount);
        emit Unstaked(msg.sender, amount);
    }

    /// @notice Escape hatch: balikin SEMUA stake. SENGAJA skip _updateReward reward-nya —
    ///         reward FORFEIT, checkpoint di-reset biar restake gak dapet phantom reward.
    function emergencyWithdraw() external nonReentrant {
        uint256 amount = _stakedBalance[msg.sender];
        if (amount == 0) revert StakingPool__NothingStaked();

        // Freeze akumulasi global SEBELUM saldo dikurangi (share user masih ikut
        // terhitung sampai detik ini), supaya stored/lastUpdate konsisten dengan
        // checkpoint user — gak ada stored_lama < checkpoint -> underflow di earned().
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();

        // effects
        _stakedBalance[msg.sender] = 0;
        totalStaked -= amount;
        rewards[msg.sender] = 0; // FORFEIT — trade-off eksplisit SPEC E5
        userRewardPerTokenPaid[msg.sender] = rewardPerTokenStored;

        // interactions
        rewardToken.transfer(msg.sender, amount);
        emit EmergencyWithdraw(msg.sender, amount);
    }

    // ===== REWARD FUNCTIONS (implementasi Sen 14 Sep — pola Synthetix, SPEC §5) =====

    /// @notice Set rate baru dan mulai periode 7-hari SEKARANG. Akumulasi lama di-freeze via _updateReward(address(0)).
    function setRewardRate(uint256 newRate) external onlyOwner {
        _updateReward(address(0));
        if (newRate > MAX_REWARD_RATE) revert StakingPool__RewardRateTooHigh();

        rewardRate = newRate;
        lastUpdateTime = block.timestamp;
        periodFinish = block.timestamp + DURATION;
        emit RewardRateSet(newRate);
    }

    /// @notice Akumulator berhenti di periodFinish — reward gak jalan melewati periode.
    function lastTimeRewardApplicable() public view returns (uint256) {
        return block.timestamp < periodFinish ? block.timestamp : periodFinish;
    }

    /// @notice Reward kumulatif per 1e18 token yang distake, sejak awal waktu.
    /// GUARD div-by-zero: pool kosong -> akumulator diam (reward periode itu hilang, E10).
    function rewardPerToken() public view returns (uint256) {
        if (totalStaked == 0) {
            return rewardPerTokenStored;
        }
        return rewardPerTokenStored +
            (rewardRate * (lastTimeRewardApplicable() - lastUpdateTime) * 1e18) / totalStaked;
    }

    /// @notice Total reward milik `account` yang belum di-claim.
    function earned(address account) public view returns (uint256) {
        return (
            _stakedBalance[account] *
                (rewardPerToken() - userRewardPerTokenPaid[account])
        ) / 1e18 + rewards[account];
    }

    /// @notice Claim reward: MINT RewardToken baru ke user (pull payment).
    /// CEI: checkpoint + reset rewards dulu, mint belakangan.
    function claimReward() external nonReentrant {
        _updateReward(msg.sender);
        uint256 amount = rewards[msg.sender];
        if (amount == 0) revert StakingPool__NothingToClaim();

        // effects
        rewards[msg.sender] = 0;

        // interactions — satu-satunya jalur mint yang sah di seluruh protocol
        IMintable(address(rewardToken)).mint(msg.sender, amount);
        emit RewardPaid(msg.sender, amount);
    }

    /// @notice Convenience: unstake SEMUA + claim reward dalam 1 tx (SPEC §4, E17, I-5).
    function unstakeAndClaim() external nonReentrant {
        _updateReward(msg.sender);
        uint256 staked = _stakedBalance[msg.sender];
        uint256 owed = rewards[msg.sender];
        if (staked == 0) revert StakingPool__NothingStaked();
        if (owed == 0) revert StakingPool__NothingToClaim();

        // effects
        _stakedBalance[msg.sender] = 0;
        totalStaked -= staked;
        rewards[msg.sender] = 0;

        // interactions
        rewardToken.transfer(msg.sender, staked);
        IMintable(address(rewardToken)).mint(msg.sender, owed);
        emit Unstaked(msg.sender, staked);
        emit RewardPaid(msg.sender, owed);
    }

    /// @notice WAJIB dipanggil di awal fungsi yang mengubah saldo/rate:
    /// freeze akumulasi global + materialisasi reward user ke mapping sebelum state berubah.
    function _updateReward(address account) internal {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
    }

    function getStakedBalance(address user) external view returns (uint256) {
        return _stakedBalance[user];
    }

    function getTotalStaked() external view returns (uint256) {
        return totalStaked;
    }
}
