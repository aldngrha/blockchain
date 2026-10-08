// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

// import testing framework bawaan Foundry (Test.sol)
import {Test} from "forge-std/Test.sol";
// import kontrak yang mau dites
import {ERC20} from "../src/ERC20.sol";

contract ERC20Test is Test {

    ERC20 token;

    // makeAddr() membuat alamat dompet palsu secara otomatis
    address alice = makeAddr("alice");
    address bob   = makeAddr("bob");
    address carol = makeAddr("carol");

    /**
     * @dev setUp() dipanggil OTOMATIS sebelum setiap unit test dimulai.
     * Ini menjamin setiap tes punya kondisi awal yang bersih.
     */
    function setUp() public {
        // Deploy token dengan supply awal 1000 koin
        token = new ERC20("AldiToken", "ALDI", 1000);

        // Kasih Alice 100 koin di awal
        // Kita gunakan assertTrue() karena transfer ERC20 mengembalikan 'bool'
        assertTrue(token.transfer(alice, 100 * 10 ** 18));
    }

    // --- Unit Tests (Nama fungsi harus diawali 'test') ---

    function test_InitialSupply() public view {
        // Cek apakah total supply benar (1000 * 10^18)
        assertEq(token.totalSupply(), 1000 * 10 ** 18);
    }

    function test_NameAndSymbol() public view {
        assertEq(token.name(), "AldiToken");
        assertEq(token.symbol(), "ALDI");
    }

    function test_Transfer() public {
        // --- Langkah 1: Pura-pura jadi Alice ---
        // vm.prank(address) membuat transaksi selanjutnya dikirim oleh address tsb
        vm.prank(alice);

        // Alice kirim 50 koin ke Bob
        assertTrue(token.transfer(bob, 50 * 10 ** 18));

        // --- Langkah 2: Verifikasi ---
        assertEq(token.balanceOf(alice), 50 * 10 ** 18);
        assertEq(token.balanceOf(bob),   50 * 10 ** 18);
    }

    function test_Transfer_RevertIfInsufficientBalance() public {
        // --- Skenario: Alice coba kirim lebih dari yang dia punya (100) ---
        vm.prank(alice);

        // vm.expectRevert() memberitahu Foundry bahwa transaksi selanjutnya HARUS GAGAL
        // Jika gagal, tes ini justru LULUS.
        vm.expectRevert(
            abi.encodeWithSelector(
                ERC20.InsufficientBalance.selector,
                100 * 10 ** 18,  // Saldo yang dimiliki Alice
                200 * 10 ** 18   // Saldo yang mau dikirim
            )
        );

        // Trik Silencer: Karena ini revert, kita tangkap ke variabel tapi jangan di-assert
        // supaya linter tidak marah, tapi logika revert Foundry tetap jalan.
        bool success = token.transfer(bob, 200 * 10 ** 18);
        success;
    }

    function test_Approve_And_TransferFrom() public {
        // 1. Alice beri izin ke Bob (50 koin)
        vm.prank(alice);
        token.approve(bob, 50 * 10 ** 18);

        assertEq(token.allowance(alice, bob), 50 * 10 ** 18);

        // 2. Bob (sebagai spender) kirim koin Alice ke Carol
        vm.prank(bob);
        assertTrue(token.transferFrom(alice, carol, 30 * 10 ** 18));

        assertEq(token.balanceOf(carol),      30 * 10 ** 18);
        assertEq(token.allowance(alice, bob), 20 * 10 ** 18); // Sisa izin berkurang
    }

    function test_TransferFrom_RevertIfInsufficientAllowance() public {
        // 1. Alice cuma kasih izin 10 koin
        vm.prank(alice);
        token.approve(bob, 10 * 10 ** 18);

        // 2. Bob maksa mau ambil 50 koin
        vm.prank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(
                ERC20.InsufficientAllowance.selector,
                10 * 10 ** 18,
                50 * 10 ** 18
            )
        );
        bool success = token.transferFrom(alice, carol, 50 * 10 ** 18);
        success;
    }

    function test_Mint_OnlyOwner() public {
        // Owner (kita/test contract) bisa cetak koin baru
        token.mint(bob, 500 * 10 ** 18);
        assertEq(token.balanceOf(bob), 500 * 10 ** 18);

        // Alice (Bukan owner) dilarang cetak koin
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                ERC20.NotOwner.selector,
                alice
            )
        );
        token.mint(bob, 100 * 10 ** 18);
    }

    function test_Burn() public {
        uint256 balanceBefore = token.balanceOf(alice);

        // Alice musnahkan 50 koin miliknya
        vm.prank(alice);
        token.burn(50 * 10 ** 18);

        assertEq(token.balanceOf(alice), balanceBefore - 50 * 10 ** 18);
    }

    function test_Transfer_EmitsEvent() public {
        // vm.expectEmit() mengecek apakah Event di-emit dengan benar
        // Parameter (true, true, false, true) = Cek index1, index2, index3, data
        vm.expectEmit(true, true, false, true);
        emit ERC20.Transfer(alice, bob, 10 * 10 ** 18);

        vm.prank(alice);
        assertTrue(token.transfer(bob, 10 * 10 ** 18));
    }
}
