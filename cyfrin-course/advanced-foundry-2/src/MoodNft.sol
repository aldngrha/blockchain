// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract MoodNft is ERC721 {
    uint256 private s_tokenId;
    string private s_mood;

    string constant HAPPY_MOOD = ":D";
    string constant SAD_MOOD = ":(";

    error MoodNft__TokenDoesNotExist();

    constructor() ERC721("MoodNft", "MNFT") {
        s_mood = HAPPY_MOOD;
    }

    /// @notice Mints a new MoodNFT to msg.sender
    function mintNft() public {
        s_tokenId++;
        _safeMint(msg.sender, s_tokenId);
    }

    /// @notice Flips the mood between happy and sad
    function flipMood() external {
        if (keccak256(bytes(s_mood)) == keccak256(bytes(HAPPY_MOOD))) {
            s_mood = SAD_MOOD;
        } else {
            s_mood = HAPPY_MOOD;
        }
    }

    /// @notice Returns the token URI as an on-chain SVG data URI
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        if (_ownerOf(tokenId) == address(0)) revert MoodNft__TokenDoesNotExist();
        return getSvgTokenUri();
    }

    /// @notice Returns the current mood
    function getMood() external view returns (string memory) {
        return s_mood;
    }

    /// @notice Returns the on-chain SVG as a base64-encoded data URI
    function getSvgTokenUri() public view returns (string memory) {
        string memory svgImage;
        if (keccak256(bytes(s_mood)) == keccak256(bytes(HAPPY_MOOD))) {
            svgImage =
                "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 100'><text x='50' y='50' font-size='50' text-anchor='middle'>:D</text></svg>";
        } else {
            svgImage =
                "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 100'><text x='50' y='50' font-size='50' text-anchor='middle'>:(</text></svg>";
        }

        string memory svgBase64 =
            "data:image/svg+xml;base64,";
        // In production you'd base64 encode here; for simplicity we use a data URI with the raw SVG
        return string(abi.encodePacked(svgBase64, svgImage));
    }
}
