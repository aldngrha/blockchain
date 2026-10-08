// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title MultiToken
 * @notice ERC-1155: Fungible + Non-Fungible dalam 1 kontrak
 * @dev May 11 — Kenapa ERC-1155 lebih hemat gas dari ERC-20 + ERC-721 terpisah?
 *
 * ERC-1155 bisa representasi:
 * - Token ID 0: Fungible (1000 unit, kayak ERC-20)
 * - Token ID 1: Non-Fungible (1 unit, kayak ERC-721)
 * - Token ID 2: Semi-Fungible (50 unit, game items)
 *
 * Gas savings: batch transfer = 1 tx untuk banyak token
 */
contract MultiToken is ERC1155, Ownable {
    uint256 private _tokenIdCounter;

    error MultiToken__ZeroAmount();
    error MultiToken__ExceedsSupply();

    event TokenCreated(uint256 indexed tokenId, uint256 maxSupply, string uri);

    constructor() ERC1155("") Ownable(msg.sender) {}

    /**
     * @notice Create a new token type
     * @param maxSupply Maximum supply (0 = unlimited)
     * @param uri Metadata URI
     * @return tokenId The new token ID
     */
    function createToken(uint256 maxSupply, string calldata uri) external onlyOwner returns (uint256) {
        uint256 tokenId = _tokenIdCounter;
        _tokenIdCounter++;
        emit TokenCreated(tokenId, maxSupply, uri);
        return tokenId;
    }

    /**
     * @notice Mint tokens (fungible or non-fungible)
     * @dev amount=1 for NFT, amount>1 for fungible tokens
     */
    function mint(address to, uint256 tokenId, uint256 amount) external onlyOwner {
        _mint(to, tokenId, amount, "");
    }

    /**
     * @notice Batch mint — hemat gas untuk mint banyak token sekaligus
     * @dev Satu transaksi = multiple token mints
     */
    function batchMint(address to, uint256[] calldata ids, uint256[] calldata amounts) external onlyOwner {
        _mintBatch(to, ids, amounts, "");
    }

    /**
     * @notice Batch transfer — hemat gas untuk transfer banyak token
     * @dev Satu transaksi = multiple token transfers
     */
    function batchTransfer(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts
    ) external {
        safeBatchTransferFrom(from, to, ids, amounts, "");
    }

    /**
     * @notice Burn tokens
     */
    function burn(address account, uint256 tokenId, uint256 amount) external {
        _burn(account, tokenId, amount);
    }

    /**
     * @notice Batch burn — hemat gas untuk burn banyak token
     */
    function batchBurn(address account, uint256[] calldata ids, uint256[] calldata amounts) external {
        _burnBatch(account, ids, amounts);
    }

    /**
     * @notice Set URI for a token
     */
    function setURI(string calldata newUri) external onlyOwner {
        _setURI(newUri);
    }
}
