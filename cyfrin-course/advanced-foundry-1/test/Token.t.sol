// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {Token} from "../src/Token.sol";

contract TokenTest is Test {
    Token public token;
    address public owner;
    address public user1;
    address public user2;

    string constant NAME = "CodebuffToken";
    string constant SYMBOL = "CBT";
    uint256 constant INITIAL_SUPPLY = 100_000 * 10 ** 18;
    uint256 constant MAX_SUPPLY = 1_000_000 * 10 ** 18;

    function setUp() external {
        owner = makeAddr("owner");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        vm.prank(owner);
        token = new Token(NAME, SYMBOL, INITIAL_SUPPLY);
    }

    /*//////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////*/

    function testConstructorSetsNameAndSymbol() public view {
        assertEq(token.name(), NAME);
        assertEq(token.symbol(), SYMBOL);
    }

    function testConstructorMintsInitialSupplyToOwner() public view {
        assertEq(token.totalSupply(), INITIAL_SUPPLY);
        assertEq(token.balanceOf(owner), INITIAL_SUPPLY);
    }

    function testConstructorSetsOwner() public view {
        assertEq(token.owner(), owner);
    }

    /*//////////////////////////////////////////////////////////
                            MINT
    //////////////////////////////////////////////////////////*/

    function testMintIncreasesTotalSupply() public {
        uint256 mintAmount = 50_000 * 10 ** 18;

        vm.prank(owner);
        token.mint(user1, mintAmount);

        assertEq(token.balanceOf(user1), mintAmount);
        assertEq(token.totalSupply(), INITIAL_SUPPLY + mintAmount);
    }

    function testMintRevertsWhenNotOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        token.mint(user1, 1000);
    }

    function testMintRevertsWhenExceedsMaxSupply() public {
        uint256 tooMuch = MAX_SUPPLY;

        vm.prank(owner);
        vm.expectRevert(Token.Token__MoreThanMaxSupply.selector);
        token.mint(user1, tooMuch);
    }

    function testMintRevertsWhenZeroAmount() public {
        vm.prank(owner);
        vm.expectRevert(Token.Token__ZeroTokens.selector);
        token.mint(user1, 0);
    }

    /*//////////////////////////////////////////////////////////
                            BURN
    //////////////////////////////////////////////////////////*/

    function testBurnReducesBalance() public {
        uint256 burnAmount = 10_000 * 10 ** 18;

        vm.prank(owner);
        token.burn(burnAmount);

        assertEq(token.balanceOf(owner), INITIAL_SUPPLY - burnAmount);
        assertEq(token.totalSupply(), INITIAL_SUPPLY - burnAmount);
    }

    function testBurnRevertsWhenInsufficientBalance() public {
        vm.prank(user1);
        vm.expectRevert();
        token.burn(1);
    }

    /*//////////////////////////////////////////////////////////
                            GIFT
    //////////////////////////////////////////////////////////*/

    function testGiftMintsToMultipleRecipients() public {
        address[] memory recipients = new address[](2);
        recipients[0] = user1;
        recipients[1] = user2;
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1000;
        amounts[1] = 2000;

        vm.prank(owner);
        token.gift(recipients, amounts);

        assertEq(token.balanceOf(user1), 1000);
        assertEq(token.balanceOf(user2), 2000);
        assertEq(token.totalSupply(), INITIAL_SUPPLY + 3000);
    }

    function testGiftRevertsWhenNotOwner() public {
        address[] memory recipients = new address[](1);
        recipients[0] = user1;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1000;

        vm.prank(user1);
        vm.expectRevert();
        token.gift(recipients, amounts);
    }

    function testGiftRevertsWhenExceedsMaxSupply() public {
        address[] memory recipients = new address[](1);
        recipients[0] = user1;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = MAX_SUPPLY;

        vm.prank(owner);
        vm.expectRevert(Token.Token__MoreThanMaxSupply.selector);
        token.gift(recipients, amounts);
    }

    /*//////////////////////////////////////////////////////////
                        TRANSFER
    //////////////////////////////////////////////////////////*/

    function testTransferWorks() public {
        vm.prank(owner);
        token.transfer(user1, 5000);

        assertEq(token.balanceOf(user1), 5000);
        assertEq(token.balanceOf(owner), INITIAL_SUPPLY - 5000);
    }

    function testTransferRevertsWhenInsufficientBalance() public {
        vm.prank(user1);
        vm.expectRevert();
        token.transfer(user2, 1);
    }

    /*//////////////////////////////////////////////////////////
                        MAX SUPPLY
    //////////////////////////////////////////////////////////*/

    function testGetMaxSupply() public view {
        assertEq(token.getMaxSupply(), MAX_SUPPLY);
    }

    /*//////////////////////////////////////////////////////////
                        FUZZ TESTS
    //////////////////////////////////////////////////////////*/

    function testFuzz_Mint(uint256 _amount) public {
        vm.assume(_amount > 0 && _amount <= MAX_SUPPLY - INITIAL_SUPPLY);

        vm.prank(owner);
        token.mint(user1, _amount);

        assertEq(token.balanceOf(user1), _amount);
    }

    function testFuzz_Burn(uint256 _amount) public {
        vm.assume(_amount > 0 && _amount <= INITIAL_SUPPLY);

        vm.prank(owner);
        token.burn(_amount);

        assertEq(token.balanceOf(owner), INITIAL_SUPPLY - _amount);
    }

    function testFuzz_Transfer(uint256 _amount) public {
        vm.assume(_amount > 0 && _amount <= INITIAL_SUPPLY);

        vm.prank(owner);
        token.transfer(user1, _amount);

        assertEq(token.balanceOf(user1), _amount);
        assertEq(token.balanceOf(owner), INITIAL_SUPPLY - _amount);
    }
}
