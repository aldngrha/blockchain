// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title EventsDeepDive
 * @notice Events & Logs: cara kontrak "berteriak" ke dunia luar
 * @dev May 12 — Events vs Storage, indexed parameters, off-chain querying
 *
 * Key Concepts:
 * - Events = cheap storage (log vs sstore)
 * - Max 3 indexed parameters per event
 * - Indexed parameters bisa di-filter (topic0, topic1, topic2)
 * - Non-indexed parameters = data (tidak bisa di-filter, tapi lebih murah)
 * - Events TIDAK BISA dibaca oleh kontrak lain
 * - Events BISA dibaca oleh frontend/off-chain via getLogs()
 */
contract EventsDeepDive {
    // ================================================================
    // BASIC EVENTS
    // ================================================================

    // Simple event — tidak ada indexed parameter
    event SimpleEvent(uint256 value, string message);

    // Event dengan indexed parameters (bisa di-filter)
    event Transfer(
        address indexed from,    // topic1 — bisa filter by sender
        address indexed to,      // topic2 — bisa filter by receiver
        uint256 indexed amount,  // topic3 — bisa filter by amount (HASHED)
        string memo              // data — tidak bisa filter, tapi bisa dibaca
    );

    // Event dengan semua indexed (maksimal 3!)
    event MaxIndexed(
        address indexed a,  // topic1
        address indexed b,  // topic2
        uint256 indexed c   // topic3
        // TIDAK BOLEH lebih dari 3 indexed!
    );

    // Event tanpa indexed (semua jadi data)
    event AllData(uint256 a, uint256 b, string c);

    // ================================================================
    // EVENTS UNTUK TRACKING STATE
    // ================================================================

    event Deposited(address indexed user, uint256 amount, uint256 timestamp);
    event Withdrawn(address indexed user, uint256 amount);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    // ================================================================
    // EVENTS UNTUK FRONTEND INDEXING (The Graph compatible)
    // ================================================================

    event ItemCreated(
        uint256 indexed itemId,
        address indexed creator,
        string name,
        uint256 price,
        bool isActive
    );

    event ItemUpdated(
        uint256 indexed itemId,
        string name,
        uint256 price
    );

    event ItemSold(
        uint256 indexed itemId,
        address indexed buyer,
        address indexed seller,
        uint256 price
    );

    // ================================================================
    // STATE VARIABLES
    // ================================================================

    mapping(address => uint256) public balances;
    uint256 public totalDeposits;
    address public owner;

    struct Item {
        string name;
        uint256 price;
        address creator;
        bool isActive;
    }

    mapping(uint256 => Item) public items;
    uint256 public itemCount;

    constructor() {
        owner = msg.sender;
    }

    // ================================================================
    // FUNCTIONS WITH EVENTS
    // ================================================================

    function deposit() external payable {
        balances[msg.sender] += msg.value;
        totalDeposits += msg.value;

        // ✅ Emit event — off-chain bisa track ini
        emit Deposited(msg.sender, msg.value, block.timestamp);
    }

    function withdraw(uint256 amount) external {
        require(balances[msg.sender] >= amount, "Insufficient balance");
        balances[msg.sender] -= amount;
        totalDeposits -= amount;

        (bool success,) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");

        emit Withdrawn(msg.sender, amount);
    }

    function createItem(string calldata name, uint256 price) external returns (uint256) {
        uint256 itemId = itemCount;
        itemCount++;

        items[itemId] = Item({
            name: name,
            price: price,
            creator: msg.sender,
            isActive: true
        });

        // ✅ Event untuk indexing — The Graph bisa index ini
        emit ItemCreated(itemId, msg.sender, name, price, true);

        return itemId;
    }

    function updateItem(uint256 itemId, string calldata name, uint256 price) external {
        require(items[itemId].creator == msg.sender, "Not creator");
        items[itemId].name = name;
        items[itemId].price = price;

        emit ItemUpdated(itemId, name, price);
    }

    function buyItem(uint256 itemId) external payable {
        Item storage item = items[itemId];
        require(item.isActive, "Item not active");
        require(msg.value >= item.price, "Insufficient payment");
        require(msg.sender != item.creator, "Cannot buy own item");

        // Transfer payment to creator
        (bool success,) = item.creator.call{value: msg.value}("");
        require(success, "Payment failed");

        // Emit event
        emit ItemSold(itemId, msg.sender, item.creator, msg.value);
    }

    // ================================================================
    // VIEW FUNCTIONS (events tidak bisa dibaca dari dalam kontrak!)
    // ================================================================

    /**
     * @notice Events TIDAK BISA dibaca dari dalam kontrak
     * @dev Ini bedanya events vs storage
     */
    function getBalance(address user) external view returns (uint256) {
        return balances[user]; // ✅ Storage — bisa dibaca kontrak lain
    }
}
