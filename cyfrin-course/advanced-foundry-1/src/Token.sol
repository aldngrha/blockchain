// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract Token is ERC20, Ownable {
    uint256 private constant MAX_SUPPLY = 1_000_000 * 10 ** 18; // 1 million tokens

    error Token__MoreThanMaxSupply();
    error Token__ZeroTokens();

    constructor(string memory name, string memory symbol, uint256 initialSupply) ERC20(name, symbol) Ownable(msg.sender) {
        _mint(msg.sender, initialSupply);
    }

    /// @notice Owner can mint tokens up to MAX_SUPPLY
    function mint(address to, uint256 amount) external onlyOwner {
        if (totalSupply() + amount > MAX_SUPPLY) revert Token__MoreThanMaxSupply();
        if (amount == 0) revert Token__ZeroTokens();
        _mint(to, amount);
    }

    /// @notice Anyone can burn their own tokens
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }

    /// @notice Owner can gift tokens to multiple addresses
    function gift(address[] calldata recipients, uint256[] calldata amounts) external onlyOwner {
        if (recipients.length != amounts.length) revert("Length mismatch");
        for (uint256 i = 0; i < recipients.length; i++) {
            if (totalSupply() + amounts[i] > MAX_SUPPLY) revert Token__MoreThanMaxSupply();
            _mint(recipients[i], amounts[i]);
        }
    }

    /// @notice Returns the max supply of the token
    function getMaxSupply() external pure returns (uint256) {
        return MAX_SUPPLY;
    }
}
