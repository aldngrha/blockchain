// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title RebaseToken
 * @notice Cross-chain rebase token — supply adjusts automatically across chains
 * @dev This is the STARTER contract for Cyfrin Advanced Foundry Section 4
 *      Follow the Cyfrin course to implement the full cross-chain logic with Chainlink CCIP
 */
contract RebaseToken is ERC20, Ownable {
    uint256 private constant MAX_SUPPLY = 100_000_000 * 10 ** 18; // 100M tokens

    mapping(address => uint256) private _balancesBeforeRebase;
    uint256 private _totalSupplyMultiplier; // basis points (10000 = 1x)

    error RebaseToken__ExceedsMaxSupply();
    error RebaseToken__ZeroAmount();

    event RebaseApplied(uint256 oldMultiplier, uint256 newMultiplier);

    constructor() ERC20("RebaseToken", "RBT") Ownable(msg.sender) {
        _totalSupplyMultiplier = 10000; // 1x = 10000 basis points
    }

    /**
     * @notice Apply a rebase multiplier (called by bridge/keeper)
     * @param newMultiplier New multiplier in basis points (10000 = 1x, 11000 = 1.1x)
     */
    function rebase(uint256 newMultiplier) external onlyOwner {
        uint256 oldMultiplier = _totalSupplyMultiplier;
        _totalSupplyMultiplier = newMultiplier;
        emit RebaseApplied(oldMultiplier, newMultiplier);
    }

    /**
     * @notice Get the current balance adjusted by the rebase multiplier
     * @dev balanceOf returns the raw balance; this returns the effective balance
     */
    function effectiveBalanceOf(address account) public view returns (uint256) {
        return (balanceOf(account) * _totalSupplyMultiplier) / 10000;
    }

    /**
     * @notice Get the total supply adjusted by the rebase multiplier
     */
    function effectiveTotalSupply() public view returns (uint256) {
        return (totalSupply() * _totalSupplyMultiplier) / 10000;
    }

    function getMultiplier() external view returns (uint256) {
        return _totalSupplyMultiplier;
    }

    function mint(address to, uint256 amount) external onlyOwner {
        if (totalSupply() + amount > MAX_SUPPLY) revert RebaseToken__ExceedsMaxSupply();
        if (amount == 0) revert RebaseToken__ZeroAmount();
        _mint(to, amount);
    }
}
