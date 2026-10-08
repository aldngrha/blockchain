// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title Treasury - minimal ETH vault controlled by governance.
/// @notice Holds ETH. The ONLY way to move funds out is execute(), callable
///         exclusively by the TimelockController. Since the timelock only executes
///         operations scheduled by the Governor, fund outflows always go through
///         a passed proposal: propose -> vote -> queue -> timelock delay -> execute.
contract Treasury {
    /// @dev the timelock contract that governs this vault (set once, immutable).
    address public immutable timelock;

    error Treasury__OnlyTimelock(address caller, address timelock);
    error Treasury__ExecutionFailed(address to, uint256 amount);

    event TreasuryPaymentExecuted(address indexed to, uint256 amount);

    constructor(address timelock_) {
        timelock = timelock_;
    }

    /// @notice Governance (via proposal) funds the vault by sending ETH here.
    receive() external payable {}

    /// @notice Send ETH out of the vault. Only the timelock may call this.
    ///         The timelock calls it as the executor of a queued governance proposal.
    /// @param to recipient of the payout.
    /// @param amount wei to send.
    function execute(address payable to, uint256 amount) external {
        if (msg.sender != timelock) {
            revert Treasury__OnlyTimelock(msg.sender, timelock);
        }
        (bool success,) = to.call{value: amount}("");
        if (!success) {
            revert Treasury__ExecutionFailed(to, amount);
        }
        emit TreasuryPaymentExecuted(to, amount);
    }

    /// @notice Convenience for the frontend / tests.
    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }
}
