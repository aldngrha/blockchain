// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Token (Ethernaut Level 5)
 * @notice Vulnerable: integer underflow di transfer()
 *
 * EXPLOIT:
 * - Contract punya 20 tokens
 * - Transfer 21 tokens → balance = 20 - 21 = ??
 * - Di Solidity <0.8: underflow → balance jadi MAX_UINT256
 * - Di Solidity 0.8+: revert (overflow protection)
 *
 * NOTE: Original Ethernaut pakai Solidity <0.8
 * Untuk demo di 0.8+, kita pakai unchecked block
 */
contract Token {
    mapping(address => uint256) public balances;
    uint256 public totalSupply;

    constructor(uint256 _initialSupply) {
        balances[msg.sender] = _initialSupply;
        totalSupply = _initialSupply;
    }

    function transfer(address _to, uint256 _value) public returns (bool) {
        // ⚠️ BUG: gak ada check balances[msg.sender] >= _value
        // Di Solidity <0.8: underflow → balance jadi MAX_UINT256
        // Di Solidity 0.8+: pakai unchecked buat demo
        unchecked {
            balances[msg.sender] -= _value;
        }
        balances[_to] += _value;
        return true;
    }
}
