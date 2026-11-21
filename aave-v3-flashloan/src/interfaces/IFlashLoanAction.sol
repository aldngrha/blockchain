// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IFlashLoanAction {
    /// @notice Dipanggil di dalam callback flash loan, saat dana sudah ada di receiver.
    /// @dev Tidak boleh mengasumsikan msg.sender adalah user. msg.sender adalah receiver.
    function onFlashLoan(address asset, uint256 amount, bytes calldata params) external;
}
