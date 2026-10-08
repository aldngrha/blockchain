// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

// Import standar industri dari OpenZeppelin
// ERC721URIStorage: Standar NFT yang mendukung penyimpanan link metadata (IPFS/URL) per token ID
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title AldiNFT
 * @dev Kontrak Smart NFT dengan fitur batasan supply, harga cetak (minting),
 * pembatasan jumlah per dompet, dan fitur darurat (pause).
 */
contract AldiNFT is ERC721URIStorage, Ownable, Pausable {

    // --- State Variables (Data Permanen di Blockchain) ---
    uint256 public totalSupply;   // Melacak jumlah NFT yang sudah dicetak (dimulai dari 0)
    uint256 public maxSupply;     // Batas maksimal NFT yang boleh dicetak seumur hidup
    uint256 public mintPrice;     // Harga (dalam Wei) untuk mencetak 1 NFT

    // Mapping untuk melacak berapa banyak NFT yang sudah dicetak oleh setiap alamat dompet
    mapping(address => uint256) public mintedCount;
    uint256 public maxPerWallet;  // Batas maksimal NFT per dompet (mencegah monopoli)

    // Event untuk memberikan notifikasi ke sistem luar (Frontend/Backend) saat NFT dicetak
    event NFTMinted(address indexed to, uint256 indexed tokenId, string tokenURI);

    // Custom Error: Jauh lebih hemat Gas dibandingkan menggunakan pesan teks di 'require'
    error ExceedsMaxSupply(uint256 requested, uint256 remaining);
    error ExceedsMaxPerWallet(address minter, uint256 count, uint256 max);
    error InsufficientPayment(uint256 sent, uint256 required);
    error TokenNotFound(uint256 tokenId);

    /**
     * @dev Inisialisasi kontrak saat deployment.
     */
    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _maxSupply,
        uint256 _mintPrice,
        uint256 _maxPerWallet
    )
        ERC721(_name, _symbol)
        Ownable(msg.sender)
    {
        maxSupply     = _maxSupply;
        mintPrice     = _mintPrice;
        maxPerWallet  = _maxPerWallet;
    }

    // ── Bagian Pencetakan (Mint) ──────────────────────────────────────────

    /**
     * @dev Fungsi utama bagi publik untuk membeli dan mencetak NFT.
     * @param _tokenURI Link metadata (biasanya alamat IPFS) untuk gambar/atribut NFT.
     */
    function mint(string memory _tokenURI)
        public
        payable        // Wajib 'payable' agar fungsi bisa menerima transfer ETH
        whenNotPaused  // Hanya bisa jalan jika kontrak tidak sedang dihentikan (pause)
    {
        // 1. Validasi: Cek apakah stok NFT masih tersedia
        if (totalSupply + 1 > maxSupply) {
            revert ExceedsMaxSupply(1, maxSupply - totalSupply);
        }

        // 2. Validasi: Cek apakah user sudah mencapai batas mint per dompet
        if (mintedCount[msg.sender] + 1 > maxPerWallet) {
            revert ExceedsMaxPerWallet(msg.sender, mintedCount[msg.sender], maxPerWallet);
        }

        // 3. Validasi: Cek apakah pembayaran (msg.value) sudah cukup
        if (msg.value < mintPrice) {
            revert InsufficientPayment(msg.value, mintPrice);
        }

        // 4. Logika Update State
        uint256 newTokenId = ++totalSupply; // Token ID naik otomatis
        mintedCount[msg.sender]++;

        // 5. Eksekusi Minting dari OpenZeppelin
        _safeMint(msg.sender, newTokenId);
        _setTokenURI(newTokenId, _tokenURI); // Menghubungkan ID dengan metadata

        emit NFTMinted(msg.sender, newTokenId, _tokenURI);

        // 6. Logika Refund (Pengembalian)
        // Jika pembayar mengirim ETH lebih, sisanya dikembalikan secara otomatis.
        if (msg.value > mintPrice) {
          // Menggunakan pola .call{} (Standar keamanan modern)
          (bool refundSuccess, ) = payable(msg.sender).call{value: msg.value - mintPrice}("");
          require(refundSuccess, "Refund failed");
        }
    }

    /**
     * @dev Fungsi bagi Owner untuk mencetak NFT secara gratis (misal: Airdrop).
     */
    function ownerMint(address _to, string memory _tokenURI)
        public
        onlyOwner
    {
        if (totalSupply + 1 > maxSupply) {
            revert ExceedsMaxSupply(1, maxSupply - totalSupply);
        }

        uint256 newTokenId = ++totalSupply;
        _safeMint(_to, newTokenId);
        _setTokenURI(newTokenId, _tokenURI);

        emit NFTMinted(_to, newTokenId, _tokenURI);
    }

    // ── Bagian Admin ─────────────────────────────────────────

    // Fungsi darurat untuk menghentikan semua aktivitas transfer/mint
    function pause()   public onlyOwner { _pause(); }
    function unpause() public onlyOwner { _unpause(); }

    function setMintPrice(uint256 _newPrice) public onlyOwner {
        mintPrice = _newPrice;
    }

    /**
     * @dev Menarik semua ETH yang terkumpul di dalam kontrak ke dompet Owner.
     */
    function withdraw() public onlyOwner {
      // address(this).balance = mengambil seluruh saldo kontrak saat ini
      (bool success, ) = payable(owner()).call{value: address(this).balance}("");
      require(success, "Withdraw failed");
    }

    // ── Bagian View (Hanya Baca) ─────────────────────────────────────────

    function remainingSupply() public view returns (uint256) {
        return maxSupply - totalSupply;
    }

    /**
     * @dev Mencari semua Token ID yang dimiliki oleh sebuah alamat dompet.
     * Berguna untuk integrasi Frontend (menampilkan galeri NFT milik user).
     */
    function tokensOfOwner(address _owner)
        public
        view
        returns (uint256[] memory)
    {
        uint256 count = balanceOf(_owner);
        uint256[] memory tokenIds = new uint256[](count);
        uint256 index = 0;

        // Looping untuk memfilter semua token yang ada di sirkulasi
        for (uint256 i = 1; i <= totalSupply; i++) {
            // _ownerOf: Fungsi internal OZ untuk cek pemilik token ID tertentu
            if (_ownerOf(i) == _owner) {
                tokenIds[index] = i;
                index++;
            }
        }
        return tokenIds;
    }

    // ── Override (Wajib) ──────────────────────────────────────

    /**
     * @dev Fungsi internal yang dipanggil setiap kali ada perpindahan token.
     * Kita override agar fitur 'pause' (whenNotPaused) berfungsi pada setiap transfer.
     */
    function _update(
        address to,
        uint256 tokenId,
        address auth
    ) internal override whenNotPaused returns (address) {
        return super._update(to, tokenId, auth);
    }
}
