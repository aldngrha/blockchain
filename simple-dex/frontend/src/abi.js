// Hand-written ABIs. Source of truth:
//   DEX_PAIR_ABI: ../src/DexPair.sol (pair functions + its ERC20 surface)
//   ERC20_ABI:    OpenZeppelin v5 ERC20 surface used by TokenA/TokenB mocks
// Only the functions, events, and errors the frontend needs. Keep in sync
// when the contracts change.

// The DexPair is both the pool and the LP token (ERC20 "SimpleDex LP Token").
export const DEX_PAIR_ABI = [
  // Pair reads
  { type: "function", name: "token0", stateMutability: "view", inputs: [], outputs: [{ name: "", type: "address" }] },
  { type: "function", name: "token1", stateMutability: "view", inputs: [], outputs: [{ name: "", type: "address" }] },
  { type: "function", name: "getReserves", stateMutability: "view", inputs: [], outputs: [{ name: "", type: "uint256" }, { name: "", type: "uint256" }] },
  // Pair writes
  { type: "function", name: "addLiquidity", stateMutability: "nonpayable", inputs: [{ name: "amount0Desired", type: "uint256" }, { name: "amount1Desired", type: "uint256" }], outputs: [{ name: "amount0", type: "uint256" }, { name: "amount1", type: "uint256" }, { name: "liquidity", type: "uint256" }] },
  { type: "function", name: "removeLiquidity", stateMutability: "nonpayable", inputs: [{ name: "lpAmount", type: "uint256" }], outputs: [{ name: "amount0", type: "uint256" }, { name: "amount1", type: "uint256" }] },
  { type: "function", name: "swapExactTokensForTokens", stateMutability: "nonpayable", inputs: [{ name: "amountIn", type: "uint256" }, { name: "amountOutMin", type: "uint256" }, { name: "deadline", type: "uint256" }, { name: "zeroForOne", type: "bool" }], outputs: [{ name: "amountOut", type: "uint256" }] },
  // LP token surface (ERC20): totalSupply/balanceOf/allowance are read on the pair address.
  { type: "function", name: "totalSupply", stateMutability: "view", inputs: [], outputs: [{ name: "", type: "uint256" }] },
  { type: "function", name: "balanceOf", stateMutability: "view", inputs: [{ name: "account", type: "address" }], outputs: [{ name: "", type: "uint256" }] },
  { type: "function", name: "allowance", stateMutability: "view", inputs: [{ name: "owner", type: "address" }, { name: "spender", type: "address" }], outputs: [{ name: "", type: "uint256" }] },
  { type: "function", name: "symbol", stateMutability: "view", inputs: [], outputs: [{ name: "", type: "string" }] },
  // Events watched for live refetches.
  { type: "event", name: "Mint", inputs: [{ name: "sender", type: "address", indexed: true }, { name: "amount0", type: "uint256", indexed: false }, { name: "amount1", type: "uint256", indexed: false }] },
  { type: "event", name: "Burn", inputs: [{ name: "sender", type: "address", indexed: true }, { name: "amount0", type: "uint256", indexed: false }, { name: "amount1", type: "uint256", indexed: false }] },
  { type: "event", name: "Swap", inputs: [{ name: "sender", type: "address", indexed: true }, { name: "zeroForOne", type: "bool", indexed: true }, { name: "amountIn", type: "uint256", indexed: false }, { name: "amountOut", type: "uint256", indexed: false }] },
  { type: "event", name: "Sync", inputs: [{ name: "reserve0", type: "uint256", indexed: false }, { name: "reserve1", type: "uint256", indexed: false }] },
  // DexPair custom errors (src/DexPair.sol), so viem can decode revert reasons.
  { type: "error", name: "DexPair__Locked", inputs: [] },
  { type: "error", name: "DexPair__IdenticalAddresses", inputs: [] },
  { type: "error", name: "DexPair__ZeroAddress", inputs: [] },
  { type: "error", name: "DexPair__ZeroAmount", inputs: [] },
  { type: "error", name: "DexPair__Expired", inputs: [] },
  { type: "error", name: "DexPair__InsufficientOutput", inputs: [] },
  { type: "error", name: "DexPair__InsufficientLiquidityMinted", inputs: [] },
  { type: "error", name: "DexPair__InsufficientLiquidityBurned", inputs: [] },
  { type: "error", name: "DexPair__FeeOnTransferNotSupported", inputs: [] },
  // AMMLibrary custom errors (src/AMMLibrary.sol), reachable through the pair.
  { type: "error", name: "AMMLibrary__InsufficientInput", inputs: [] },
  { type: "error", name: "AMMLibrary__InsufficientOutput", inputs: [] },
  { type: "error", name: "AMMLibrary__InsufficientLiquidity", inputs: [] },
];

// TokenA and TokenB are OpenZeppelin v5 ERC20 mocks (src/mocks/ERC20Mock.sol).
export const ERC20_ABI = [
  { type: "function", name: "approve", stateMutability: "nonpayable", inputs: [{ name: "spender", type: "address" }, { name: "value", type: "uint256" }], outputs: [{ name: "", type: "bool" }] },
  { type: "function", name: "balanceOf", stateMutability: "view", inputs: [{ name: "account", type: "address" }], outputs: [{ name: "", type: "uint256" }] },
  { type: "function", name: "allowance", stateMutability: "view", inputs: [{ name: "owner", type: "address" }, { name: "spender", type: "address" }], outputs: [{ name: "", type: "uint256" }] },
  { type: "function", name: "symbol", stateMutability: "view", inputs: [], outputs: [{ name: "", type: "string" }] },
  { type: "function", name: "decimals", stateMutability: "view", inputs: [], outputs: [{ name: "", type: "uint8" }] },
  // OpenZeppelin v5 ERC20 custom errors surfaced through approve / transferFrom.
  { type: "error", name: "ERC20InsufficientBalance", inputs: [{ name: "sender", type: "address" }, { name: "balance", type: "uint256" }, { name: "needed", type: "uint256" }] },
  { type: "error", name: "ERC20InvalidSender", inputs: [{ name: "sender", type: "address" }] },
  { type: "error", name: "ERC20InvalidReceiver", inputs: [{ name: "receiver", type: "address" }] },
  { type: "error", name: "ERC20InsufficientAllowance", inputs: [{ name: "spender", type: "address" }, { name: "allowance", type: "uint256" }, { name: "needed", type: "uint256" }] },
  { type: "error", name: "ERC20InvalidApprover", inputs: [{ name: "approver", type: "address" }] },
  { type: "error", name: "ERC20InvalidSpender", inputs: [{ name: "spender", type: "address" }] },
  { type: "event", name: "Approval", inputs: [{ name: "owner", type: "address", indexed: true }, { name: "spender", type: "address", indexed: true }, { name: "value", type: "uint256", indexed: false }] },
  { type: "event", name: "Transfer", inputs: [{ name: "from", type: "address", indexed: true }, { name: "to", type: "address", indexed: true }, { name: "value", type: "uint256", indexed: false }] },
];
