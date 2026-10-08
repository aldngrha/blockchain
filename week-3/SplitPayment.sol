// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

contract SplitPayment {

    // ── Structs ───────────────────────────────────────
    struct Recipient {
        address wallet;
        uint256 percentage; // basis points: 10000 = 100%
        // pakai basis points supaya bisa handle desimal
        // misal 33.5% = 3350 basis points
    }

    struct Payment {
        address payer;
        uint256 amount;
        uint256 timestamp;
    }

    // ── State Variables ────────────────────────────────
    address public owner;
    Recipient[] public recipients;
    uint256 public totalReceived;
    uint256 public paymentCount;

    mapping(address => uint256) public balances;
    mapping(uint256 => Payment) public paymentHistory;

    // ── Events ────────────────────────────────────────
    event PaymentReceived(
        address indexed payer,
        uint256 amount,
        uint256 paymentId
    );
    event Withdrawn(address indexed recipient, uint256 amount);
    event SplitUpdated(address[] wallets, uint256[] percentages);

    // ── Custom Errors ─────────────────────────────────
    error NotOwner(address caller);
    error InvalidPercentageTotal(uint256 total);
    error NoRecipientsSet();
    error NothingToWithdraw();
    error ZeroPayment();
    error ArrayLengthMismatch();

    // ── Modifiers ─────────────────────────────────────
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner(msg.sender);
        _;
    }

    modifier hasRecipients() {
        if (recipients.length == 0) revert NoRecipientsSet();
        _;
    }

    // ── Constructor ───────────────────────────────────
    constructor(
        address[] memory _wallets,
        uint256[] memory _percentages
    ) {
        owner = msg.sender;
        _setRecipients(_wallets, _percentages);
    }

    // ── Internal ──────────────────────────────────────

    function _setRecipients(
        address[] memory _wallets,
        uint256[] memory _percentages
    ) internal {
        if (_wallets.length != _percentages.length) {
            revert ArrayLengthMismatch();
        }

        // validasi total = 10000 (100%)
        uint256 total = 0;
        for (uint256 i = 0; i < _percentages.length; i++) {
            total += _percentages[i];
        }
        if (total != 10000) revert InvalidPercentageTotal(total);

        // hapus recipients lama
        delete recipients;

        // set recipients baru
        for (uint256 i = 0; i < _wallets.length; i++) {
            recipients.push(Recipient({
                wallet: _wallets[i],
                percentage: _percentages[i]
            }));
        }
    }

    // ── Main Functions ────────────────────────────────

    // terima pembayaran dan split otomatis
    receive() external payable hasRecipients {
        if (msg.value == 0) revert ZeroPayment();

        totalReceived += msg.value;
        paymentCount++;

        // simpan history
        paymentHistory[paymentCount] = Payment({
            payer: msg.sender,
            amount: msg.value,
            timestamp: block.timestamp
        });

        // split ke masing-masing recipient
        for (uint256 i = 0; i < recipients.length; i++) {
            uint256 share = (msg.value * recipients[i].percentage) / 10000;
            balances[recipients[i].wallet] += share;
        }

        emit PaymentReceived(msg.sender, msg.value, paymentCount);
    }

    // recipient withdraw bagian mereka
    function withdraw() public {
        uint256 amount = balances[msg.sender];
        if (amount == 0) revert NothingToWithdraw();

        // set 0 dulu — cegah reentrancy!
        balances[msg.sender] = 0;

        payable(msg.sender).transfer(amount);

        emit Withdrawn(msg.sender, amount);
    }

    // owner update split ratio
    function updateSplit(
        address[] memory _wallets,
        uint256[] memory _percentages
    ) public onlyOwner {
        _setRecipients(_wallets, _percentages);
        emit SplitUpdated(_wallets, _percentages);
    }

    // ── Views ─────────────────────────────────────────

    function getRecipients() public view returns (Recipient[] memory) {
        return recipients;
    }

    function getPayment(uint256 _id) public view returns (Payment memory) {
        return paymentHistory[_id];
    }

    function recipientCount() public view returns (uint256) {
        return recipients.length;
    }
}
