// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

contract GasOptimization {

    // ── 1. STORAGE PACKING ────────────────────────────
    // Contoh packing — variabel diurutkan supaya pack dalam 1 slot
    // uint128 + uint128 = 32 bytes = 1 slot ✓
    uint128 public a;
    uint128 public c; // pack bareng a dalam 1 slot
    uint256 public b; // slot sendiri

    // ── 2. STORAGE vs MEMORY ──────────────────────────
    uint256[] public numbers;

    function addNumbers(uint256 _count) public {
        for (uint256 i = 0; i < _count;) {
            numbers.push(i);
            unchecked { i++; }
        }
    }

    // BURUK — SLOAD setiap iterasi
    function sumBad() public view returns (uint256 total) {
        for (uint256 i = 0; i < numbers.length; i++) {
            total += numbers[i];
        }
    }

    // BAGUS — copy ke memory dulu, 1x SLOAD
    function sumGood() public view returns (uint256 total) {
        uint256[] memory _numbers = numbers;
        uint256 len = _numbers.length;
        for (uint256 i = 0; i < len;) {
            total += _numbers[i];
            unchecked { i++; }
        }
    }

    // BAGUS — calldata lebih murah dari memory untuk parameter
    function sumCalldata(uint256[] calldata _data)
        public
        pure
        returns (uint256 total)
    {
        for (uint256 i = 0; i < _data.length;) {
            total += _data[i];
            unchecked { i++; }
        }
    }

    // ── 3. UNCHECKED MATH ─────────────────────────────

    function loopBad(uint256 n) public pure returns (uint256 total) {
        for (uint256 i = 0; i < n; i++) {
            total += i;
        }
    }

    function loopGood(uint256 n) public pure returns (uint256 total) {
        for (uint256 i = 0; i < n;) {
            total += i;
            unchecked { i++; }
        }
    }

    // ── 4. CUSTOM ERRORS vs STRING ────────────────────

    error CustomError(address caller, uint256 value);

    function revertString() public pure {
        revert("This string costs more gas to store and revert");
    }

    function revertCustom() public view {
        revert CustomError(msg.sender, 42);
    }

    // ── 5. CONSTANT vs IMMUTABLE vs STORAGE ───────────

    uint256 public constant  MAX_SUPPLY  = 10000;
    uint256 public immutable deployTime;
    address public immutable deployer;
    uint256 public           mutableValue = 42;

    constructor() {
        deployTime = block.timestamp;
        deployer   = msg.sender;
    }

    // ── 6. MAPPING vs ARRAY ───────────────────────────

    mapping(address => uint256) public balanceMap;
    address[] public holders;

    function getBalance(address _user) public view returns (uint256) {
        return balanceMap[_user]; // O(1)
    }

    function findHolder(address _user) public view returns (bool) {
        for (uint256 i = 0; i < holders.length;) {
            if (holders[i] == _user) return true;
            unchecked { i++; }
        }
        return false;
    }

    // ── 7. SHORT CIRCUIT ──────────────────────────────

    function checkBad(address _user, uint256 _amount) public view returns (bool) {
        return _expensiveCheck(_user) && _amount > 0;
    }

    function checkGood(address _user, uint256 _amount) public view returns (bool) {
        return _amount > 0 && _expensiveCheck(_user);
    }

    function _expensiveCheck(address _user) internal view returns (bool) {
        return balanceMap[_user] > 0;
    }
}
