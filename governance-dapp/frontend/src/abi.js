// Hand-written ABIs. Source of truth:
//   GOVERNOR_ABI: ../src/GovernorContract.sol + OpenZeppelin v5.4.0 (verified
//     against out/GovernorContract.sol/GovernorContract.json, including the
//     `signatures` field on ProposalCreated that most OZ docs omit)
//   GOVERNANCE_TOKEN_ABI: ../src/GovernanceToken.sol (+ ERC20Votes from OZ)
//   TREASURY_ABI: ../src/Treasury.sol
// Only the functions, events, and errors the frontend needs. Error entries are
// included so viem can decode revert reasons from nested contract calls.
// Keep in sync when the contracts change.

export const GOVERNOR_ABI = [
  // State-changing
  { type: "function", name: "propose", stateMutability: "nonpayable", inputs: [{ name: "targets", type: "address[]" }, { name: "values", type: "uint256[]" }, { name: "calldatas", type: "bytes[]" }, { name: "description", type: "string" }], outputs: [{ name: "", type: "uint256" }] },
  { type: "function", name: "castVote", stateMutability: "nonpayable", inputs: [{ name: "proposalId", type: "uint256" }, { name: "support", type: "uint8" }], outputs: [{ name: "", type: "uint256" }] },
  { type: "function", name: "castVoteWithReason", stateMutability: "nonpayable", inputs: [{ name: "proposalId", type: "uint256" }, { name: "support", type: "uint8" }, { name: "reason", type: "string" }], outputs: [{ name: "", type: "uint256" }] },
  { type: "function", name: "queue", stateMutability: "nonpayable", inputs: [{ name: "targets", type: "address[]" }, { name: "values", type: "uint256[]" }, { name: "calldatas", type: "bytes[]" }, { name: "descriptionHash", type: "bytes32" }], outputs: [{ name: "", type: "uint256" }] },
  { type: "function", name: "execute", stateMutability: "payable", inputs: [{ name: "targets", type: "address[]" }, { name: "values", type: "uint256[]" }, { name: "calldatas", type: "bytes[]" }, { name: "descriptionHash", type: "bytes32" }], outputs: [{ name: "", type: "uint256" }] },
  { type: "function", name: "cancel", stateMutability: "nonpayable", inputs: [{ name: "targets", type: "address[]" }, { name: "values", type: "uint256[]" }, { name: "calldatas", type: "bytes[]" }, { name: "descriptionHash", type: "bytes32" }], outputs: [{ name: "", type: "uint256" }] },
  // Views
  { type: "function", name: "state", stateMutability: "view", inputs: [{ name: "proposalId", type: "uint256" }], outputs: [{ name: "", type: "uint8" }] },
  { type: "function", name: "proposalSnapshot", stateMutability: "view", inputs: [{ name: "proposalId", type: "uint256" }], outputs: [{ name: "", type: "uint256" }] },
  { type: "function", name: "proposalDeadline", stateMutability: "view", inputs: [{ name: "proposalId", type: "uint256" }], outputs: [{ name: "", type: "uint256" }] },
  { type: "function", name: "proposalEta", stateMutability: "view", inputs: [{ name: "proposalId", type: "uint256" }], outputs: [{ name: "", type: "uint256" }] },
  { type: "function", name: "proposalProposer", stateMutability: "view", inputs: [{ name: "proposalId", type: "uint256" }], outputs: [{ name: "", type: "address" }] },
  { type: "function", name: "proposalVotes", stateMutability: "view", inputs: [{ name: "proposalId", type: "uint256" }], outputs: [{ name: "againstVotes", type: "uint256" }, { name: "forVotes", type: "uint256" }, { name: "abstainVotes", type: "uint256" }] },
  { type: "function", name: "hasVoted", stateMutability: "view", inputs: [{ name: "proposalId", type: "uint256" }, { name: "account", type: "address" }], outputs: [{ name: "", type: "bool" }] },
  { type: "function", name: "quorum", stateMutability: "view", inputs: [{ name: "timepoint", type: "uint256" }], outputs: [{ name: "", type: "uint256" }] },
  { type: "function", name: "hashProposal", stateMutability: "pure", inputs: [{ name: "targets", type: "address[]" }, { name: "values", type: "uint256[]" }, { name: "calldatas", type: "bytes[]" }, { name: "descriptionHash", type: "bytes32" }], outputs: [{ name: "", type: "uint256" }] },
  { type: "function", name: "token", stateMutability: "view", inputs: [], outputs: [{ name: "", type: "address" }] },
  { type: "function", name: "timelock", stateMutability: "view", inputs: [], outputs: [{ name: "", type: "address" }] },
  { type: "function", name: "votingDelay", stateMutability: "view", inputs: [], outputs: [{ name: "", type: "uint256" }] },
  { type: "function", name: "votingPeriod", stateMutability: "view", inputs: [], outputs: [{ name: "", type: "uint256" }] },
  // Events. Note: OZ 5.4 ProposalCreated carries a `signatures` field between
  // values and calldatas (verified against the compiled ABI, OZ 5.4.0).
  { type: "event", name: "ProposalCreated", inputs: [{ name: "proposalId", type: "uint256", indexed: false }, { name: "proposer", type: "address", indexed: false }, { name: "targets", type: "address[]", indexed: false }, { name: "values", type: "uint256[]", indexed: false }, { name: "signatures", type: "string[]", indexed: false }, { name: "calldatas", type: "bytes[]", indexed: false }, { name: "voteStart", type: "uint256", indexed: false }, { name: "voteEnd", type: "uint256", indexed: false }, { name: "description", type: "string", indexed: false }] },
  { type: "event", name: "VoteCast", inputs: [{ name: "voter", type: "address", indexed: true }, { name: "proposalId", type: "uint256", indexed: false }, { name: "support", type: "uint8", indexed: false }, { name: "weight", type: "uint256", indexed: false }, { name: "reason", type: "string", indexed: false }] },
  { type: "event", name: "ProposalQueued", inputs: [{ name: "proposalId", type: "uint256", indexed: false }, { name: "etaSeconds", type: "uint256", indexed: false }] },
  { type: "event", name: "ProposalExecuted", inputs: [{ name: "proposalId", type: "uint256", indexed: false }] },
  { type: "event", name: "ProposalCanceled", inputs: [{ name: "proposalId", type: "uint256", indexed: false }] },
  // IGovernor + TimelockController errors that can surface as revert reasons.
  // Timelock errors propagate through governor.execute because the timelock
  // call is not wrapped, so they must be decodable here too. Note: in OZ 5.4
  // the timelock error carries a bytes32 state BITMAP, not a uint8 (selector
  // 0x5ead8eb5, verified against the revert data on chain).
  { type: "error", name: "GovernorUnexpectedProposalState", inputs: [{ name: "proposalId", type: "uint256" }, { name: "current", type: "uint8" }, { name: "expectedStates", type: "bytes32" }] },
  { type: "error", name: "GovernorAlreadyCastVote", inputs: [{ name: "voter", type: "address" }] },
  { type: "error", name: "GovernorNonexistentProposal", inputs: [{ name: "proposalId", type: "uint256" }] },
  { type: "error", name: "GovernorUnableToCancel", inputs: [{ name: "proposalId", type: "uint256" }, { name: "account", type: "address" }] },
  { type: "error", name: "GovernorOnlyExecutor", inputs: [{ name: "account", type: "address" }] },
  { type: "error", name: "GovernorInvalidProposalLength", inputs: [{ name: "targets", type: "uint256" }, { name: "calldatas", type: "uint256" }, { name: "values", type: "uint256" }] },
  { type: "error", name: "TimelockUnexpectedOperationState", inputs: [{ name: "operationId", type: "bytes32" }, { name: "expectedStates", type: "bytes32" }] },
];

