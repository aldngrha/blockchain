// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {BasicNft} from "../src/BasicNft.sol";

contract BasicNftTest is Test {
    BasicNft public basicNft;
    address public user;

    function setUp() external {
        user = makeAddr("user");
        basicNft = new BasicNft();
    }

    /*//////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////*/

    function testConstructorSetsNameAndSymbol() public view {
        assertEq(basicNft.name(), "BasicNft");
        assertEq(basicNft.symbol(), "BNFT");
    }

    /*//////////////////////////////////////////////////////////
                            MINT
    //////////////////////////////////////////////////////////*/

    function testMintNftMintsOneToken() public {
        vm.prank(user);
        basicNft.mintNft();

        assertEq(basicNft.balanceOf(user), 1);
        assertEq(basicNft.ownerOf(1), user);
    }

    function testMintNftIncrementsTokenId() public {
        vm.prank(user);
        basicNft.mintNft();

        vm.prank(user);
        basicNft.mintNft();

        assertEq(basicNft.balanceOf(user), 2);
        assertEq(basicNft.ownerOf(1), user);
        assertEq(basicNft.ownerOf(2), user);
    }

    /*//////////////////////////////////////////////////////////
                            TOKEN URI
    //////////////////////////////////////////////////////////*/

    function testTokenUriReturnsCorrectUri() public {
        vm.prank(user);
        basicNft.mintNft();
        string memory expectedUri = "ipfs://QmSsYRx3yovKrQ49M59WA8Gsadb3jSidlLmRDBFDGE7LwD";
        assertEq(basicNft.tokenURI(1), expectedUri);
    }

    function testTokenUriRevertsForNonexistentToken() public {
        vm.expectRevert(BasicNft.BasicNft__TokenDoesNotExist.selector);
        basicNft.tokenURI(999);
    }

    /*//////////////////////////////////////////////////////////
                            FUZZ TESTS
    //////////////////////////////////////////////////////////*/

    function testFuzz_MintMultipleTokens(uint8 _count) public {
        vm.assume(_count > 0 && _count < 10);
        address receiver = makeAddr("receiver");

        for (uint256 i = 0; i < _count; i++) {
            vm.prank(receiver);
            basicNft.mintNft();
        }

        assertEq(basicNft.balanceOf(receiver), _count);
    }
}
