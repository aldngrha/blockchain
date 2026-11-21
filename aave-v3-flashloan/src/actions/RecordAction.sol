// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IFlashLoanAction} from "../interfaces/IFlashLoanAction.sol";

/// @title RecordAction
/// @notice Action minimal: mencatat dana yang terlihat di receiver saat callback.
/// @dev Dipakai untuk membuktikan dua hal tanpa strategi apa pun:
///      1. dana memang sudah ada di receiver sebelum action dipanggil,
///      2. premium harus dibayar dari saldo sendiri, karena action ini tidak menghasilkan apa pun.
contract RecordAction is IFlashLoanAction {
    event ActionExecuted(address indexed asset, uint256 amount, uint256 balanceInCallback, bytes params);

    uint256 public callCount;
    uint256 public lastAmount;
    uint256 public lastBalanceInCallback;
    bytes public lastParams;

    function onFlashLoan(address asset, uint256 amount, bytes calldata params) external {
        callCount += 1;
        lastAmount = amount;
        // msg.sender adalah receiver, jadi ini saldo receiver di dalam callback.
        lastBalanceInCallback = IERC20(asset).balanceOf(msg.sender);
        lastParams = params;

        emit ActionExecuted(asset, amount, lastBalanceInCallback, params);
    }
}
