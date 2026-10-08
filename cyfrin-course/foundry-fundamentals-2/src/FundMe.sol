// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

/**
 * @title Proyek FundMe - Belajar Solidity Section 3
 * @author Patrick Collins (Implemented by Gemini CLI)
 * @notice Kontrak ini digunakan untuk mengumpulkan dana (crowdfunding) dengan batas minimal USD
 * @dev Kontrak ini mengimplementasikan Chainlink Price Feeds sebagai library
 */

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {PriceConverter} from "./PriceConverter.sol";

// Custom Error: Lebih hemat gas daripada require(..., "pesan error")
error FundMe__NotOwner();

contract FundMe {
    // Menggunakan library PriceConverter untuk tipe data uint256
    using PriceConverter for uint256;

    // --- State Variables ---
    
    // Constant & Immutable: Variabel yang tidak berubah setelah deploy (Sangat Hemat Gas)
    // i_ = immutable, s_ = storage (Naming convention untuk identifikasi gas cost)
    uint256 public constant MINIMUM_USD = 5 * 1e18;
    
    // s_funders disimpan di Storage (Mahal). Dibuat private untuk optimasi gas.
    address[] private s_funders;
    mapping(address => uint256) private s_addressToAmountFunded;
    
    address private immutable i_owner;
    AggregatorV3Interface private s_priceFeed;

    // Events: Berguna untuk indexing data di Off-chain (Front-end)
    event Funded(address indexed funder, uint256 amount);

    // Modifier: Fungsi yang dijalankan sebelum fungsi utama
    modifier onlyOwner() {
        // Menggunakan custom error FundMe__NotOwner()
        if (msg.sender != i_owner) revert FundMe__NotOwner();
        _;
    }

    // Constructor: Dipanggil sekali saat kontrak di-deploy
    constructor(address priceFeed) {
        i_owner = msg.sender;
        s_priceFeed = AggregatorV3Interface(priceFeed);
    }

    /**
     * @notice Fungsi untuk mengirim dana ke kontrak
     * @dev Menggunakan library PriceConverter untuk cek apakah ETH yang dikirim >= 5 USD
     */
    function fund() public payable {
        require(msg.value.getConversionRate(s_priceFeed) >= MINIMUM_USD, "Didnt send enough ETH");
        s_addressToAmountFunded[msg.sender] += msg.value;
        s_funders.push(msg.sender);
        emit Funded(msg.sender, msg.value);
    }

    /**
     * @notice Fungsi withdraw standar (Masih agak boros gas karena baca storage di looping)
     */
    function withdraw() public onlyOwner {
        for (uint256 funderIndex = 0; funderIndex < s_funders.length; funderIndex++) {
            address funder = s_funders[funderIndex];
            s_addressToAmountFunded[funder] = 0;
        }
        // Reset array
        s_funders = new address[](0);

        // Call: Cara kirim ETH paling aman & fleksibel saat ini
        (bool callSuccess,) = payable(msg.sender).call{value: address(this).balance}("");
        require(callSuccess, "Call failed");
    }

    /**
     * @notice Fungsi withdraw versi HEMAT GAS
     * @dev Kita memindahkan array dari Storage ke Memory sebelum looping
     */
    function cheaperWithdraw() public onlyOwner {
        // OPTIMASI GAS: Membaca storage satu kali ke dalam memory array
        // Membaca dari memory JAUH lebih murah daripada membaca dari storage berkali-kali di dalam loop
        address[] memory funders = s_funders;
        
        for (uint256 funderIndex = 0; funderIndex < funders.length; funderIndex++) {
            address funder = funders[funderIndex];
            // Update mapping tetap harus ke storage (mapping tidak bisa di memory)
            s_addressToAmountFunded[funder] = 0;
        }
        s_funders = new address[](0);

        (bool callSuccess,) = payable(msg.sender).call{value: address(this).balance}("");
        require(callSuccess, "Call failed");
    }

    // --- Getter Functions (View/Pure) ---
    // Fungsi-fungsi ini memudahkan user/UI melihat data tanpa harus tahu struktur internal
    
    function getAddressToAmountFunded(address fundingAddress) external view returns (uint256) {
        return s_addressToAmountFunded[fundingAddress];
    }

    function getFunder(uint256 index) external view returns (address) {
        return s_funders[index];
    }

    function getOwner() external view returns (address) {
        return i_owner;
    }

    function getPriceFeed() external view returns (AggregatorV3Interface) {
        return s_priceFeed;
    }

    // Handling jika ada orang kirim ETH tanpa panggil fund()
    receive() external payable {
        fund();
    }

    fallback() external payable {
        fund();
    }
}
