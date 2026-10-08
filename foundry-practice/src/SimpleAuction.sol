// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

/**
 * @title SimpleAuction
 * @dev Logika lelang sederhana dengan pola 'Pull-over-Push' (penarikan dana mandiri).
 */
contract SimpleAuction {
    address public owner;
    uint256 public auctionEndTime; // Waktu berakhir (timestamp)
    bool    public ended;          // Status apakah lelang sudah selesai
    address public highestBidder;  // Pemenang sementara
    uint256 public highestBid;     // Harga tertinggi sementara

    // Menyimpan dana penawar yang kalah agar bisa mereka tarik sendiri (Withdraw).
    // Ini lebih aman daripada kontrak mengirim koin secara otomatis saat ada tawaran baru.
    mapping(address => uint256) public pendingReturns;

    event NewBid(address indexed bidder, uint256 amount);
    event AuctionEnded(address indexed winner, uint256 amount);
    event Withdrawn(address indexed bidder, uint256 amount);

    error NotOwner(address caller);
    error AuctionAlreadyEnded();
    error AuctionNotYetEnded();
    error BidTooLow(uint256 current, uint256 minimum);
    error NothingToWithdraw();
    error AuctionEndAlreadyCalled();

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner(msg.sender);
        _;
    }

    // Cek apakah waktu lelang masih aktif
    modifier auctionActive() {
        if (block.timestamp >= auctionEndTime) revert AuctionAlreadyEnded();
        if (ended) revert AuctionAlreadyEnded();
        _;
    }

    // Cek apakah lelang sudah layak ditutup
    modifier auctionFinished() {
        if (block.timestamp < auctionEndTime) revert AuctionNotYetEnded();
        if (ended) revert AuctionEndAlreadyCalled();
        _;
    }

    constructor(uint256 _durationSeconds) {
        owner = msg.sender;
        auctionEndTime = block.timestamp + _durationSeconds;
    }

    /**
     * @dev Mengajukan tawaran (Bid).
     * Jika tawaran baru lebih tinggi, uang penawar sebelumnya masuk ke 'pendingReturns'.
     */
    function bid() public payable auctionActive {
        if (msg.value <= highestBid) revert BidTooLow(highestBid, highestBid + 1);

        if (highestBidder != address(0)) {
            pendingReturns[highestBidder] += highestBid;
        }

        highestBidder = msg.sender;
        highestBid    = msg.value;
        emit NewBid(msg.sender, msg.value);
    }

    /**
     * @dev Fungsi bagi penawar yang kalah untuk menarik kembali uang mereka.
     * Pola: Check -> Effects -> Interactions (C-E-I) untuk mencegah Reentrancy Attack.
     */
    function withdraw() public {
        uint256 amount = pendingReturns[msg.sender];
        if (amount == 0) revert NothingToWithdraw();

        // 1. Effects: Reset saldo ke 0 SEBELUM mengirim uang (Sangat Penting!)
        pendingReturns[msg.sender] = 0;

        // 2. Interactions: Kirim uang
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Transfer failed.");

        emit Withdrawn(msg.sender, amount);
    }

    /**
     * @dev Menutup lelang dan mengirim uang ke pemilik kontrak (Owner).
     */
    function endAuction() public onlyOwner auctionFinished {
        ended = true;
        emit AuctionEnded(highestBidder, highestBid);

        (bool success, ) = payable(owner).call{value: highestBid}("");
        require(success, "Transfer failed.");
    }

    function timeRemaining() public view returns (uint256) {
        if (block.timestamp >= auctionEndTime) return 0;
        return auctionEndTime - block.timestamp;
    }
}
