// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

/**
 * @title PriceConverter Library
 * @notice Library untuk mengkonversi nilai ETH ke USD menggunakan Chainlink Price Feed
 */
library PriceConverter {
    /**
     * @notice Mengambil harga ETH terkini dari Chainlink Oracle
     */
    function getPrice(AggregatorV3Interface priceFeed) internal view returns (uint256) {
        // Mendapatkan data harga terbaru (roundData)
        (, int256 answer, , , ) = priceFeed.latestRoundData();

        // Harga dari Chainlink biasanya punya 8 desimal (contoh: 2000,00000000)
        // Kita butuh 18 desimal agar setara dengan WEI, jadi kita kali 1e10
        return uint256(answer * 1e10);
    }

    /**
     * @notice Mengkonversi jumlah ETH yang dikirim menjadi nilai USD-nya
     */
    function getConversionRate(uint256 ethAmount, AggregatorV3Interface priceFeed) internal view returns (uint256) {
        uint256 ethPrice = getPrice(priceFeed);

        // Rumus: (Harga ETH * Jumlah ETH) / 1e18
        // Kita bagi 1e18 karena (18 desimal * 18 desimal) akan menghasilkan 36 desimal
        uint256 ethAmountInUsd = (ethPrice * ethAmount) / 1e18;
        return ethAmountInUsd;
    }
}
