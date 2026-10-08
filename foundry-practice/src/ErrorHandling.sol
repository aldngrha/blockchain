// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

/**
 * @title ErrorHandling
 * @dev Belajar perbedaan 'require' (old school) dan 'revert' (modern/hemat gas).
 */
contract ErrorHandling {
    address public owner;
    mapping(address => uint256) public balances;
    uint256 public totalSupply;
    uint256 constant MAX_SUPPLY = 1000;

    error NotOwner(address caller);
    error InsufficientBalance(uint256 available, uint256 required);
    error ZeroAddress();
    error ExceedsMaxSupply(uint256 current, uint256 max, uint256 requested);
    error ZeroAmount();

    constructor() {
        owner = msg.sender;
    }

    /**
     * @dev Deposit menggunakan 'require'.
     * Cocok untuk kondisi sederhana, tapi gas lebih mahal karena menyimpan string error.
     */
    function deposit(uint256 _amount) public {
        require(_amount > 0, "Amount must be greater than 0");
        require(totalSupply + _amount <= MAX_SUPPLY, "Exceeds max supply");

        balances[msg.sender] += _amount;
        totalSupply += _amount;
    }

    function withdraw(uint256 _amount) public {
        require(_amount > 0, "Amount must be greater than 0");
        require(balances[msg.sender] >= _amount, "Insufficient balance");

        balances[msg.sender] -= _amount;
        totalSupply -= _amount;
    }

    /**
     * @dev Transfer menggunakan 'revert' dengan Custom Error.
     * Jauh lebih hemat gas dan bisa mengirim parameter (misal: saldo yang tersedia).
     */
    function transfer(address _to, uint256 _amount) public {
        if (_to == address(0)) revert ZeroAddress();
        if (balances[msg.sender] < _amount) revert InsufficientBalance(balances[msg.sender], _amount);
        if (_amount == 0) revert ZeroAmount();

        balances[msg.sender] -= _amount;
        balances[_to] += _amount;
    }

    function mint(address _to, uint256 _amount) public {
        if (msg.sender != owner) revert NotOwner(msg.sender);
        if (_to == address(0)) revert ZeroAddress();
        if (totalSupply + _amount > MAX_SUPPLY) revert ExceedsMaxSupply(totalSupply, MAX_SUPPLY, _amount);

        balances[_to] += _amount;
        totalSupply += _amount;
    }

    function burn(uint256 _amount) public {
        if (balances[msg.sender] < _amount) revert InsufficientBalance(balances[msg.sender], _amount);

        balances[msg.sender] -= _amount;
        totalSupply -= _amount;
    }
}