export const GOVERNANCE_TOKEN_ABI = [
  { type: "function", name: "delegate", stateMutability: "nonpayable", inputs: [{ name: "delegatee", type: "address" }], outputs: [] },
  { type: "function", name: "balanceOf", stateMutability: "view", inputs: [{ name: "account", type: "address" }], outputs: [{ name: "", type: "uint256" }] },
  { type: "function", name: "getVotes", stateMutability: "view", inputs: [{ name: "account", type: "address" }], outputs: [{ name: "", type: "uint256" }] },
  { type: "function", name: "getPastVotes", stateMutability: "view", inputs: [{ name: "account", type: "address" }, { name: "timepoint", type: "uint256" }], outputs: [{ name: "", type: "uint256" }] },
  { type: "function", name: "delegates", stateMutability: "view", inputs: [{ name: "account", type: "address" }], outputs: [{ name: "", type: "address" }] },
  { type: "function", name: "symbol", stateMutability: "view", inputs: [], outputs: [{ name: "", type: "string" }] },
  { type: "function", name: "decimals", stateMutability: "view", inputs: [], outputs: [{ name: "", type: "uint8" }] },
  { type: "function", name: "totalSupply", stateMutability: "view", inputs: [], outputs: [{ name: "", type: "uint256" }] },
  { type: "event", name: "Transfer", inputs: [{ name: "from", type: "address", indexed: true }, { name: "to", type: "address", indexed: true }, { name: "value", type: "uint256", indexed: false }] },
  { type: "event", name: "DelegateChanged", inputs: [{ name: "delegator", type: "address", indexed: true }, { name: "fromDelegate", type: "address", indexed: true }, { name: "toDelegate", type: "address", indexed: true }] },
  { type: "event", name: "DelegateVotesChanged", inputs: [{ name: "delegate", type: "address", indexed: true }, { name: "previousBalance", type: "uint256", indexed: false }, { name: "newBalance", type: "uint256", indexed: false }] },
  // OZ v5 ERC20 error, so viem can decode the few revert paths delegate() has.
  { type: "error", name: "ERC20InvalidReceiver", inputs: [{ name: "receiver", type: "address" }] },
];

export const TREASURY_ABI = [
  { type: "function", name: "execute", stateMutability: "nonpayable", inputs: [{ name: "to", type: "address" }, { name: "amount", type: "uint256" }], outputs: [] },
  { type: "function", name: "getBalance", stateMutability: "view", inputs: [], outputs: [{ name: "", type: "uint256" }] },
  { type: "function", name: "timelock", stateMutability: "view", inputs: [], outputs: [{ name: "", type: "address" }] },
  { type: "event", name: "TreasuryPaymentExecuted", inputs: [{ name: "to", type: "address", indexed: true }, { name: "amount", type: "uint256", indexed: false }] },
  { type: "error", name: "Treasury__OnlyTimelock", inputs: [{ name: "caller", type: "address" }, { name: "timelock", type: "address" }] },
  { type: "error", name: "Treasury__ExecutionFailed", inputs: [{ name: "to", type: "address" }, { name: "amount", type: "uint256" }] },
];

// ProposalState enum from OZ Governor, by uint8 value.
export const PROPOSAL_STATES = [
  "Pending",
  "Active",
  "Canceled",
  "Defeated",
  "Succeeded",
  "Queued",
  "Expired",
  "Executed",
];

// GovernorCountingSimple ordering (confirmed in src/GovernorContract.sol).
export const SUPPORT = { AGAINST: 0, FOR: 1, ABSTAIN: 2 };
