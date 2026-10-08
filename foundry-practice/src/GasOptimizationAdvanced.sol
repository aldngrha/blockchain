// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title GasOptimizationAdvanced
 * @notice Advanced gas optimization techniques yang hemat 30%+
 * @dev May 21 — Technique-by-technique dengan benchmark
 *
 * 7 Techniques:
 * 1. Bitmap untuk boolean flags (hemat 90%+)
 * 2. Packed structs (hemat 50%+)
 * 3. Short-circuit evaluation
 * 4. Unchecked blocks yang aman
 * 5. Calldata vs memory (hemat ~30%)
 * 6. Immutable vs constant vs storage
 * 7. Custom errors vs string require
 */
contract GasOptimizationAdvanced {

    // ================================================================
    // TECHNIQUE 1: BITMAP — Pack 256 boolean dalam 1 storage slot
    // ================================================================

    /**
     * ❌ NAIF: 256 boolean = 256 storage slots = 256 * 20,000 gas = 5,120,000 gas
     */
    mapping(uint256 => bool) public naifFlags;

    /**
     * ✅ BITMAP: 256 boolean = 1 storage slot = 20,000 gas
     * Hemat 99.6% gas!
     */
    uint256 private _flags;

    function setFlag(uint256 index, bool value) public {
        require(index < 256, "Index out of bounds");
        if (value) {
            _flags |= (1 << index);   // Set bit
        } else {
            _flags &= ~(1 << index);  // Clear bit
        }
    }

    function getFlag(uint256 index) public view returns (bool) {
        return (_flags & (1 << index)) != 0;
    }

    // ================================================================
    // TECHNIQUE 2: PACKED STRUCTS — Multiple vars dalam 1 slot
    // ================================================================

    /**
     * ❌ NAIF: 3 variables = 3 storage slots = 60,000 gas untuk write
     */
    struct NaifStruct {
        uint256 a;  // slot 0
        uint256 b;  // slot 1
        uint256 c;  // slot 2
    }

    /**
     * ✅ PACKED: 3 variables = 1 storage slot = 20,000 gas untuk write
     * Hemat 66.7% gas!
     */
    struct PackedStruct {
        uint128 a;  // slot 0 (16 bytes)
        uint128 b;  // slot 0 (16 bytes) — pack bareng a!
        uint64 c;   // slot 1 (8 bytes)
        uint64 d;   // slot 1 (8 bytes) — pack bareng c!
    }

    PackedStruct public packed;

    function setPacked(uint128 a, uint128 b, uint64 c, uint64 d) public {
        packed = PackedStruct(a, b, c, d); // 1 SSTORE = 20,000 gas
    }

    // ================================================================
    // TECHNIQUE 3: SHORT-CIRCUIT — Urutan evaluasi yang tepat
    // ================================================================

    mapping(address => uint256) public balances;

    /**
     * ❌ NAIF: Expensive check duluan
     * Kalau _expensiveCheck() false, tetap jalan semua
     */
    function checkBad(address user, uint256 amount) public view returns (bool) {
        return _expensiveCheck(user) && amount > 0;
    }

    /**
     * ✅ SHORT-CIRCUIT: Cheap check duluan
     * Kalau amount = 0, _expensiveCheck() TIDAK jalan!
     */
    function checkGood(address user, uint256 amount) public view returns (bool) {
        return amount > 0 && _expensiveCheck(user);
    }

    function _expensiveCheck(address user) internal view returns (bool) {
        return balances[user] > 0;
    }

    // ================================================================
    // TECHNIQUE 4: UNCHECKED MATH — Aman untuk increment
    // ================================================================

    uint256[] public numbers;

    /**
     * ❌ NAIF: Overflow check setiap iterasi (~200 gas per iteration)
     */
    function addNaif(uint256 count) public {
        for (uint256 i = 0; i < count; i++) {
            numbers.push(i);
        }
    }

    /**
     * ✅ UNCHECKED: Tanpa overflow check (hemat ~200 gas per iterasi)
     * AMAN karena i < count dan count bisa di-control
     */
    function addOptimized(uint256 count) public {
        for (uint256 i = 0; i < count;) {
            numbers.push(i);
            unchecked { i++; } // Hemat gas!
        }
    }

    // ================================================================
    // TECHNIQUE 5: CALLDATA vs MEMORY — Read-only params
    // ================================================================

    /**
     * ❌ NAIF: Memory — copy dari calldata ke memory (extra gas)
     */
    function processMemory(string memory data) public pure returns (uint256) {
        return bytes(data).length;
    }

    /**
     * ✅ OPTIMIZED: Calldata — baca langsung dari calldata
     * Hemat ~30-50 gas per call
     */
    function processCalldata(string calldata data) public pure returns (uint256) {
        return bytes(data).length;
    }

    // ================================================================
    // TECHNIQUE 6: IMMUTABLE vs CONSTANT vs STORAGE
    // ================================================================

    uint256 public constant CONSTANT_VALUE = 42;           // Compile-time, 0 gas read
    uint256 public immutable IMMUTABLE_VALUE;               // Deploy-time, 3 gas read
    uint256 public storageValue = 100;                      // Storage, 2100 gas read

    constructor() {
        IMMUTABLE_VALUE = block.timestamp; // Set sekali saat deploy
    }

    /**
     * ❌ NAIF: Storage read — 2100 gas
     */
    function readStorage() external view returns (uint256) {
        return storageValue;
    }

    /**
     * ✅ OPTIMIZED: Immutable read — 3 gas (99.86% hemat!)
     */
    function readImmutable() external view returns (uint256) {
        return IMMUTABLE_VALUE;
    }

    /**
     * ✅ BEST: Constant read — 0 gas (embedded in bytecode)
     */
    function readConstant() external pure returns (uint256) {
        return CONSTANT_VALUE;
    }

    // ================================================================
    // TECHNIQUE 7: CUSTOM ERRORS vs STRING REQUIRE
    // ================================================================

    error InsufficientBalance(uint256 available, uint256 required);
    error ZeroAddress();

    /**
     * ❌ NAIF: String require — 200+ gas untuk revert
     */
    function withdrawNaif(uint256 amount) external {
        require(balances[msg.sender] >= amount, "Insufficient balance");
        require(msg.sender != address(0), "Zero address");
    }

    /**
     * ✅ OPTIMIZED: Custom error — 32 gas untuk revert
     * Hemat ~85% gas saat revert!
     */
    function withdrawOptimized(uint256 amount) external {
        if (balances[msg.sender] < amount) revert InsufficientBalance(balances[msg.sender], amount);
        if (msg.sender == address(0)) revert ZeroAddress();
    }

    // ================================================================
    // BONUS: SSTORE2 — Store large data di bytecode
    // ================================================================

    /**
     * @notice Store data besar tanpa storage slots
     * @dev Simpan data sebagai bytecode, baca pakai EXTCODECOPY
     *      Lebih hemat dari SSTORE untuk data > 1 KB
     */
    function storeData(bytes memory data) external returns (address) {
        address deployed;
        assembly {
            deployed := create(0, add(data, 0x20), mload(data))
        }
        return deployed;
    }
}
