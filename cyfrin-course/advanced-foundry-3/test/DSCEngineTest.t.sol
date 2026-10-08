// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {DecentralizedStableCoin} from "../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../src/DSCEngine.sol";
import {MockV3Aggregator} from "./mocks/MockV3Aggregator.sol";

contract DSCEngineTest is Test {
    DecentralizedStableCoin public dsc;
    DSCEngine public dsce;
    MockV3Aggregator public mockPriceFeed;

    address public user;
    address public user2;
    address public liquidator;

    uint8 public constant PRICE_FEED_DECIMALS = 8;
    uint256 public constant INITIAL_PRICE = 2000e8; // $2000 ETH/USD
    uint256 public constant DEPOSIT_AMOUNT = 10 ether; // 10 ETH
    uint256 public constant MORE_COLLATERAL_THAN_NEEDED = 30 ether;

    function setUp() public {
        user = makeAddr("user");
        user2 = makeAddr("user2");
        liquidator = makeAddr("liquidator");

        // Deploy mock price feed
        mockPriceFeed = new MockV3Aggregator(PRICE_FEED_DECIMALS, int256(INITIAL_PRICE));

        // Deploy DSC with address(0) first, then set engine after DSCEngine is deployed
        dsc = new DecentralizedStableCoin(address(0));

        address[] memory priceFeedAddresses = new address[](1);
        priceFeedAddresses[0] = address(mockPriceFeed);

        address[] memory collateralAddresses = new address[](1);
        collateralAddresses[0] = address(0); // ETH

        dsce = new DSCEngine(address(dsc), priceFeedAddresses, collateralAddresses);

        // Now set the engine address on DSC so it can mint/burn
        dsc.setEngine(address(dsce));
    }

    /*//////////////////////////////////////////////////////////
                         HELPER FUNCTIONS
    //////////////////////////////////////////////////////////*/

    function _giveTokensToUser(address _user, uint256 _amount) internal {
        vm.deal(_user, _amount);
    }

    function _depositAsUser(address _user, uint256 _amount) internal {
        vm.deal(_user, _amount);
        vm.prank(_user);
        dsce.depositCollateral{value: _amount}();
    }

    function _mintDscAsUser(address _user, uint256 _amount) internal {
        vm.prank(_user);
        dsce.mintDsc(_amount);
    }

    /*//////////////////////////////////////////////////////////
                      DEPOSIT COLLATERAL TESTS
    //////////////////////////////////////////////////////////*/

    function testDepositCollateralIncreasesBalance() public {
        _depositAsUser(user, DEPOSIT_AMOUNT);
        assertEq(dsce.getCollateralBalance(user), DEPOSIT_AMOUNT);
    }

    function testDepositCollateralEmitsEvent() public {
        vm.expectEmit(true, true, true, true);
        emit DSCEngine.CollateralDeposited(user, DEPOSIT_AMOUNT);
        _depositAsUser(user, DEPOSIT_AMOUNT);
    }

    function testDepositCollateralUpdatesTotalCollateral() public {
        _depositAsUser(user, DEPOSIT_AMOUNT);
        assertEq(dsce.getTotalCollateral(), DEPOSIT_AMOUNT);
    }

    function testDepositCollateralRevertsOnZero() public {
        vm.deal(user, 1 ether);
        vm.prank(user);
        vm.expectRevert(DSCEngine.DSCEngine__CollateralDepositZero.selector);
        dsce.depositCollateral{value: 0}();
    }

    /*//////////////////////////////////////////////////////////
                        MINT DSC TESTS
    //////////////////////////////////////////////////////////*/

    function testMintDscMintsTokens() public {
        _depositAsUser(user, DEPOSIT_AMOUNT);
        _mintDscAsUser(user, 1000 * 1e18);

        assertEq(dsc.balanceOf(user), 1000 * 1e18);
    }

    function testMintDscRevertsWhenBreaksHealthFactor() public {
        // 10 ETH = $20,000. At 50% threshold, can mint max $10,000 DSC
        _depositAsUser(user, DEPOSIT_AMOUNT);
        vm.prank(user);
        vm.expectRevert(DSCEngine.DSCEngine__BreaksHealthFactor.selector);
        dsce.mintDsc(10_001 * 1e18); // slightly over
    }

    function testMintDscRevertsOnZeroAmount() public {
        _depositAsUser(user, DEPOSIT_AMOUNT);
        vm.prank(user);
        vm.expectRevert(DSCEngine.DSCEngine__MintFailed.selector);
        dsce.mintDsc(0);
    }

    function testMintDscMultipleUsers() public {
        _depositAsUser(user, DEPOSIT_AMOUNT);
        _depositAsUser(user2, DEPOSIT_AMOUNT);

        _mintDscAsUser(user, 5000 * 1e18);
        _mintDscAsUser(user2, 5000 * 1e18);

        assertEq(dsc.balanceOf(user), 5000 * 1e18);
        assertEq(dsc.balanceOf(user2), 5000 * 1e18);
    }

    /*//////////////////////////////////////////////////////////
                     HEALTH FACTOR TESTS
    //////////////////////////////////////////////////////////*/

    function testGetHealthFactorReturnsMaxWhenNoDebt() public {
        _depositAsUser(user, DEPOSIT_AMOUNT);
        uint256 healthFactor = dsce.getHealthFactor(user);
        assertEq(healthFactor, type(uint256).max);
    }

    function testGetHealthFactorReturnsCorrectValue() public {
        // 10 ETH = $20,000 at $2000/ETH
        // Mint 5000 DSC (debt = $5000)
        // healthFactor = (20000 * 50 / 100) / 5000 * 1e18 = 2e18
        _depositAsUser(user, DEPOSIT_AMOUNT);
        _mintDscAsUser(user, 5000 * 1e18);

        uint256 healthFactor = dsce.getHealthFactor(user);
        // healthFactor = (20000e18 * 50 / 100) / 5000e18 * 1e18 = 2e18
        assertEq(healthFactor, 2e18);
    }

    function testHealthFactorDecreasesWhenPriceDrops() public {
        _depositAsUser(user, DEPOSIT_AMOUNT);
        _mintDscAsUser(user, 5000 * 1e18);

        uint256 healthFactorBefore = dsce.getHealthFactor(user);
        assertEq(healthFactorBefore, 2e18);

        // Drop ETH price from $2000 to $1000
        mockPriceFeed.updateAnswer(1000e8);

        uint256 healthFactorAfter = dsce.getHealthFactor(user);
        // Now: (10000 * 50 / 100) / 5000 * 1e18 = 1e18
        assertEq(healthFactorAfter, 1e18);
    }

    /*//////////////////////////////////////////////////////////
                      REDEEM COLLATERAL TESTS
    //////////////////////////////////////////////////////////*/

    function testRedeemCollateralReturnsETH() public {
        _depositAsUser(user, DEPOSIT_AMOUNT);

        uint256 balanceBefore = user.balance;

        vm.prank(user);
        dsce.redeemCollateral(DEPOSIT_AMOUNT);

        assertEq(user.balance, balanceBefore + DEPOSIT_AMOUNT);
        assertEq(dsce.getCollateralBalance(user), 0);
    }

    function testRedeemCollateralRevertsWhenBreaksHealthFactor() public {
        // Deposit 10 ETH, mint 9900 DSC (very close to max of 10000)
        _depositAsUser(user, DEPOSIT_AMOUNT);
        _mintDscAsUser(user, 9900 * 1e18);

        // Try to redeem 1 ETH — would break health factor
        // After redeeming 1 ETH: 9 ETH = $18,000. At 50%: $9,000 health
        // Debt: 9900 DSC. Health factor: 9000/9900 = 0.909 (unhealthy!)
        vm.prank(user);
        vm.expectRevert(DSCEngine.DSCEngine__BreaksHealthFactor.selector);
        dsce.redeemCollateral(1 ether);
    }

    function testRedeemCollateralRevertsOnInsufficientBalance() public {
        _depositAsUser(user, DEPOSIT_AMOUNT);

        vm.prank(user);
        vm.expectRevert(DSCEngine.DSCEngine__InsufficientCollateralBalance.selector);
        dsce.redeemCollateral(DEPOSIT_AMOUNT + 1);
    }

    /*//////////////////////////////////////////////////////////
                       LIQUIDATION TESTS
    //////////////////////////////////////////////////////////*/

    function testLiquidationCanOccur() public {
        // Deposit 10 ETH = $20,000, mint 9000 DSC (close to max)
        _depositAsUser(user, DEPOSIT_AMOUNT);
        _mintDscAsUser(user, 9000 * 1e18);

        // Liquidator also needs collateral + DSC to be able to liquidate
        _depositAsUser(liquidator, 20 ether);
        _mintDscAsUser(liquidator, 9000 * 1e18);

        // Drop ETH price from $2000 to $1000 — user now undercollateralized
        mockPriceFeed.updateAnswer(1000e8);

        uint256 healthFactor = dsce.getHealthFactor(user);
        assertTrue(healthFactor < 1e18);

        uint256 liquidatorBalanceBefore = liquidator.balance;

        // Liquidator covers 4000 DSC debt
        vm.prank(liquidator);
        dsce.liquidate(user, 4000 * 1e18);

        // Liquidator should receive collateral: 4000 * 1.10 / 0.50 = 8800 USD worth
        // At $1000/ETH: 8800 / 1000 = 8.8 ETH
        uint256 expectedCollateral = (4000 * 1e18 * 110) / 50; // 8800 * 1e18
        uint256 expectedEth = (expectedCollateral * 1e8) / (1000e8);

        assertEq(liquidator.balance, liquidatorBalanceBefore + expectedEth);
    }

    function testLiquidationRevertsWhenHealthFactorOk() public {
        _depositAsUser(user, DEPOSIT_AMOUNT);
        _mintDscAsUser(user, 5000 * 1e18);

        // Liquidator also needs collateral + DSC to attempt liquidation
        _depositAsUser(liquidator, 20 ether);
        _mintDscAsUser(liquidator, 5000 * 1e18);

        // User is healthy (healthFactor = 2e18)
        vm.prank(liquidator);
        vm.expectRevert(DSCEngine.DSCEngine__HealthFactorOk.selector);
        dsce.liquidate(user, 1000 * 1e18);
    }

    /*//////////////////////////////////////////////////////////
                       USD VALUE TESTS
    //////////////////////////////////////////////////////////*/

    function testGetUsdValue() public {
        _depositAsUser(user, DEPOSIT_AMOUNT);
        uint256 usdValue = dsce.getUsdValue(user);
        // 10 ETH * $2000 = $20,000
        assertEq(usdValue, 20_000 * 1e18);
    }

    function testGetUsdValueChangesWithPrice() public {
        _depositAsUser(user, DEPOSIT_AMOUNT);

        mockPriceFeed.updateAnswer(3000e8); // $3000
        uint256 usdValue = dsce.getUsdValue(user);
        assertEq(usdValue, 30_000 * 1e18);
    }

    /*//////////////////////////////////////////////////////////
                        FUZZ TESTS
    //////////////////////////////////////////////////////////*/

    function testFuzz_DepositAndCheckBalance(uint8 _amount) public {
        vm.assume(_amount > 0);
        uint256 depositAmount = uint256(_amount) * 1 ether;
        _depositAsUser(user, depositAmount);
        assertEq(dsce.getCollateralBalance(user), depositAmount);
    }

    function testFuzz_MintWithinHealthFactor(uint8 _amount) public {
        vm.assume(_amount > 0 && _amount < 50); // max ~$10,000 at $2000 ETH with 10 ETH
        uint256 mintAmount = uint256(_amount) * 100 * 1e18; // 100 DSC increments
        _depositAsUser(user, DEPOSIT_AMOUNT);
        _mintDscAsUser(user, mintAmount);
        assertEq(dsc.balanceOf(user), mintAmount);
    }

    /*//////////////////////////////////////////////////////////
                      BURN DSC TESTS
    //////////////////////////////////////////////////////////*/

    function testBurnDscReducesBalance() public {
        _depositAsUser(user, DEPOSIT_AMOUNT);
        _mintDscAsUser(user, 5000 * 1e18);

        vm.prank(user);
        dsce.burnDsc(2000 * 1e18);

        assertEq(dsc.balanceOf(user), 3000 * 1e18);
    }

    function testBurnDscEmitsEvent() public {
        _depositAsUser(user, DEPOSIT_AMOUNT);
        _mintDscAsUser(user, 5000 * 1e18);

        vm.expectEmit(true, true, true, true);
        emit DSCEngine.DSCBurned(user, 2000 * 1e18);

        vm.prank(user);
        dsce.burnDsc(2000 * 1e18);
    }

    /*//////////////////////////////////////////////////////////
                      VIEW FUNCTIONS
    //////////////////////////////////////////////////////////*/

    function testGetDsc() public view {
        assertEq(dsce.getDsc(), address(dsc));
    }

    function testGetSupportedCollateral() public view {
        address[] memory supported = dsce.getSupportedCollateral();
        assertEq(supported.length, 1);
        assertEq(supported[0], address(0)); // ETH
    }

    function testGetTotalCollateral() public {
        _depositAsUser(user, DEPOSIT_AMOUNT);
        _depositAsUser(user2, 5 ether);
        assertEq(dsce.getTotalCollateral(), 15 ether);
    }
}
