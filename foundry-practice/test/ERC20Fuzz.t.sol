// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "../src/ERC20.sol";

/**
 * @title ERC20 Fuzz Testing (Full Suite - 9 Tests)
 * @dev Menggunakan input acak untuk memastikan keamanan kontrak di segala kondisi angka.
 */
contract ERC20FuzzTest is Test {
    ERC20 token;

    address owner = address(this);
    address alice = makeAddr("alice");
    address bob   = makeAddr("bob");
    address carol = makeAddr("carol");

    uint256 constant INITIAL_SUPPLY = 1_000_000; // 1 Juta

    function setUp() public {
        token = new ERC20("AldiToken", "ALDI", INITIAL_SUPPLY);
    }

    // 1. FUZZ: Transfer Berhasil
    function testFuzz_Transfer(uint256 amount) public {
        amount = bound(amount, 1, 1e30);
        token.mint(alice, amount);

        vm.prank(alice);
        assertTrue(token.transfer(bob, amount));

        assertEq(token.balanceOf(bob), amount);
        assertEq(token.balanceOf(alice), 0);
    }

    // 2. FUZZ: Revert jika Saldo Kurang
    function testFuzz_Transfer_RevertIfInsufficientBalance(uint256 balance, uint256 amount) public {
        balance = bound(balance, 0, 1e30);
        amount = bound(amount, balance + 1, type(uint256).max); // Pastikan amount > balance

        token.mint(alice, balance);

        vm.prank(alice);
        vm.expectRevert();
        token.transfer(bob, amount);
    }

    // 3. FUZZ: Approve (Izin Spender)
    function testFuzz_Approve(address spender, uint256 amount) public {
        vm.assume(spender != address(0));

        vm.prank(alice);
        assertTrue(token.approve(spender, amount));

        assertEq(token.allowance(alice, spender), amount);
    }

    // 4. FUZZ: TransferFrom (Spender mengirim koin owner)
    function testFuzz_TransferFrom(uint256 mintAmount, uint256 allowAmount, uint256 transferAmount) public {
        mintAmount = bound(mintAmount, 1, 1e30);
        allowAmount = bound(allowAmount, 0, mintAmount);
        transferAmount = bound(transferAmount, 0, allowAmount);

        token.mint(alice, mintAmount);

        vm.prank(alice);
        token.approve(bob, allowAmount);

        vm.prank(bob);
        assertTrue(token.transferFrom(alice, carol, transferAmount));

        assertEq(token.balanceOf(carol), transferAmount);
        assertEq(token.allowance(alice, bob), allowAmount - transferAmount);
    }

    // 5. FUZZ: Minting oleh Owner
    function testFuzz_Mint(uint256 amount) public {
        amount = bound(amount, 0, 1e30);
        uint256 supplyBefore = token.totalSupply();

        token.mint(alice, amount);

        assertEq(token.totalSupply(), supplyBefore + amount);
        assertEq(token.balanceOf(alice), amount);
    }

    // 6. FUZZ: Burn Berhasil (Saldo Cukup)
    function testFuzz_Burn_Success(uint256 amountToMint, uint256 amountToBurn) public {
        amountToMint = bound(amountToMint, 1, 1e30);
        amountToBurn = bound(amountToBurn, 0, amountToMint);

        token.mint(alice, amountToMint);

        vm.prank(alice);
        token.burn(amountToBurn);

        assertEq(token.balanceOf(alice), amountToMint - amountToBurn);
    }

    // 7. FUZZ: Burn Gagal (Saldo Kurang)
    function testFuzz_Burn_RevertIfInsufficient(uint256 balance, uint256 amount) public {
        balance = bound(balance, 0, 1e30);
        amount = bound(amount, balance + 1, type(uint256).max);

        token.mint(alice, balance);

        vm.prank(alice);
        vm.expectRevert();
        token.burn(amount);
    }

    // 8. FUZZ: Event Transfer Selalu Terpancar Benar
    function testFuzz_Transfer_EmitsEvent(uint256 amount) public {
        amount = bound(amount, 1, 1e30);
        token.mint(alice, amount);

        vm.expectEmit(true, true, false, true);
        emit ERC20.Transfer(alice, bob, amount);

        vm.prank(alice);
        token.transfer(bob, amount);
    }

    // 9. FUZZ: Invarian Total Supply (Hukum Kekekalan Token)
    // Berapapun yang di-mint ke dua user, Total Supply harus sama dengan jumlah saldo mereka + awal
    function testFuzz_TotalSupply_Invariant(uint256 amount1, uint256 amount2) public {
        amount1 = bound(amount1, 0, 1e30);
        amount2 = bound(amount2, 0, 1e30);

        uint256 initialTotal = token.totalSupply();

        token.mint(alice, amount1);
        token.mint(bob, amount2);

        assertEq(token.totalSupply(), initialTotal + amount1 + amount2);
        assertEq(token.balanceOf(alice) + token.balanceOf(bob), amount1 + amount2);
    }
}
