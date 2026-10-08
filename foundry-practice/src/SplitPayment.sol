// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

/**
 * @title SplitPayment
 * @dev Kontrak untuk membagi pembayaran masuk secara otomatis ke beberapa dompet.
 * Berguna untuk bagi hasil tim atau royalti.
 */
contract SplitPayment {
    // Struktur data penerima (dompet dan persentase)
    struct Recipient {
        address wallet;
        uint256 percentage; // Dalam basis point (misal: 10000 = 100%, 500 = 5%)
    }

    // Histori setiap pembayaran masuk
    struct Payment {
        address payer;
        uint256 amount;
        uint256 timestamp;
    }

    address     public owner;
    Recipient[] public recipients;     // Daftar siapa saja yang berhak dapat uang
    uint256     public totalReceived;  // Total koin yang pernah masuk ke kontrak
    uint256     public paymentCount;   // Jumlah transaksi masuk

    // Saldo virtual masing-masing penerima
    mapping(address => uint256) public balances;
    mapping(uint256 => Payment) public paymentHistory;

    event PaymentReceived(address indexed payer, uint256 amount, uint256 paymentId);
    event Withdrawn(address indexed recipient, uint256 amount);
    event SplitUpdated(address[] wallets, uint256[] percentages);

    error NotOwner(address caller);
    error InvalidPercentageTotal(uint256 total);
    error NoRecipientsSet();
    error NothingToWithdraw();
    error ZeroPayment();
    error ArrayLengthMismatch();

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner(msg.sender);
        _;
    }

    modifier hasRecipients() {
        if (recipients.length == 0) revert NoRecipientsSet();
        _;
    }

    constructor(address[] memory _wallets, uint256[] memory _percentages) {
        owner = msg.sender;
        _setRecipients(_wallets, _percentages);
    }

    /**
     * @dev Fungsi internal untuk mengatur daftar penerima.
     * Harus memastikan total persentase adalah tepat 100% (10000 basis points).
     */
    function _setRecipients(address[] memory _wallets, uint256[] memory _percentages) internal {
        if (_wallets.length != _percentages.length) revert ArrayLengthMismatch();

        uint256 total = 0;
        for (uint256 i = 0; i < _percentages.length; i++) {
            total += _percentages[i];
        }

        if (total != 10000) revert InvalidPercentageTotal(total);

        delete recipients; // Hapus daftar lama
        for (uint256 i = 0; i < _wallets.length; i++) {
            recipients.push(Recipient({ wallet: _wallets[i], percentage: _percentages[i] }));
        }
    }

    /**
     * @dev Fungsi receive() otomatis jalan ketika ada orang kirim koin langsung ke alamat kontrak.
     * Di sinilah logika pembagian (splitting) terjadi.
     */
    receive() external payable hasRecipients {
        if (msg.value == 0) revert ZeroPayment();

        totalReceived += msg.value;
        paymentCount++;

        paymentHistory[paymentCount] = Payment({
            payer: msg.sender,
            amount: msg.value,
            timestamp: block.timestamp
        });

        // Bagi-bagi jatah ke semua penerima
        for (uint256 i = 0; i < recipients.length; i++) {
            uint256 share = (msg.value * recipients[i].percentage) / 10000;
            balances[recipients[i].wallet] += share;
        }

        emit PaymentReceived(msg.sender, msg.value, paymentCount);
    }

    /**
     * @dev Masing-masing penerima menarik jatah mereka sendiri.
     */
    function withdraw() public {
        uint256 amount = balances[msg.sender];
        if (amount == 0) revert NothingToWithdraw();

        balances[msg.sender] = 0;

        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Transfer failed.");

        emit Withdrawn(msg.sender, amount);
    }

    function updateSplit(address[] memory _wallets, uint256[] memory _percentages) public onlyOwner {
        _setRecipients(_wallets, _percentages);
        emit SplitUpdated(_wallets, _percentages);
    }

    function getRecipients() public view returns (Recipient[] memory) {
        return recipients;
    }

    function getPayment(uint256 _id) public view returns (Payment memory) {
        return paymentHistory[_id];
    }
}
