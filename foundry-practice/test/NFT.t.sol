// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

// Import library pengujian Foundry
import "forge-std/Test.sol";
import "../src/NFT.sol";

contract NFTTest is Test {

    AldiNFT nft;

    // Membuat alamat dompet simulasi untuk testing
    address alice = makeAddr("alice");
    address bob   = makeAddr("bob");

    // Contoh link metadata (URI) — biasanya mengarah ke IPFS
    string constant URI_1 = "ipfs://QmHash1/metadata.json";
    string constant URI_2 = "ipfs://QmHash2/metadata.json";

    /**
     * @dev Fungsi setUp dijalankan SEBELUM setiap fungsi test lainnya.
     * Digunakan untuk menginisialisasi kondisi awal.
     */
    function setUp() public {
        // Deploy kontrak NFT baru:
        // Nama: AldiNFT, Simbol: ALDI, MaxSupply: 100, Harga: 0.01 ETH, Max 3 NFT per dompet
        nft = new AldiNFT("AldiNFT", "ALDI", 100, 0.01 ether, 3);

        // vm.deal: Cheatcode Foundry untuk memberikan saldo ETH palsu ke alamat tertentu
        vm.deal(alice, 1 ether);
        vm.deal(bob,   1 ether);
    }

    /**
     * @dev Memverifikasi apakah status awal kontrak setelah dideploy sudah benar.
     */
    function test_InitialState() public view {
        assertEq(nft.name(),            "AldiNFT");
        assertEq(nft.symbol(),          "ALDI");
        assertEq(nft.maxSupply(),       100);
        assertEq(nft.mintPrice(),       0.01 ether);
        assertEq(nft.totalSupply(),     0);
        assertEq(nft.remainingSupply(), 100);
    }

    /**
     * @dev Menguji proses pencetakan (minting) NFT yang berhasil.
     */
    function test_Mint() public {
        // vm.prank: Transaksi berikutnya akan dianggap berasal dari Alice
        vm.prank(alice);
        nft.mint{value: 0.01 ether}(URI_1);

        assertEq(nft.totalSupply(),      1);       // Total supply jadi 1
        assertEq(nft.ownerOf(1),         alice);   // NFT ID #1 harus milik Alice
        assertEq(nft.tokenURI(1),        URI_1);   // URI harus sesuai
        assertEq(nft.mintedCount(alice), 1);       // Alice sudah mint 1 kali
        assertEq(nft.balanceOf(alice),   1);       // Saldo NFT Alice harus 1
    }

    /**
     * @dev Menguji fitur refund otomatis jika user membayar lebih dari harga mint.
     */
    function test_Mint_RefundExcess() public {
        uint256 balanceBefore = alice.balance;

        vm.prank(alice);
        // Alice membayar 0.05 ETH (padahal harga hanya 0.01 ETH)
        nft.mint{value: 0.05 ether}(URI_1);

        // Hanya 0.01 yang benar-benar terpakai, sisanya (0.04) harus kembali ke Alice
        assertEq(alice.balance, balanceBefore - 0.01 ether);
    }

    /**
     * @dev Memastikan transaksi gagal jika ETH yang dikirim kurang dari harga mint.
     */
    function test_Mint_RevertIfInsufficientPayment() public {
        vm.prank(alice);
        // vm.expectRevert: Menandakan bahwa transaksi di bawah ini HARUS GAGAL dengan error tertentu
        vm.expectRevert(
            abi.encodeWithSelector(
                AldiNFT.InsufficientPayment.selector,
                0.005 ether,
                0.01 ether
            )
        );
        nft.mint{value: 0.005 ether}(URI_1);
    }

    /**
     * @dev Menguji batas maksimal pencetakan per dompet (maxPerWallet).
     */
    function test_Mint_RevertIfExceedsMaxPerWallet() public {
        // vm.startPrank: Semua transaksi berikutnya dari Alice sampai stopPrank dipanggil
        vm.startPrank(alice);
        nft.mint{value: 0.01 ether}(URI_1);
        nft.mint{value: 0.01 ether}(URI_2);
        nft.mint{value: 0.01 ether}("ipfs://QmHash3/metadata.json");

        // Pencetakan ke-4 harus gagal karena batasnya hanya 3 per dompet
        vm.expectRevert(
            abi.encodeWithSelector(
                AldiNFT.ExceedsMaxPerWallet.selector,
                alice,
                3,
                3
            )
        );
        nft.mint{value: 0.01 ether}("ipfs://QmHash4/metadata.json");
        vm.stopPrank();
    }

    /**
     * @dev Menguji pencetakan gratis oleh Owner (reserved supply/airdrop).
     */
    function test_OwnerMint() public {
        // Kontrak ini (Test contract) adalah owner, jadi bisa memanggil ownerMint
        nft.ownerMint(bob, URI_1);
        assertEq(nft.ownerOf(1), bob);
        assertEq(nft.totalSupply(), 1);
    }

    /**
     * @dev Menguji fungsi pembantu untuk mendapatkan semua Token ID milik owner tertentu.
     */
    function test_TokensOfOwner() public {
        vm.startPrank(alice);
        nft.mint{value: 0.01 ether}(URI_1);
        nft.mint{value: 0.01 ether}(URI_2);
        vm.stopPrank();

        uint256[] memory tokens = nft.tokensOfOwner(alice);
        assertEq(tokens.length, 2);
        assertEq(tokens[0], 1);
        assertEq(tokens[1], 2);
    }

    /**
     * @dev Menguji fitur Pause/Unpause (darurat).
     */
    function test_Pause() public {
        nft.pause();

        vm.prank(alice);
        vm.expectRevert(); // Saat di-pause, publik dilarang mint
        nft.mint{value: 0.01 ether}(URI_1);

        nft.unpause();

        vm.prank(alice);
        nft.mint{value: 0.01 ether}(URI_1);
        assertEq(nft.totalSupply(), 1);
    }

    /**
     * @dev Menguji penarikan dana hasil penjualan NFT oleh owner.
     */
    function test_Withdraw() public {
        // Alice melakukan mint agar kontrak memiliki saldo ETH
        vm.prank(alice);
        nft.mint{value: 0.01 ether}(URI_1);

        uint256 ownerBalanceBefore = address(this).balance;
        nft.withdraw();

        // Saldo owner harus bertambah sebesar harga mint tadi
        assertEq(address(this).balance, ownerBalanceBefore + 0.01 ether);
    }

    /**
     * @dev Fungsi receive diperlukan agar kontrak test ini bisa menerima ETH dari withdraw.
     */
    receive() external payable {}
}
