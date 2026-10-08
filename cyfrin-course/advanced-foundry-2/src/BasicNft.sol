// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract BasicNft is ERC721 {
    uint256 private s_tokenId;

    error BasicNft__TokenDoesNotExist();

    constructor() ERC721("BasicNft", "BNFT") {}

    /// @notice Mints a new NFT to msg.sender
    function mintNft() public {
        s_tokenId++;
        _safeMint(msg.sender, s_tokenId);
    }

    /// @notice Returns the token URI (off-chain metadata)
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        if (_ownerOf(tokenId) == address(0)) revert BasicNft__TokenDoesNotExist();
        return "ipfs://QmSsYRx3yovKrQ49M59WA8Gsadb3jSidlLmRDBFDGE7LwD";
    }

    /// @notice Returns the total number of tokens minted
    function getSvgTokenUri() external pure returns (string memory) {
        return "ipfs://QmSsYRx3yovKrQ49M59WA8Gsadb3jSidlLmRDBFDGE7LwD";
    }
}
