// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {FundMe} from "../src/FundMe.sol";
import {DeployFundMe} from "../script/DeployFundMe.s.sol";
import {HelperConfig} from "../script/HelperConfig.s.sol";

// Kontrak pembantu untuk mengetes kegagalan withdraw (tidak bisa terima ETH)
contract RevertingOwner {
  function doWithdraw(FundMe fundMe) public {
    fundMe.withdraw();
  }
}

contract FundMeTest is Test {
  FundMe fundMe;
  HelperConfig helperConfig;

  address USER = makeAddr("user");
  uint256 constant SEND_VALUE = 0.1 ether;
  uint256 constant STARTING_BALANCE = 10 ether;

  function setUp() external {
      DeployFundMe deployer = new DeployFundMe();
      (fundMe, helperConfig) = deployer.run();
      vm.deal(USER, STARTING_BALANCE);
  }

  function testMinimumDollarIsFive() public view {
      assertEq(fundMe.MINIMUM_USD(), 5 * 1e18);
  }

  function testOwnerIsMsgSender() public view {
      assertEq(fundMe.getOwner(), msg.sender);
  }

  function testPriceFeedVersionIsAccurate() public view {
      uint256 version = fundMe.getPriceFeed().version();
      if (block.chainid == 11155111) {
          assertEq(version, 4);
      } else {
          assertEq(version, 0);
      }
  }

  function testFundFailsWithoutEnoughETH() public {
      vm.expectRevert();
      fundMe.fund();
  }

  function testFundUpdatesFundedDataStructure() public {
      vm.prank(USER);
      fundMe.fund{value: SEND_VALUE}();

      uint256 amountFunded = fundMe.getAddressToAmountFunded(USER);
      assertEq(amountFunded, SEND_VALUE);
  }

  function testAddsFunderToArrayOfFunders() public {
      vm.prank(USER);
      fundMe.fund{value: SEND_VALUE}();

      address funder = fundMe.getFunder(0);
      assertEq(funder, USER);
  }

  modifier funded() {
      vm.prank(USER);
      fundMe.fund{value: SEND_VALUE}();
      _;
  }

  function testOnlyOwnerCanWithdraw() public funded {
      vm.expectRevert();
      vm.prank(USER);
      fundMe.withdraw();
  }

  function testWithdrawWithASingleFunder() public funded {
      // Arrange
      uint256 startingOwnerBalance = fundMe.getOwner().balance;
      uint256 startingFundMeBalance = address(fundMe).balance;

      // Act
      vm.prank(fundMe.getOwner());
      fundMe.withdraw();

      // Assert
      uint256 endingOwnerBalance = fundMe.getOwner().balance;
      uint256 endingFundMeBalance = address(fundMe).balance;
      assertEq(endingFundMeBalance, 0);
      assertEq(startingOwnerBalance + startingFundMeBalance, endingOwnerBalance);
  }

  function testWithdrawFromMultipleFunders() public funded {
      // Arrange
      uint160 numberOfFunders = 10;
      uint160 startingFunderIndex = 1;
      for (uint160 i = startingFunderIndex; i < numberOfFunders; i++) {
          hoax(address(i), SEND_VALUE);
          fundMe.fund{value: SEND_VALUE}();
      }

      uint256 startingOwnerBalance = fundMe.getOwner().balance;
      uint256 startingFundMeBalance = address(fundMe).balance;

      // Act
      vm.startPrank(fundMe.getOwner());
      fundMe.withdraw();
      vm.stopPrank();

      // Assert
      assert(address(fundMe).balance == 0);
      assert(startingOwnerBalance + startingFundMeBalance == fundMe.getOwner().balance);
  }

  function testCheaperWithdrawFromMultipleFunders() public funded {
      // Arrange
      uint160 numberOfFunders = 10;
      uint160 startingFunderIndex = 1;
      for (uint160 i = startingFunderIndex; i < numberOfFunders; i++) {
          hoax(address(i), SEND_VALUE);
          fundMe.fund{value: SEND_VALUE}();
      }

      uint256 startingOwnerBalance = fundMe.getOwner().balance;
      uint256 startingFundMeBalance = address(fundMe).balance;

      // Act
      vm.startPrank(fundMe.getOwner());
      fundMe.cheaperWithdraw();
      vm.stopPrank();

      // Assert
      assert(address(fundMe).balance == 0);
      assert(startingOwnerBalance + startingFundMeBalance == fundMe.getOwner().balance);
  }

  function testReceiveFunction() public {
      vm.prank(USER);
      (bool success,) = address(fundMe).call{value: SEND_VALUE}("");
      require(success);
      assertEq(fundMe.getAddressToAmountFunded(USER), SEND_VALUE);
  }

  function testFallbackFunction() public {
    vm.prank(USER);
    (bool success,) = address(fundMe).call{value: SEND_VALUE}(abi.encodeWithSignature("nonExistentFunction()"));
    require(success);
    assertEq(fundMe.getAddressToAmountFunded(USER), SEND_VALUE);
  }

  function testHelperConfigSepoliaChain() public {
    vm.chainId(11155111);
    HelperConfig newConfig = new HelperConfig();
    assertEq(newConfig.activeNetworkConfig(), 0x694AA1769357215DE4FAC081bf1f309aDC325306);
  }

  function testGetOrCreateAnvilEthConfigReturnsExistingConfig() public {
    helperConfig.getOrCreateAnvilEthConfig();
    address priceFeed = helperConfig.activeNetworkConfig();
    assertTrue(priceFeed != address(0));
  }

  // --- TEST UNTUK BRANCH COVERAGE 100% ---

  function testWithdrawFailsWhenCallFails() public funded {
    // Kita butuh owner yang tidak bisa terima ETH
    // Tapi i_owner di set saat constructor. Kita harus deploy ulang dengan RevertingOwner sebagai msg.sender
    RevertingOwner revOwner = new RevertingOwner();

    vm.startPrank(address(revOwner));
    FundMe newFundMe = new FundMe(helperConfig.activeNetworkConfig());
    vm.stopPrank();

    vm.deal(USER, SEND_VALUE);
    vm.prank(USER);
    newFundMe.fund{value: SEND_VALUE}();

    // Sekarang panggil withdraw dari revOwner.
    // withdraw akan mencoba call(revOwner) dan akan gagal karena revOwner tidak punya receive/fallback.
    vm.expectRevert();
    revOwner.doWithdraw(newFundMe);
  }
}
