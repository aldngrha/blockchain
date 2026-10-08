// Hand-written ABIs. Source of truth:
//   STAKING_POOL_ABI: ../src/StakingPool.sol
//   REWARD_TOKEN_ABI: ../src/RewardToken.sol (+ OpenZeppelin v5 ERC20 errors)
// Only the functions, events, and errors the frontend needs. Keep in sync
// when the contracts change.

export const STAKING_POOL_ABI = [
  { type: "function", name: "stake", stateMutability: "nonpayable", inputs: [{ name: "amount", type: "uint256" }], outputs: [] },
  { type: "function", name: "unstake", stateMutability: "nonpayable", inputs: [{ name: "amount", type: "uint256" }], outputs: [] },
  { type: "function", name: "claimReward", stateMutability: "nonpayable", inputs: [], outputs: [] },
  { type: "function", name: "emergencyWithdraw", stateMutability: "nonpayable", inputs: [], outputs: [] },
  { type: "function", name: "getStakedBalance", stateMutability: "view", inputs: [{ name: "user", type: "address" }], outputs: [{ name: "", type: "uint256" }] },
  { type: "function", name: "getTotalStaked", stateMutability: "view", inputs: [], outputs: [{ name: "", type: "uint256" }] },
  { type: "function", name: "earned", stateMutability: "view", inputs: [{ name: "account", type: "address" }], outputs: [{ name: "", type: "uint256" }] },
  { type: "function", name: "rewardRate", stateMutability: "view", inputs: [], outputs: [{ name: "", type: "uint256" }] },
  { type: "function", name: "periodFinish", stateMutability: "view", inputs: [], outputs: [{ name: "", type: "uint256" }] },
  { type: "function", name: "rewardToken", stateMutability: "view", inputs: [], outputs: [{ name: "", type: "address" }] },
  { type: "event", name: "Staked", inputs: [{ name: "user", type: "address", indexed: true }, { name: "amount", type: "uint256", indexed: false }] },
  { type: "event", name: "Unstaked", inputs: [{ name: "user", type: "address", indexed: true }, { name: "amount", type: "uint256", indexed: false }] },
  { type: "event", name: "EmergencyWithdraw", inputs: [{ name: "user", type: "address", indexed: true }, { name: "amount", type: "uint256", indexed: false }] },
  { type: "event", name: "RewardPaid", inputs: [{ name: "user", type: "address", indexed: true }, { name: "amount", type: "uint256", indexed: false }] },
  { type: "event", name: "RewardRateSet", inputs: [{ name: "newRate", type: "uint256", indexed: false }] },
  { type: "error", name: "StakingPool__ZeroAmount", inputs: [] },
  { type: "error", name: "StakingPool__InsufficientStake", inputs: [] },
  { type: "error", name: "StakingPool__NothingStaked", inputs: [] },
  { type: "error", name: "StakingPool__NothingToClaim", inputs: [] },
  { type: "error", name: "StakingPool__RewardRateTooHigh", inputs: [] },
];

export const REWARD_TOKEN_ABI = [
  { type: "function", name: "approve", stateMutability: "nonpayable", inputs: [{ name: "spender", type: "address" }, { name: "value", type: "uint256" }], outputs: [{ name: "", type: "bool" }] },
  { type: "function", name: "balanceOf", stateMutability: "view", inputs: [{ name: "account", type: "address" }], outputs: [{ name: "", type: "uint256" }] },
  { type: "function", name: "allowance", stateMutability: "view", inputs: [{ name: "owner", type: "address" }, { name: "spender", type: "address" }], outputs: [{ name: "", type: "uint256" }] },
  { type: "function", name: "symbol", stateMutability: "view", inputs: [], outputs: [{ name: "", type: "string" }] },
  { type: "function", name: "decimals", stateMutability: "view", inputs: [], outputs: [{ name: "", type: "uint8" }] },
  { type: "error", name: "RewardToken__Unauthorized", inputs: [] },
  { type: "error", name: "RewardToken__StakingPoolAlreadySet", inputs: [] },
  // OpenZeppelin v5 ERC20 custom errors, so viem can decode revert reasons
  // from approve/transferFrom paths.
  { type: "error", name: "ERC20InsufficientBalance", inputs: [{ name: "sender", type: "address" }, { name: "balance", type: "uint256" }, { name: "needed", type: "uint256" }] },
  { type: "error", name: "ERC20InvalidSender", inputs: [{ name: "sender", type: "address" }] },
  { type: "error", name: "ERC20InvalidReceiver", inputs: [{ name: "receiver", type: "address" }] },
  { type: "error", name: "ERC20InsufficientAllowance", inputs: [{ name: "spender", type: "address" }, { name: "allowance", type: "uint256" }, { name: "needed", type: "uint256" }] },
  { type: "error", name: "ERC20InvalidApprover", inputs: [{ name: "approver", type: "address" }] },
  { type: "error", name: "ERC20InvalidSpender", inputs: [{ name: "spender", type: "address" }] },
  { type: "event", name: "Approval", inputs: [{ name: "owner", type: "address", indexed: true }, { name: "spender", type: "address", indexed: true }, { name: "value", type: "uint256", indexed: false }] },
  { type: "event", name: "Transfer", inputs: [{ name: "from", type: "address", indexed: true }, { name: "to", type: "address", indexed: true }, { name: "value", type: "uint256", indexed: false }] },
];
