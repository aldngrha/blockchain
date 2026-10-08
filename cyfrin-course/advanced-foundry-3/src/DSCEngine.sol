// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {AggregatorV3Interface} from "./helpers/AggregatorV3Interface.sol";
import {DecentralizedStableCoin} from "./DecentralizedStableCoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title DSCEngine
/// @notice Core engine for the DSC stablecoin protocol — deposit collateral, mint/burn DSC, liquidate
/// @dev Follows the Checks-Effects-Interactions pattern
contract DSCEngine is ReentrancyGuard {
    // Constants
    uint256 public constant LIQUIDATION_THRESHOLD = 50; // 50% = need 2x collateral to mint 1 DSC
    uint256 public constant LIQUIDATION_BONUS = 10; // 10% bonus for liquidators
    uint256 public constant HEALTH_FACTOR_LIQUIDATION_THRESHOLD = 1e18;
    uint256 public constant PRICE_FEED_DECIMALS = 8;
    uint256 public constant USD_PER_UNIT = 1e18; // DSC is pegged to $1

    // State
    mapping(address => uint256) public s_collateralDeposited; // user => ETH deposited (in wei)
    address[] private s_supportedCollateral;
    mapping(address => AggregatorV3Interface) private s_priceFeeds;
    DecentralizedStableCoin private immutable i_dsc;
    uint256 private s_totalCollateral; // total ETH deposited across all users

    // Errors
    error DSCEngine__ZeroAddress();
    error DSCEngine__BreaksHealthFactor();
    error DSCEngine__HealthFactorOk();
    error DSCEngine__CollateralDepositZero();
    error DSCEngine__InsufficientCollateralBalance();
    error DSCEngine__MintFailed();
    error DSCEngine__MustBeMoreThanLiquidationThreshold();
    error DSCEngine__NotAllowed();
    error DSCEngine__InvalidHealthFactor();

    // Events
    event CollateralDeposited(address indexed user, uint256 amount);
    event CollateralRedeemed(address indexed source, address indexed destination, uint256 amount);
    event DSCMinted(address indexed user, uint256 amount);
    event DSCBurned(address indexed user, uint256 amount);
    event LiquidationCalled(address indexed liquidator, address indexed user, uint256 debtAmount, uint256 collateralAmount);

    /// @param dscAddress Address of the DSC token
    /// @param priceFeedAddresses Array of price feed addresses for each collateral
    /// @param collateralAddresses Array of collateral token addresses (address(0) for ETH)
    constructor(address dscAddress, address[] memory priceFeedAddresses, address[] memory collateralAddresses) {
        if (dscAddress == address(0)) revert DSCEngine__ZeroAddress();
        if (priceFeedAddresses.length != collateralAddresses.length) revert DSCEngine__ZeroAddress();

        i_dsc = DecentralizedStableCoin(dscAddress);

        for (uint256 i = 0; i < collateralAddresses.length; i++) {
            s_priceFeeds[collateralAddresses[i]] = AggregatorV3Interface(priceFeedAddresses[i]);
            s_supportedCollateral.push(collateralAddresses[i]);
        }
    }

    /// @notice Deposit ETH as collateral
    /// @dev User sends ETH with the call
    function depositCollateral() public payable nonReentrant {
        _depositCollateral(msg.value);
    }

    /// @notice Deposit ERC20 as collateral
    /// @param token The ERC20 token address
    /// @param amount The amount to deposit
    function depositCollateralToken(address token, uint256 amount) public nonReentrant {
        _depositCollateralToken(token, amount);
    }

    /// @notice Mint DSC against deposited collateral
    /// @param amount The amount of DSC to mint
    function mintDsc(uint256 amount) external nonReentrant {
        if (amount == 0) revert DSCEngine__MintFailed();

        uint256 userCollateralValue = _getUsdValue(msg.sender, s_collateralDeposited[msg.sender]);
        uint256 amountMinted = getUserDscMinted(msg.sender);
        uint256 totalDscMinted = amountMinted + amount;

        // Health factor check: (collateralValue * LIQUIDATION_THRESHOLD) / 100 >= totalDscMinted
        if ((userCollateralValue * LIQUIDATION_THRESHOLD) / 100 < totalDscMinted) {
            revert DSCEngine__BreaksHealthFactor();
        }

        bool minted = i_dsc.mint(msg.sender, amount);
        if (!minted) revert DSCEngine__MintFailed();

        emit DSCMinted(msg.sender, amount);
    }

    /// @notice Burn DSC to reduce debt
    /// @param amount The amount of DSC to burn
    function burnDsc(uint256 amount) external nonReentrant {
        i_dsc.burn(msg.sender, amount);

        uint256 userCollateralValue = _getUsdValue(msg.sender, s_collateralDeposited[msg.sender]);
        uint256 remainingDscMinted = getUserDscMinted(msg.sender) - amount;

        // If user still has debt, check health factor
        if (remainingDscMinted > 0) {
            if ((userCollateralValue * LIQUIDATION_THRESHOLD) / 100 < remainingDscMinted) {
                revert DSCEngine__BreaksHealthFactor();
            }
        }

        emit DSCBurned(msg.sender, amount);
    }

    /// @notice Redeem collateral by burning DSC first
    /// @param amount The amount of ETH to redeem
    function redeemCollateral(uint256 amount) public nonReentrant {
        _redeemCollateral(msg.sender, msg.sender, amount);
    }

    /// @notice Redeem collateral to another address
    /// @param from The address to redeem from
    /// @param to The address to send collateral to
    /// @param amount The amount of ETH to redeem
    function redeemCollateralAndMintDsc(address from, address to, uint256 amount) external nonReentrant {
        _redeemCollateral(from, to, amount);
    }

    /// @notice Liquidate an unhealthy position
    /// @dev Anyone can liquidate a position with health factor < 1
    /// @param collateralFrom The address of the undercollateralized user
    /// @param debtToCover The amount of DSC debt to cover
    function liquidate(address collateralFrom, uint256 debtToCover) external nonReentrant {
        uint256 startingUserHealthFactor = getHealthFactor(collateralFrom);
        if (startingUserHealthFactor >= HEALTH_FACTOR_LIQUIDATION_THRESHOLD) {
            revert DSCEngine__HealthFactorOk();
        }

        // Calculate collateral to seize (debt * (100 + LIQUIDATION_BONUS) / LIQUIDATION_THRESHOLD)
        uint256 collateralSeized = _calculateCollateralToSeize(debtToCover);

        // Burn DSC from liquidator's balance
        i_dsc.burn(msg.sender, debtToCover);

        // Transfer collateral to liquidator
        (bool success, ) = msg.sender.call{value: collateralSeized}("");
        if (!success) revert DSCEngine__MintFailed();

        // Update state — must come AFTER external call (CEI pattern)
        s_collateralDeposited[collateralFrom] -= collateralSeized;
        s_totalCollateral -= collateralSeized;

        // Check liquidator's health factor (should be fine since they're gaining collateral)
        uint256 endingUserHealthFactor = getHealthFactor(collateralFrom);
        if (endingUserHealthFactor > startingUserHealthFactor && endingUserHealthFactor < HEALTH_FACTOR_LIQUIDATION_THRESHOLD) {
            revert DSCEngine__InvalidHealthFactor();
        }

        emit LiquidationCalled(msg.sender, collateralFrom, debtToCover, collateralSeized);
    }

    /*//////////////////////////////////////////////////////////////
                           VIEW FUNCTIONS
    //////////////////////////////////////////////////////////*/

    /// @notice Get the health factor of a user
    /// @dev healthFactor = (collateralValue * LIQUIDATION_THRESHOLD / 100) / debt
    ///      If debt is 0, returns max uint256 (healthy)
    function getHealthFactor(address user) public view returns (uint256) {
        uint256 userDscMinted = getUserDscMinted(user);
        if (userDscMinted == 0) return type(uint256).max;

        uint256 userCollateralValue = _getUsdValue(user, s_collateralDeposited[user]);
        uint256 collateralAdjustedForThreshold = (userCollateralValue * LIQUIDATION_THRESHOLD) / 100;

        return (collateralAdjustedForThreshold * 1e18) / userDscMinted;
    }

    /// @notice Get the total DSC minted by a user
    function getUserDscMinted(address user) public view returns (uint256) {
        return i_dsc.balanceOf(user);
    }

    /// @notice Get the USD value of a user's collateral
    function getUsdValue(address user) public view returns (uint256) {
        return _getUsdValue(user, s_collateralDeposited[user]);
    }

    /// @notice Get the collateral balance of a user
    function getCollateralBalance(address user) public view returns (uint256) {
        return s_collateralDeposited[user];
    }

    /// @notice Get the total collateral deposited in the protocol
    function getTotalCollateral() public view returns (uint256) {
        return s_totalCollateral;
    }

    /// @notice Get the DSC token address
    function getDsc() public view returns (address) {
        return address(i_dsc);
    }

    /// @notice Get the price feed for a collateral token
    function getPriceFeed(address token) public view returns (AggregatorV3Interface) {
        return s_priceFeeds[token];
    }

    /// @notice Get the supported collateral tokens
    function getSupportedCollateral() public view returns (address[] memory) {
        return s_supportedCollateral;
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////*/

    function _depositCollateral(uint256 amount) internal {
        if (amount == 0) revert DSCEngine__CollateralDepositZero();

        s_collateralDeposited[msg.sender] += amount;
        s_totalCollateral += amount;

        emit CollateralDeposited(msg.sender, amount);
    }

    function _depositCollateralToken(address token, uint256 amount) internal {
        if (amount == 0) revert DSCEngine__CollateralDepositZero();

        ERC20(token).transferFrom(msg.sender, address(this), amount);

        s_collateralDeposited[msg.sender] += amount;
        s_totalCollateral += amount;

        emit CollateralDeposited(msg.sender, amount);
    }

    function _redeemCollateral(address from, address to, uint256 amount) internal {
        if (s_collateralDeposited[from] < amount) revert DSCEngine__InsufficientCollateralBalance();

        s_collateralDeposited[from] -= amount;
        s_totalCollateral -= amount;

        // Check health factor after redemption
        uint256 userDscMinted = getUserDscMinted(from);
        if (userDscMinted > 0) {
            uint256 userCollateralValue = _getUsdValue(from, s_collateralDeposited[from]);
            if ((userCollateralValue * LIQUIDATION_THRESHOLD) / 100 < userDscMinted) {
                revert DSCEngine__BreaksHealthFactor();
            }
        }

        // Transfer ETH
        (bool success, ) = to.call{value: amount}("");
        if (!success) revert DSCEngine__MintFailed();

        emit CollateralRedeemed(from, to, amount);
    }

    /// @notice Calculate the collateral to seize during liquidation
    /// @dev collateralToSeize = debt * (100 + LIQUIDATION_BONUS) / LIQUIDATION_THRESHOLD
    function _calculateCollateralToSeize(uint256 debtAmount) internal view returns (uint256) {
        uint256 bonusMultiplier = 100 + LIQUIDATION_BONUS;
        // debtAmount is already in 18 decimals (DSC = $1 each), so it IS the USD value
        uint256 amountCollateralUsd = (debtAmount * bonusMultiplier) / LIQUIDATION_THRESHOLD;

        address supportedCollateral = s_supportedCollateral[0]; // ETH
        uint256 collateralPrice = _getPrice(supportedCollateral);
        // priceFeed has 8 decimals, collateralAmount in wei (18 decimals)
        uint256 collateralAmount = (amountCollateralUsd * 1e8) / collateralPrice;

        return collateralAmount;
    }

    /// @notice Get the USD value of collateral in wei
    function _getUsdValue(address user, uint256 collateralAmount) internal view returns (uint256) {
        address supportedCollateral = s_supportedCollateral[0]; // ETH
        uint256 collateralPrice = _getPrice(supportedCollateral);

        // value = (collateralAmount * collateralPrice) / 1e8
        // Since DSC has 18 decimals and price feed has 8 decimals
        return (collateralAmount * collateralPrice) / 1e8;
    }

    /// @notice Get the latest price from a Chainlink price feed
    function _getPrice(address token) internal view returns (uint256) {
        AggregatorV3Interface priceFeed = s_priceFeeds[token];
        (, int256 answer, , uint256 updatedAt, ) = priceFeed.latestRoundData();
        if (answer < 0) revert DSCEngine__ZeroAddress();
        // Price feed returns 8 decimals
        return uint256(answer);
    }

    /// @dev Required for receive() — allows contract to receive ETH from liquidations
    receive() external payable {}
}
