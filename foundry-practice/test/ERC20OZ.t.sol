// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "../src/ERC20OZ.sol";

contract ERC20OZTest is Test {

    AldiToken token;

    // Alamat dompet simulasi
    address alice = makeAddr("alice");
    address bob   = makeAddr("bob");

    /**
     * @dev Inisialisasi kontrak sebelum setiap pengujian.
     */
    function setUp() public {
        // Param: Nama, Simbol, InitialSupply (1000), MaxSupply (10000)
        token = new AldiToken("AldiToken", "ALDI", 1000, 10000);

        // Kasih modal awal ke Alice 100 token
        token.transfer(alice, 100 * 10 ** 18);
    }

    /**
     * @dev Memastikan data awal (state) benar.
     */
    function test_InitialState() public view {
        assertEq(token.name(),        "AldiToken");
        assertEq(token.symbol(),      "ALDI");
        assertEq(token.decimals(),    18);
        assertEq(token.totalSupply(), 1000 * 10 ** 18);
        assertEq(token.maxSupply(),   10000 * 10 ** 18);
    }

    /**
     * @dev Tes pengiriman token antar user.
     */
    function test_Transfer() public {
        vm.prank(alice); // Transaksi berikutnya dari Alice
        token.transfer(bob, 50 * 10 ** 18);

        assertEq(token.balanceOf(alice), 50 * 10 ** 18);
        assertEq(token.balanceOf(bob),   50 * 10 ** 18);
    }

    /**
     * @dev Tes hak akses pencetakan koin (Hanya Owner).
     */
    function test_Mint_OnlyOwner() public {
        // Mint oleh Owner (sukses)
        token.mint(bob, 500 * 10 ** 18);
        assertEq(token.balanceOf(bob), 500 * 10 ** 18);

        // Mint oleh Alice (harus gagal/revert)
        vm.prank(alice);
        vm.expectRevert(); // Kita mengharapkan error OwnableUnauthorizedAccount
        token.mint(bob, 100 * 10 ** 18);
    }

    /**
     * @dev Tes pembatasan Max Supply.
     */
    function test_Mint_ExceedsMaxSupply() public {
        // Mencoba mint 9001, padahal sisa jatah cuma 9000 (10000 - 1000)
        vm.expectRevert(
            abi.encodeWithSelector(
                AldiToken.ExceedsMaxSupply.selector,
                9001 * 10 ** 18,
                9000 * 10 ** 18
            )
        );
        token.mint(bob, 9001 * 10 ** 18);
    }

    /**
     * @dev Tes fitur Jeda (Pause). Saat jeda, transfer dilarang.
     */
    function test_Pause() public {
        token.pause();

        // Transfer saat pause harus gagal
        vm.prank(alice);
        vm.expectRevert();
        token.transfer(bob, 10 * 10 ** 18);

        token.unpause();

        // Setelah unpause, transfer harus sukses lagi
        vm.prank(alice);
        token.transfer(bob, 10 * 10 ** 18);
        assertEq(token.balanceOf(bob), 10 * 10 ** 18);
    }

    /**
     * @dev Tes fitur pembakaran token (Burn).
     */
    function test_Burn() public {
        vm.prank(alice);
        token.burn(50 * 10 ** 18);

        assertEq(token.balanceOf(alice), 50 * 10 ** 18);
        assertEq(token.totalSupply(),    950 * 10 ** 18); // Total koin berkurang
    }

    /**
     * @dev Tes memperbarui batas maksimal supply.
     */
    function test_UpdateMaxSupply() public {
        // Naikkan jadi 20000
        token.updateMaxSupply(20000);
        assertEq(token.maxSupply(), 20000 * 10 ** 18);

        // Tidak boleh set di bawah total yang sudah ada (1000)
        vm.expectRevert("Below current supply");
        token.updateMaxSupply(500);
    }
}
