// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "../../src/patterns/AccessControl.sol";
import "@openzeppelin/contracts/access/IAccessControl.sol";

/**
 * @title TokenWithRolesTest
 * @dev Kumpulan skenario pengujian untuk kontrak TokenWithRoles.
 * Fokus pengujian pada integritas Role-Based Access Control (RBAC) dan pembatasan fitur.
 */
contract TokenWithRolesTest is Test {

    TokenWithRoles token;

    // Alamat-alamat simulasi untuk peran berbeda
    address admin  = address(this);
    address minter = makeAddr("minter");
    address burner = makeAddr("burner");
    address alice  = makeAddr("alice");

    /**
     * @notice Persiapan awal untuk setiap skenario tes.
     * @dev Mendeploy kontrak baru dan mengatur role awal untuk alamat minter dan burner.
     */
    function setUp() public {
        token = new TokenWithRoles(1000);

        // Memberikan role operasional ke alamat berbeda
        token.grantRole(token.MINTER_ROLE(), minter);
        token.grantRole(token.BURNER_ROLE(), burner);
    }

    /**
     * @notice Memastikan role yang diberikan saat setup sudah benar.
     */
    function test_InitialRoles() public view {
        assertTrue(token.hasRole(token.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(token.hasRole(token.MINTER_ROLE(), minter));
        assertTrue(token.hasRole(token.BURNER_ROLE(), burner));
        assertFalse(token.hasRole(token.MINTER_ROLE(), alice));
    }

    /**
     * @notice Verifikasi bahwa akun dengan MINTER_ROLE dapat mencetak token dengan sukses.
     */
    function test_Mint_WithMinterRole() public {
        vm.prank(minter);
        token.mint(alice, 100);

        assertEq(token.balances(alice), 100);
        assertEq(token.totalSupply(),   100);
    }

    /**
     * @notice Memastikan pencetakan gagal jika dilakukan oleh akun tanpa role minter.
     */
    function test_Mint_RevertIfNoRole() public {
        vm.prank(alice);
        vm.expectRevert(); // Mengharapkan revert dari modifier onlyRole
        token.mint(alice, 100);
    }

    /**
     * @notice Verifikasi bahwa akun dengan BURNER_ROLE dapat menghancurkan token dengan sukses.
     */
    function test_Burn_WithBurnerRole() public {
        vm.prank(minter);
        token.mint(alice, 100);

        vm.prank(burner);
        token.burn(alice, 50);

        assertEq(token.balances(alice), 50);
    }

    /**
     * @notice Menguji batasan delegasi role; hanya admin yang boleh memberikan role ke orang lain.
     * @dev Alice yang hanya memiliki MINTER_ROLE tidak boleh memberikan role tersebut ke orang lain.
     */
    function test_GrantRole_OnlyAdmin() public {
        bytes32 minterRole = token.MINTER_ROLE();
        bytes32 adminRole = token.DEFAULT_ADMIN_ROLE();
        
        // Admin asli memberikan akses ke Alice
        token.grantRole(minterRole, alice);
        assertTrue(token.hasRole(minterRole, alice));

        address random = makeAddr("random");
        
        // Alice mencoba memberikan akses ke orang lain (harus gagal)
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                alice,
                adminRole
            )
        );
        token.grantRole(minterRole, random);
    }

    /**
     * @notice Memastikan pencabutan role (revocation) berfungsi dan hak akses segera hilang.
     */
    function test_RevokeRole() public {
        token.revokeRole(token.MINTER_ROLE(), minter);
        assertFalse(token.hasRole(token.MINTER_ROLE(), minter));

        vm.prank(minter);
        vm.expectRevert();
        token.mint(alice, 100);
    }

    /**
     * @notice Menguji integrasi AccessControl dengan fitur Pausable.
     * @dev Memastikan minting tidak bisa dilakukan saat kontrak sedang dihentikan (pause).
     */
    function test_Pause_OnlyPauserRole() public {
        token.pause();

        vm.prank(minter);
        vm.expectRevert(); // Harusnya gagal karena status 'paused'
        token.mint(alice, 100);

        token.unpause();

        vm.prank(minter);
        token.mint(alice, 100);
        assertEq(token.balances(alice), 100);
    }
}
