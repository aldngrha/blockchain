// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IPool {
    function flashLoanSimple(
        address receiverAddress,
        address asset,
        uint256 amount,
        bytes calldata params,
        uint16 referralCode
    ) external;

    function FLASHLOAN_PREMIUM_TOTAL() external view returns (uint128);

    function FLASHLOAN_PREMIUM_TO_PROTOCOL() external view returns (uint128);

    function ADDRESSES_PROVIDER() external view returns (address);
}
