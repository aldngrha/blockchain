// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

// Base contract untuk ownership
contract Ownable {
    address public owner;

    error NotOwner(address caller);

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner(msg.sender);
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function transferOwnership(address _newOwner) public onlyOwner {
        require(_newOwner != address(0), "Zero address");
        owner = _newOwner;
    }
}

// Base contract untuk pause
contract Pausable is Ownable {
    bool public paused;

    error ContractPaused();

    event Paused(address indexed by);
    event Unpaused(address indexed by);

    modifier whenNotPaused() {
        if (paused) revert ContractPaused();
        _;
    }

    function pause() public onlyOwner {
        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() public onlyOwner {
        paused = false;
        emit Unpaused(msg.sender);
    }
}

// Main contract — inherit dari Pausable (yang sudah inherit Ownable)
contract WhitelistMinter is Pausable {

    // ── State Variables ────────────────────────────────
    uint256 public maxSupply;
    uint256 public totalMinted;
    uint256 public mintPrice;

    mapping(address => bool) public whitelist;
    mapping(address => uint256) public mintedCount;

    // ── Events ────────────────────────────────────────
    event Whitelisted(address indexed account);
    event RemovedFromWhitelist(address indexed account);
    event Minted(address indexed to, uint256 amount, uint256 totalMinted);

    // ── Custom Errors ─────────────────────────────────
    error NotWhitelisted(address caller);
    error ExceedsMaxSupply(uint256 requested, uint256 available);
    error InsufficientPayment(uint256 sent, uint256 required);
    error AlreadyWhitelisted(address account);
    error NotInWhitelist(address account);

    // ── Modifiers ─────────────────────────────────────
    modifier onlyWhitelisted() {
        if (!whitelist[msg.sender]) revert NotWhitelisted(msg.sender);
        _;
    }

    modifier hasSupply(uint256 _amount) {
        uint256 available = maxSupply - totalMinted;
        if (_amount > available) revert ExceedsMaxSupply(_amount, available);
        _;
    }

    // ── Constructor ───────────────────────────────────
    constructor(uint256 _maxSupply, uint256 _mintPrice) {
        maxSupply = _maxSupply;
        mintPrice = _mintPrice;
    }

    // ── Whitelist Management ──────────────────────────

    function addToWhitelist(address _account) public onlyOwner {
        if (whitelist[_account]) revert AlreadyWhitelisted(_account);
        whitelist[_account] = true;
        emit Whitelisted(_account);
    }

    // tambah banyak address sekaligus — lebih efisien
    function addBatchToWhitelist(address[] calldata _accounts) public onlyOwner {
        for (uint256 i = 0; i < _accounts.length; i++) {
            if (!whitelist[_accounts[i]]) {
                whitelist[_accounts[i]] = true;
                emit Whitelisted(_accounts[i]);
            }
        }
    }

    function removeFromWhitelist(address _account) public onlyOwner {
        if (!whitelist[_account]) revert NotInWhitelist(_account);
        whitelist[_account] = false;
        emit RemovedFromWhitelist(_account);
    }

    // ── Minting ───────────────────────────────────────

    function mint(uint256 _amount)
        public
        payable
        whenNotPaused
        onlyWhitelisted
        hasSupply(_amount)
    {
        uint256 totalCost = mintPrice * _amount;
        if (msg.value < totalCost) {
            revert InsufficientPayment(msg.value, totalCost);
        }

        totalMinted += _amount;
        mintedCount[msg.sender] += _amount;

        emit Minted(msg.sender, _amount, totalMinted);

        // refund kelebihan ETH kalau user kirim lebih
        if (msg.value > totalCost) {
            payable(msg.sender).transfer(msg.value - totalCost);
        }
    }

    // ── Revenue ───────────────────────────────────────

    function withdraw() public onlyOwner {
        payable(owner).transfer(address(this).balance);
    }

    // ── Views ─────────────────────────────────────────

    function remainingSupply() public view returns (uint256) {
        return maxSupply - totalMinted;
    }

    function isWhitelisted(address _account) public view returns (bool) {
        return whitelist[_account];
    }
}
