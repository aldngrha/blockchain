// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {FlashLoanReceiver} from "../src/FlashLoanReceiver.sol";
import {RecordAction} from "../src/actions/RecordAction.sol";
import {MintProfitAction} from "../src/actions/MintProfitAction.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {MockPool} from "./mocks/MockPool.sol";

contract FlashLoanReceiverTest is Test {
    MockERC20 usdc;
    MockPool pool;
    FlashLoanReceiver receiver;
    RecordAction recordAction;
    MintProfitAction profitAction;

    address alice = address(0xA11CE);
    uint256 constant AMOUNT = 1_000e6;
    uint256 constant PREMIUM_BPS = 5;

    function setUp() public {
        usdc = new MockERC20("USD Coin", "USDC", 6);
        pool = new MockPool(PREMIUM_BPS);
        receiver = new FlashLoanReceiver(address(pool), address(this));
        recordAction = new RecordAction();
        // 0,1% profit, dua kali premium 0,05%.
        profitAction = new MintProfitAction(10);

        receiver.setActionAllowed(address(recordAction), true);
        receiver.setActionAllowed(address(profitAction), true);

        usdc.mint(address(pool), 10_000_000e6);
    }

    function _premium(uint256 amount) internal pure returns (uint256) {
        return (amount * PREMIUM_BPS) / 10_000;
    }

    function test_FlashLoan_HappyPath() public {
        uint256 premium = _premium(AMOUNT);
        usdc.mint(address(receiver), 5e6);

        uint256 poolBefore = usdc.balanceOf(address(pool));

        receiver.requestFlashLoan(address(usdc), AMOUNT, address(recordAction), hex"c0ffee");

        assertEq(receiver.lastAmount(), AMOUNT, "amount tercatat");
        assertEq(receiver.lastPremium(), premium, "premium 0,05%");
        assertEq(usdc.balanceOf(address(pool)), poolBefore + premium, "pool dapat premium saja");
        assertEq(usdc.balanceOf(address(receiver)), 5e6 - premium, "premium dipotong dari saldo sendiri");

        assertEq(recordAction.callCount(), 1);
        assertEq(recordAction.lastAmount(), AMOUNT);
        assertEq(recordAction.lastBalanceInCallback(), AMOUNT + 5e6, "dana sudah ada sebelum action");
        assertEq(recordAction.lastParams(), hex"c0ffee");

        assertEq(usdc.allowance(address(receiver), address(pool)), 0, "allowance habis terpakai");
    }

    function test_FlashLoan_PremiumCoveredByActionProfit() public {
        // Tanpa saldo awal. Profit action 0,1% lebih besar dari premium 0,05%.
        receiver.requestFlashLoan(address(usdc), AMOUNT, address(profitAction), "");

        uint256 profit = (AMOUNT * 10) / 10_000;
        uint256 premium = _premium(AMOUNT);

        assertEq(usdc.balanceOf(address(receiver)), profit - premium, "sisa profit setelah premium");
    }

    function test_FlashLoan_SecondLoanInARow() public {
        usdc.mint(address(receiver), 5e6);
        receiver.requestFlashLoan(address(usdc), AMOUNT, address(recordAction), "");
        receiver.requestFlashLoan(address(usdc), AMOUNT, address(recordAction), "");

        assertEq(recordAction.callCount(), 2);
        assertEq(usdc.allowance(address(receiver), address(pool)), 0);
        assertEq(usdc.balanceOf(address(receiver)), 5e6 - 2 * _premium(AMOUNT), "dua premium terpotong");
    }

    function test_RevertWhen_ActionNotAllowed() public {
        address stranger = address(0xBEEF);
        vm.expectRevert(abi.encodeWithSelector(FlashLoanReceiver.ActionNotAllowed.selector, stranger));
        receiver.requestFlashLoan(address(usdc), AMOUNT, stranger, "");
    }

    function test_RevertWhen_CallerIsNotOwner() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        receiver.requestFlashLoan(address(usdc), AMOUNT, address(recordAction), "");
    }

    function test_RevertWhen_ExecuteOperationCalledByNonPool() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(FlashLoanReceiver.NotPool.selector, alice));
        receiver.executeOperation(address(usdc), AMOUNT, 0, address(receiver), abi.encode(address(recordAction), ""));
    }

    function test_RevertWhen_InitiatorIsNotSelf() public {
        // Walaupun pemanggilnya Pool, pinjaman yang dimulai pihak lain harus ditolak.
        vm.prank(address(pool));
        vm.expectRevert(abi.encodeWithSelector(FlashLoanReceiver.NotSelfInitiated.selector, alice));
        receiver.executeOperation(address(usdc), AMOUNT, 0, alice, abi.encode(address(recordAction), ""));
    }

    function test_RevertWhen_RepaymentIsShort_andNothingChanges() public {
        uint256 premium = _premium(AMOUNT);
        uint256 poolBefore = usdc.balanceOf(address(pool));
        uint256 receiverBefore = usdc.balanceOf(address(receiver));

        // Tanpa saldo awal dan tanpa profit: dana pinjaman tidak cukup untuk amount + premium.
        vm.expectRevert(
            abi.encodeWithSelector(FlashLoanReceiver.InsufficientRepayment.selector, AMOUNT, AMOUNT + premium)
        );
        receiver.requestFlashLoan(address(usdc), AMOUNT, address(recordAction), "");

        assertEq(usdc.balanceOf(address(pool)), poolBefore, "pool utuh setelah revert");
        assertEq(usdc.balanceOf(address(receiver)), receiverBefore, "receiver utuh setelah revert");
        assertEq(recordAction.callCount(), 0, "efek action dibatalkan");
        assertEq(receiver.lastAmount(), 0);
    }

    function testFuzz_PremiumIsPriceOfLoan(uint256 amount, uint256 bps) public {
        amount = bound(amount, 1, 1_000_000e6);
        bps = bound(bps, 0, 100);
        pool.setPremiumBps(bps);

        uint256 premium = (amount * bps) / 10_000;
        usdc.mint(address(receiver), premium);
        uint256 poolBefore = usdc.balanceOf(address(pool));

        receiver.requestFlashLoan(address(usdc), amount, address(recordAction), "");

        assertEq(receiver.lastPremium(), premium);
        assertEq(usdc.balanceOf(address(pool)) - poolBefore, premium);
        assertEq(usdc.balanceOf(address(receiver)), 0);
    }

    function test_SweepIsOwnerOnly() public {
        usdc.mint(address(receiver), 1e6);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        receiver.sweep(address(usdc), alice, 1e6);

        receiver.sweep(address(usdc), alice, 1e6);
        assertEq(usdc.balanceOf(alice), 1e6);
    }
}
