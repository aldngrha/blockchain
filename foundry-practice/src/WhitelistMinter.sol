// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

/**
 * @dev Kontrak dasar Ownership.
 */
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

/**
 * @dev Kontrak dasar untuk fitur Jeda (Pause).
 */
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

/**
 * @title WhitelistMinter
 * @dev Contoh sistem Minting Token (seperti NFT Launchpad) dengan daftar Whitelist.
 */
contract WhitelistMinter is Pausable {
    uint256 public maxSupply;     // Maksimal total koin/NFT yang bisa dicetak
    uint256 public totalMinted;   // Jumlah yang sudah dicetak saat ini
    uint256 public mintPrice;     // Harga per 1 cetakan

    mapping(address => bool)    public whitelist;   // Siapa saja yang boleh beli
    mapping(address => uint256) public mintedCount; // Berapa banyak yang sudah dibeli tiap orang

    event Whitelisted(address indexed account);
    event RemovedFromWhitelist(address indexed account);
    event Minted(address indexed to, uint256 amount, uint256 totalMinted);

    error NotWhitelisted(address caller);
    error ExceedsMaxSupply(uint256 requested, uint256 available);
    error InsufficientPayment(uint256 sent, uint256 required);
    error AlreadyWhitelisted(address account);
    error NotInWhitelist(address account);

    modifier onlyWhitelisted() {
        if (!whitelist[msg.sender]) revert NotWhitelisted(msg.sender);
        _;
    }

    modifier hasSupply(uint256 _amount) {
        uint256 available = maxSupply - totalMinted;
        if (_amount > available) revert ExceedsMaxSupply(_amount, available);
        _;
    }

    constructor(uint256 _maxSupply, uint256 _mintPrice) {
        maxSupply  = _maxSupply;
        mintPrice  = _mintPrice;
    }

    // --- Whitelist Management ---

    function addToWhitelist(address _account) public onlyOwner {
        if (whitelist[_account]) revert AlreadyWhitelisted(_account);
        whitelist[_account] = true;
        emit Whitelisted(_account);
    }

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

    /**
     * @dev Fungsi inti Minting.
     * Syarat: Tidak dipause, terdaftar di whitelist, dan supply masih tersedia.
     */
    function mint(uint256 _amount) public payable whenNotPaused onlyWhitelisted hasSupply(_amount) {
        uint256 totalCost = mintPrice * _amount;
        if (msg.value < totalCost) revert InsufficientPayment(msg.value, totalCost);

        totalMinted += _amount;
        mintedCount[msg.sender] += _amount;

        emit Minted(msg.sender, _amount, totalMinted);

        // Refund (Kembalian): Jika user bayar lebih, kembalikan sisanya.
        if (msg.value > totalCost) {
            (bool success, ) = payable(msg.sender).call{value: msg.value - totalCost}("");
            require(success, "Refund failed.");
        }
    }

    /**
     * @dev Tarik semua hasil penjualan ke kantong Owner.
     */
    function withdraw() public onlyOwner {
        (bool success, ) = payable(owner).call{value: address(this).balance}("");
        require(success, "Transfer failed.");
    }

    function remainingSupply() public view returns (uint256) {
        return maxSupply - totalMinted;
    }
}
