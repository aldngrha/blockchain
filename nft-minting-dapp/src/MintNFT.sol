// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title MintNFT
 * @notice Simple ERC-721 NFT contract with public mint
 * @dev Users can mint NFTs by paying 0.01 ETH, each with IPFS metadata URI
 */
contract MintNFT is ERC721, ERC721URIStorage, Ownable {
    uint256 private _nextTokenId;
    uint256 public mintPrice = 0.01 ether;
    uint256 public maxSupply = 100;
    bool public mintingActive = true;

    event Minted(address indexed to, uint256 indexed tokenId, string uri);
    event MintPriceUpdated(uint256 newPrice);
    event MintingToggled(bool active);

    constructor() ERC721("Freebuff NFT", "FBNFT") Ownable(msg.sender) {}

    /**
     * @notice Mint a new NFT with a given metadata URI
     * @param uri The IPFS URI pointing to the NFT metadata JSON
     */
    function mint(string memory uri) external payable {
        require(mintingActive, "Minting is not active");
        require(msg.value >= mintPrice, "Insufficient payment");
        require(_nextTokenId < maxSupply, "Max supply reached");

        uint256 tokenId = _nextTokenId;
        _nextTokenId++;

        _safeMint(msg.sender, tokenId);
        _setTokenURI(tokenId, uri);

        emit Minted(msg.sender, tokenId, uri);
    }

    /**
     * @notice Owner can mint for free (for testing/giveaways)
     */
    function ownerMint(address to, string memory uri) external onlyOwner {
        require(_nextTokenId < maxSupply, "Max supply reached");

        uint256 tokenId = _nextTokenId;
        _nextTokenId++;

        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);

        emit Minted(to, tokenId, uri);
    }

    function setMintPrice(uint256 newPrice) external onlyOwner {
        mintPrice = newPrice;
        emit MintPriceUpdated(newPrice);
    }

    function toggleMinting() external onlyOwner {
        mintingActive = !mintingActive;
        emit MintingToggled(mintingActive);
    }

    function totalMinted() external view returns (uint256) {
        return _nextTokenId;
    }

    function remaining() external view returns (uint256) {
        return maxSupply - _nextTokenId;
    }

    // Required overrides
    function _update(address to, uint256 tokenId, address auth)
        internal
        override(ERC721)
        returns (address)
    {
        return super._update(to, tokenId, auth);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No ETH to withdraw");
        (bool success,) = payable(owner()).call{value: balance}("");
        require(success, "Withdraw failed");
    }

    receive() external payable {}
}
