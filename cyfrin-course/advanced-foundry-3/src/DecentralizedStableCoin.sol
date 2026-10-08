// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title DecentralizedStableCoin
/// @notice Algorithmic stablecoin pegged to $1 — only mintable/burnable by DSCEngine
/// @dev Fully decentralized: no owner, no admin, no special privileges
contract DecentralizedStableCoin is ERC20 {
    uint256 private constant MAX_SUPPLY = 10 ** 25; // 10,000,000 DSC

    error DecentralizedStableCoin__NotEngine();
    error DecentralizedStableCoin__CouldNotMint();

    address private i_engine;
    bool private s_engineSet;

    modifier onlyEngine() {
        if (msg.sender != i_engine) revert DecentralizedStableCoin__NotEngine();
        _;
    }

    /// @param engineAddress The DSCEngine contract that can mint/burn DSC
    constructor(address engineAddress) ERC20("DecentralizedStableCoin", "DSC") {
        i_engine = engineAddress;
        if (engineAddress != address(0)) {
            s_engineSet = true;
        }
    }

    /// @notice Set the engine address — can only be called once
    /// @param engineAddress The new DSCEngine address
    function setEngine(address engineAddress) external {
        if (s_engineSet) revert DecentralizedStableCoin__NotEngine();
        i_engine = engineAddress;
        s_engineSet = true;
    }

    /// @notice Mint DSC tokens — only callable by DSCEngine
    /// @param to The recipient
    /// @param amount The amount to mint
    function mint(address to, uint256 amount) external onlyEngine returns (bool) {
        if (totalSupply() + amount > MAX_SUPPLY) revert DecentralizedStableCoin__CouldNotMint();
        _mint(to, amount);
        return true;
    }

    /// @notice Burn DSC tokens — only callable by DSCEngine
    /// @param from The account to burn from
    /// @param amount The amount to burn
    function burn(address from, uint256 amount) external onlyEngine {
        _burn(from, amount);
    }

    /// @notice Returns the engine address
    function getEngine() external view returns (address) {
        return i_engine;
    }

    /// @notice Returns the max supply
    function getMaxSupply() external pure returns (uint256) {
        return MAX_SUPPLY;
    }
}
