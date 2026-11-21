// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {FlashLoanReceiver} from "../src/FlashLoanReceiver.sol";
import {RecordAction} from "../src/actions/RecordAction.sol";
import {IPool} from "../src/interfaces/IPool.sol";

interface IAToken {
    function UNDERLYING_ASSET_ADDRESS() external view returns (address);
    function POOL() external view returns (address);
}

/// @title ForkFlashLoanTest
/// @notice Flash loan sungguhan dari Pool Aave v3 di Ethereum mainnet, lewat fork.
/// @dev Jalankan dengan RPC:
///      FORK_RPC_URL=https://ethereum-rpc.publicnode.com forge test --match-path test/ForkFlashLoan.t.sol -vv
///      Tanpa FORK_RPC_URL, test di kontrak ini di-skip supaya `forge test` biasa tetap jalan offline.
contract ForkFlashLoanTest is Test {
    // Alamat mainnet, bukan karangan. Semuanya dicek ulang di setUp.
    address constant POOL = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant A_USDC = 0x98C23E9d8f34FEFb1B7BD6a91B7FF122F4e16F5c;

    uint256 constant AMOUNT = 1_000e6; // 1.000 USDC

    FlashLoanReceiver receiver;
    RecordAction action;
    uint256 premium;

    function setUp() public {
        string memory rpc = vm.envOr("FORK_RPC_URL", string(""));
        if (bytes(rpc).length == 0) {
            vm.skip(true);
            return;
        }

        vm.createSelectFork(rpc);

        assertGt(POOL.code.length, 0, "Pool Aave tidak ada di fork ini");
        assertGt(USDC.code.length, 0, "USDC tidak ada di fork ini");
        assertEq(IAToken(A_USDC).UNDERLYING_ASSET_ADDRESS(), USDC, "aToken bukan untuk USDC");
        assertEq(IAToken(A_USDC).POOL(), POOL, "aToken bukan milik Pool ini");

        receiver = new FlashLoanReceiver(POOL, address(this));
        action = new RecordAction();
        receiver.setActionAllowed(address(action), true);

        // Premium dibaca dari pool, bukan di-hardcode: governance bisa mengubahnya.
        premium = (AMOUNT * IPool(POOL).FLASHLOAN_PREMIUM_TOTAL()) / 10_000;
    }

    function test_Fork_RealFlashLoanFromAaveV3() public {
        // Premium wajib ada sebelum transaksi. Di strategi nyata ini datang dari profit.
        deal(USDC, address(receiver), premium + 1);

        uint256 aTokenBefore = IERC20(USDC).balanceOf(A_USDC);
        uint256 poolBefore = IERC20(USDC).balanceOf(POOL);

        receiver.requestFlashLoan(USDC, AMOUNT, address(action), "halo dari fork");

        assertEq(receiver.lastAmount(), AMOUNT, "amount dari callback Aave");
        assertEq(receiver.lastPremium(), premium, "premium sama dengan yang dihitung pool");
        assertEq(action.lastBalanceInCallback(), AMOUNT + premium + 1, "dana terlihat di callback");
        assertEq(IERC20(USDC).balanceOf(address(receiver)), 1, "sisa saldo receiver");

        // Temuan dari fork: underlying USDC di Aave v3 dipegang kontrak aToken, bukan Pool.
        // Jadi premium menambah saldo aUSDC (milik supplier), dan saldo Pool tidak bergerak.
        assertEq(IERC20(USDC).balanceOf(A_USDC) - aTokenBefore, premium, "premium tinggal di aToken");
        assertEq(IERC20(USDC).balanceOf(POOL), poolBefore, "saldo USDC Pool tidak berubah");

        // 1.000 USDC dengan premium 5 bps = 0,5 USDC.
        assertEq(premium, 500_000, "0,05% dari 1.000 USDC");
    }

    function test_Fork_RevertsWhenPremiumCannotBePaid() public {
        uint256 aTokenBefore = IERC20(USDC).balanceOf(A_USDC);

        // Tanpa saldo dan tanpa profit, receiver tidak bisa membayar amount + premium.
        vm.expectRevert();
        receiver.requestFlashLoan(USDC, AMOUNT, address(action), "");

        assertEq(IERC20(USDC).balanceOf(A_USDC), aTokenBefore, "tidak ada dana supplier yang hilang");
        assertEq(IERC20(USDC).balanceOf(address(receiver)), 0);
        assertEq(action.callCount(), 0, "seluruh transaksi dibatalkan");
    }
}
