// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

contract SimpleAuction {

    // ── State Variables ────────────────────────────────
    address public owner;
    uint256 public auctionEndTime;
    bool public ended;

    address public highestBidder;
    uint256 public highestBid;

    // simpan berapa ETH yang bisa di-withdraw tiap address
    mapping(address => uint256) public pendingReturns;

    // ── Events ────────────────────────────────────────
    event NewBid(address indexed bidder, uint256 amount);
    event AuctionEnded(address indexed winner, uint256 amount);
    event Withdrawn(address indexed bidder, uint256 amount);

    // ── Custom Errors ─────────────────────────────────
    error NotOwner(address caller);
    error AuctionAlreadyEnded();
    error AuctionNotYetEnded();
    error BidTooLow(uint256 current, uint256 minimum);
    error NothingToWithdraw();
    error AuctionEndAlreadyCalled();

    // ── Modifiers ─────────────────────────────────────
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner(msg.sender);
        _;
    }

    modifier auctionActive() {
        if (block.timestamp >= auctionEndTime) revert AuctionAlreadyEnded();
        if (ended) revert AuctionAlreadyEnded();
        _;
    }

    modifier auctionFinished() {
        if (block.timestamp < auctionEndTime) revert AuctionNotYetEnded();
        if (ended) revert AuctionEndAlreadyCalled();
        _;
    }

    // ── Constructor ───────────────────────────────────
    // _durationSeconds = berapa lama lelang berjalan
    // misal: 86400 = 1 hari, 3600 = 1 jam
    constructor(uint256 _durationSeconds) {
        owner = msg.sender;
        auctionEndTime = block.timestamp + _durationSeconds;
    }

    // ── Functions ─────────────────────────────────────

    // bid dengan kirim ETH
    function bid() public payable auctionActive {
        // bid harus lebih tinggi dari tertinggi saat ini
        if (msg.value <= highestBid) {
            revert BidTooLow(highestBid, highestBid + 1);
        }

        // kalau sudah ada highest bidder sebelumnya,
        // simpan ETH mereka supaya bisa di-withdraw
        // PENTING: ini pull pattern — kita tidak langsung kirim balik
        // karena langsung kirim (push) bisa kena reentrancy attack!
        if (highestBidder != address(0)) {
            pendingReturns[highestBidder] += highestBid;
        }

        highestBidder = msg.sender;
        highestBid = msg.value;

        emit NewBid(msg.sender, msg.value);
    }

    // bidder yang kalah withdraw ETH mereka
    function withdraw() public {
        uint256 amount = pendingReturns[msg.sender];
        if (amount == 0) revert NothingToWithdraw();

        // set ke 0 DULU sebelum transfer — cegah reentrancy!
        // ini checks-effects-interactions pattern
        pendingReturns[msg.sender] = 0;

        payable(msg.sender).transfer(amount);

        emit Withdrawn(msg.sender, amount);
    }

    // owner akhiri lelang setelah waktu habis
    function endAuction() public onlyOwner auctionFinished {
        ended = true;

        emit AuctionEnded(highestBidder, highestBid);

        // kirim ETH tertinggi ke owner
        payable(owner).transfer(highestBid);
    }

    // lihat sisa waktu lelang (dalam detik)
    function timeRemaining() public view returns (uint256) {
        if (block.timestamp >= auctionEndTime) return 0;
        return auctionEndTime - block.timestamp;
    }
}
