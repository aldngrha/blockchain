// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IPool} from "./interfaces/IPool.sol";
import {IFlashLoanSimpleReceiver} from "./interfaces/IFlashLoanSimpleReceiver.sol";
import {IFlashLoanAction} from "./interfaces/IFlashLoanAction.sol";

/// @title FlashLoanReceiver
/// @notice Receiver flash loan Aave v3 yang menjalankan satu action dari allowlist.
/// @dev Alurnya: owner minta pinjaman, Pool kirim dana lalu panggil executeOperation,
///      action dipanggil, lalu receiver approve Pool untuk amount + premium.
///      Premium TIDAK dibuat oleh protokol. Itu kewajiban receiver, dan sumbernya
///      harus dari profit action atau saldo sendiri. Kalau tidak cukup, seluruh
///      transaksi revert, termasuk semua langkah action sebelumnya.
contract FlashLoanReceiver is IFlashLoanSimpleReceiver, Ownable {
    using SafeERC20 for IERC20;

    error ZeroAddress();
    error NotPool(address caller);
    error NotSelfInitiated(address initiator);
    error ActionNotAllowed(address action);
    error InsufficientRepayment(uint256 available, uint256 required);

    event ActionAllowedUpdated(address indexed action, bool allowed);
    event FlashLoanExecuted(
        address indexed asset,
        uint256 amount,
        uint256 premium,
        address indexed action,
        uint256 balanceInCallback
    );
    event Swept(address indexed asset, address indexed to, uint256 amount);

    /// @notice Pool Aave v3 yang dipakai. Immutable supaya tidak bisa diganti di tengah jalan.
    address public immutable POOL;
    /// @notice PoolAddressesProvider, dibaca sekali dari Pool saat deploy.
    address public immutable ADDRESSES_PROVIDER;

    /// @notice Action yang boleh dijalankan. Default menolak semua.
    mapping(address => bool) public isActionAllowed;

    /// @notice State hasil eksekusi terakhir, untuk dibaca test dan UI.
    uint256 public lastAmount;
    uint256 public lastPremium;
    address public lastAction;

    constructor(address pool_, address owner_) Ownable(owner_) {
        if (pool_ == address(0)) revert ZeroAddress();
        POOL = pool_;
        ADDRESSES_PROVIDER = IPool(pool_).ADDRESSES_PROVIDER();
    }

    /// @notice Minta flash loan lalu jalankan `action`.
    /// @dev Sengaja onlyOwner. Receiver ini memegang dana dan allowance, jadi
    ///      siapa pun yang bisa memicunya bisa memilih action dan params.
    function requestFlashLoan(
        address asset,
        uint256 amount,
        address action,
        bytes calldata params
    ) external onlyOwner {
        if (!isActionAllowed[action]) revert ActionNotAllowed(action);
        IPool(POOL).flashLoanSimple(address(this), asset, amount, abi.encode(action, params), 0);
    }

    /// @notice Callback dari Pool. Dana sudah ditransfer ke kontrak ini sebelum fungsi ini jalan.
    function executeOperation(
        address asset,
        uint256 amount,
        uint256 premium,
        address initiator,
        bytes calldata params
    ) external returns (bool) {
        if (msg.sender != POOL) revert NotPool(msg.sender);
        if (initiator != address(this)) revert NotSelfInitiated(initiator);

        (address action, bytes memory actionParams) = abi.decode(params, (address, bytes));
        if (!isActionAllowed[action]) revert ActionNotAllowed(action);

        IFlashLoanAction(action).onFlashLoan(asset, amount, actionParams);

        uint256 required = amount + premium;
        uint256 available = IERC20(asset).balanceOf(address(this));
        if (available < required) revert InsufficientRepayment(available, required);

        // forceApprove, bukan approve: kalau ada sisa allowance dari pinjaman sebelumnya,
        // approve biasa bisa gagal karena USDC dan beberapa token mewajibkan allowance 0 dulu.
        IERC20(asset).forceApprove(POOL, required);

        lastAmount = amount;
        lastPremium = premium;
        lastAction = action;

        emit FlashLoanExecuted(asset, amount, premium, action, available);

        return true;
    }

    /// @notice Ubah allowlist action.
    function setActionAllowed(address action, bool allowed) external onlyOwner {
        if (action == address(0)) revert ZeroAddress();
        isActionAllowed[action] = allowed;
        emit ActionAllowedUpdated(action, allowed);
    }

    /// @notice Tarik sisa dana. Wajib ada, karena premium yang tidak terpakai bisa tertinggal di sini.
    function sweep(address asset, address to, uint256 amount) external onlyOwner {
        if (to == address(0)) revert ZeroAddress();
        IERC20(asset).safeTransfer(to, amount);
        emit Swept(asset, to, amount);
    }
}
