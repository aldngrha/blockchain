// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IFlashLoanAction} from "../interfaces/IFlashLoanAction.sol";

interface IMintable {
    function mint(address to, uint256 amount) external;
}

/// @title MintProfitAction
/// @notice Simulasi action yang menghasilkan profit.
/// @dev PROOF OF CONCEPT, BUKAN STRATEGI NYATA. Profit di sini dicetak lewat mint,
///      jadi hanya valid terhadap token mock di test lokal. Di mainnet profit harus
///      datang dari pasar (arbitrase, collateral swap, likuidasi), bukan dari mencetak token.
///      Tujuannya cuma satu: menguji bahwa premium bisa dibayar dari hasil action.
contract MintProfitAction is IFlashLoanAction {
    error InvalidBps();

    event ProfitMinted(address indexed asset, address indexed receiver, uint256 amount);

    uint256 public immutable PROFIT_BPS;

    constructor(uint256 profitBps_) {
        if (profitBps_ > 10_000) revert InvalidBps();
        PROFIT_BPS = profitBps_;
    }

    function onFlashLoan(address asset, uint256 amount, bytes calldata) external {
        uint256 profit = (amount * PROFIT_BPS) / 10_000;
        IMintable(asset).mint(msg.sender, profit);
        emit ProfitMinted(asset, msg.sender, profit);
    }
}
