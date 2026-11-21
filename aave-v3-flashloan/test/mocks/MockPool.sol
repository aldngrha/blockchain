// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IFlashLoanSimpleReceiver} from "../../src/interfaces/IFlashLoanSimpleReceiver.sol";

/// @title MockPool
/// @notice Tiruan jalur flash loan Aave v3: kirim dana, panggil callback, tarik kembali.
/// @dev Yang ditiru cuma urutan dan pengecekan pembayarannya, bukan seluruh Pool Aave.
///      Pengecekan akhirnya sama pentingnya dengan aslinya: saldo pool setelah callback
///      harus naik minimal sebesar premium. Kalau tidak, revert dan semua efek dibatalkan.
contract MockPool {
    using SafeERC20 for IERC20;

    error NotEnoughRepaid(uint256 required, uint256 received);
    error CallbackFailed();

    event FlashLoan(address indexed receiver, address indexed asset, uint256 amount, uint256 premium);

    uint256 public premiumBps;
    uint16 public lastReferralCode;

    constructor(uint256 premiumBps_) {
        premiumBps = premiumBps_;
    }

    function setPremiumBps(uint256 bps) external {
        premiumBps = bps;
    }

    /// @dev Dipakai receiver saat deploy untuk menyimpan alamat provider.
    function ADDRESSES_PROVIDER() external view returns (address) {
        return address(this);
    }

    /// @dev Sama seperti Aave: premium dalam basis poin (5 = 0,05%).
    function FLASHLOAN_PREMIUM_TOTAL() external view returns (uint128) {
        return uint128(premiumBps);
    }

    /// @dev Mock tidak memisahkan porsi treasury, semua premium tinggal di pool.
    function FLASHLOAN_PREMIUM_TO_PROTOCOL() external pure returns (uint128) {
        return 0;
    }

    function flashLoanSimple(
        address receiver,
        address asset,
        uint256 amount,
        bytes calldata params,
        uint16 referralCode
    ) external {
        uint256 premium = (amount * premiumBps) / 10_000;
        lastReferralCode = referralCode;

        IERC20 token = IERC20(asset);
        uint256 balanceBefore = token.balanceOf(address(this));

        token.safeTransfer(receiver, amount);

        bool ok = IFlashLoanSimpleReceiver(receiver).executeOperation(asset, amount, premium, msg.sender, params);
        if (!ok) revert CallbackFailed();

        // Pool menarik kembali pinjaman plus premium, memakai allowance yang dipasang receiver.
        token.safeTransferFrom(receiver, address(this), amount + premium);

        uint256 balanceAfter = token.balanceOf(address(this));
        if (balanceAfter < balanceBefore + premium) {
            revert NotEnoughRepaid(balanceBefore + premium, balanceAfter);
        }

        emit FlashLoan(receiver, asset, amount, premium);
    }
}
