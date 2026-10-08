// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";

/// @title FeeOnTransferMock
/// @notice ERC-20 that skims a percentage of every transfer and burns it.
/// @dev Exists to prove that DexPair rejects fee-on-transfer tokens instead of
///      silently corrupting its reserve accounting.
contract FeeOnTransferMock is ERC20 {
    /// @notice Fee in basis points (100 = 1%).
    uint256 public immutable feeBps;

    constructor(
        string memory name_,
        string memory symbol_,
        uint256 feeBps_
    ) ERC20(name_, symbol_) {
        feeBps = feeBps_;
    }

    /// @notice Anyone can mint. Test-only convenience.
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    /// @dev Burns `feeBps` of every non-mint transfer directly from the sender,
    ///      so the receiver gets value - fee.
    function _update(address from, address to, uint256 value) internal override {
        if (from == address(0) || to == address(0)) {
            // Mint and burn paths are not taxed.
            super._update(from, to, value);
            return;
        }
        uint256 fee = (value * feeBps) / 10_000;
        if (fee > 0) {
            super._update(from, address(0), fee);
        }
        super._update(from, to, value - fee);
    }
}
