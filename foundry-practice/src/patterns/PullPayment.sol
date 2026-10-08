// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title PullPayment
 * @dev Implementasi pola desain "Pull-over-Push" untuk transfer dana.
 * Pola ini memisahkan logika deposit dan penarikan (withdrawal), yang lebih aman 
 * terhadap serangan DoS (Denial of Service) dan Reentrancy dibandingkan transfer langsung.
 */
contract PullPayment is Ownable, ReentrancyGuard {

    /// @dev Saldo masing-masing penerima yang belum ditarik.
    mapping(address => uint256) private _pendingPayments;
    
    /// @notice Total akumulasi dana yang saat ini ditampung dalam kontrak.
    uint256 public totalPending;

    /// @dev Diemitkan saat Owner menyetor dana untuk seseorang.
    event PaymentDeposited(address indexed payee,  uint256 amount);
    /// @dev Diemitkan saat penerima melakukan penarikan dana.
    event PaymentWithdrawn(address indexed payee,  uint256 amount);

    error ZeroAmount();
    error NothingToWithdraw();
    error TransferFailed();

    /**
     * @notice Inisialisasi kontrak PullPayment.
     * @dev Constructor memanggil Ownable untuk menetapkan admin kontrak.
     */
    constructor() Ownable(msg.sender) {}

    /**
     * @notice Menyetorkan dana (ETH) ke dalam kontrak untuk penerima tertentu.
     * @dev Hanya Owner yang dapat menyetor dana.
     * @param _payee Alamat yang nantinya berhak menarik dana ini.
     */
    function depositPayment(address _payee) public payable onlyOwner {
        if (msg.value == 0) revert ZeroAmount();

        _pendingPayments[_payee] += msg.value;
        totalPending             += msg.value;

        emit PaymentDeposited(_payee, msg.value);
    }

    /**
     * @notice Mengambil dana yang tersedia untuk alamat pengirim (msg.sender).
     * @dev Menggunakan pola Checks-Effects-Interactions (CEI) dan ReentrancyGuard untuk keamanan maksimal.
     */
    function withdrawPayment() public nonReentrant {
        uint256 amount = _pendingPayments[msg.sender];
        if (amount == 0) revert NothingToWithdraw();

        // CEI Pattern: Langkah 1 & 2 (Checks & Effects)
        // Reset saldo internal ke nol sebelum melakukan transfer eksternal.
        _pendingPayments[msg.sender] = 0;
        totalPending                -= amount;

        // CEI Pattern: Langkah 3 (Interactions)
        // Mengirim dana menggunakan call{} yang merupakan standar transfer ETH modern.
        (bool success,) = payable(msg.sender).call{value: amount}("");
        if (!success) revert TransferFailed();

        emit PaymentWithdrawn(msg.sender, amount);
    }

    /**
     * @notice Melihat saldo pembayaran yang tertunda untuk alamat tertentu.
     * @param _payee Alamat dompet yang ingin diperiksa.
     * @return Jumlah dana dalam satuan Wei.
     */
    function pendingPayment(address _payee) public view returns (uint256) {
        return _pendingPayments[_payee];
    }
}
