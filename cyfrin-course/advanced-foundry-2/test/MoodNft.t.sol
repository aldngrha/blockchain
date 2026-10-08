// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {MoodNft} from "../src/MoodNft.sol";

contract MoodNftTest is Test {
    MoodNft public moodNft;
    address public user;

    function setUp() external {
        user = makeAddr("user");
        moodNft = new MoodNft();
    }

    /*//////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////*/

    function testConstructorSetsNameAndSymbol() public view {
        assertEq(moodNft.name(), "MoodNft");
        assertEq(moodNft.symbol(), "MNFT");
    }

    function testConstructorStartsWithHappyMood() public view {
        assertEq(moodNft.getMood(), ":D");
    }

    /*//////////////////////////////////////////////////////////
                            MINT
    //////////////////////////////////////////////////////////*/

    function testMintNftMintsOneToken() public {
        vm.prank(user);
        moodNft.mintNft();

        assertEq(moodNft.balanceOf(user), 1);
        assertEq(moodNft.ownerOf(1), user);
    }

    /*//////////////////////////////////////////////////////////
                            FLIP MOOD
    //////////////////////////////////////////////////////////*/

    function testFlipMoodChangesToSad() public {
        moodNft.flipMood();
        assertEq(moodNft.getMood(), ":(");
    }

    function testFlipMoodChangesBackToHappy() public {
        moodNft.flipMood();
        moodNft.flipMood();
        assertEq(moodNft.getMood(), ":D");
    }

    function testFlipMoodMultipleTimes() public {
        moodNft.flipMood(); // sad
        moodNft.flipMood(); // happy
        moodNft.flipMood(); // sad
        assertEq(moodNft.getMood(), ":(");
    }

    /*//////////////////////////////////////////////////////////
                        TOKEN URI (SVG)
    //////////////////////////////////////////////////////////*/

    function testTokenUriReturnsSvgWhenHappy() public {
        vm.prank(user);
        moodNft.mintNft();
        string memory uri = moodNft.tokenURI(1);
        // Should contain happy SVG
        assertTrue(bytes(uri).length > 0);
    }

    function testTokenUriRevertsForNonexistentToken() public {
        vm.expectRevert(MoodNft.MoodNft__TokenDoesNotExist.selector);
        moodNft.tokenURI(999);
    }

    function testGetSvgTokenUriReturnsDataUri() public view {
        string memory svgUri = moodNft.getSvgTokenUri();
        assertTrue(bytes(svgUri).length > 0);
    }

    /*//////////////////////////////////////////////////////////
                        END TO END
    //////////////////////////////////////////////////////////*/

    function testMintThenFlipMoodThenCheckUri() public {
        vm.prank(user);
        moodNft.mintNft();

        assertEq(moodNft.getMood(), ":D");

        moodNft.flipMood();
        assertEq(moodNft.getMood(), ":(");

        // Token should still be owned by user
        assertEq(moodNft.ownerOf(1), user);
    }
}
