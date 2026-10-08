// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title AssemblyCalls
 * @notice Assembly (Yul) & Low-Level Calls: powerful tapi berbahaya
 * @dev May 13 — Kapan pakai dan kapan JANGAN pakai
 *
 * 3 jenis low-level call:
 * 1. call()     — Regular call, bisa kirim ETH, ganti context
 * 2. delegatecall() — Panggil kode lain, TAPI state tetap di contract ini
 * 3. staticcall()   — Read-only call, tidak boleh ubah state
 */
contract AssemblyCalls {
    address public owner;

    event CallResult(bool success, bytes data);

    constructor() {
        owner = msg.sender;
    }

    // ================================================================
    // 1. REGULAR CALL — Kirim ETH + data ke address lain
    // ================================================================

    /**
     * @notice Kirim ETH ke address lain pakai call()
     * @dev Standar modern untuk transfer ETH
     */
    function sendETH(address payable to, uint256 amount) external returns (bool) {
        (bool success,) = to.call{value: amount}("");
        return success;
    }

    /**
     * @notice Kirim ETH + panggil fungsi di contract lain
     * @dev call() bisa kirim ETH + data sekaligus
     */
    function callWithPayload(
        address target,
        uint256 value,
        bytes calldata data
    ) external returns (bool success, bytes memory returnData) {
        (success, returnData) = target.call{value: value}(data);
        emit CallResult(success, returnData);
    }

    // ================================================================
    // 2. DELEGATECALL — Panggil kode lain, state tetap di sini
    // ================================================================

    /**
     * @notice Delegatecall ke contract lain
     * @dev KODE dari target dijalankan, tapi STATE tetap di contract INI
     *      BERBAHAYA jika target contract tidak trusted!
     *
     *   Regular Call:        Delegatecall:
     *   ┌──────────┐         ┌──────────┐
     *   │ Contract │         │ Contract │
     *   │   Code   │         │   Code   │ ← dari target
     *   │  State A │         │  State A │ ← state tetap di sini!
     *   └──────────┘         └──────────┘
     */
    function delegateCall(address target, bytes calldata data) external returns (bool, bytes memory) {
        (bool success, bytes memory returnData) = target.delegatecall(data);
        return (success, returnData);
    }

    // ================================================================
    // 3. STATICCALL — Read-only, tidak boleh ubah state
    // ================================================================

    /**
     * @notice Static call — read-only
     * @dev Target TIDAK BOLEH ubah state
     *      Berguna untuk baca data dari contract lain
     */
    function staticCall(address target, bytes calldata data) external view returns (bool, bytes memory) {
        (bool success, bytes memory returnData) = target.staticcall(data);
        return (success, returnData);
    }

    // ================================================================
    // 4. INLINE ASSEMBLY (YUL) — Super powerful, super dangerous
    // ================================================================

    /**
     * @notice Contoh inline assembly untuk fetch balance
     * @dev Assembly = bahasa level rendah EVM
     *      Lebih hemat gas, tapi SUSAH dibaca dan rawan bug
     */
    function getBalanceAssembly(address account) external view returns (uint256 bal) {
        assembly {
            // BALANCE opcode — cek ETH balance
            bal := balance(account)
        }
    }

    /**
     * @notice Contoh assembly untuk store value
     * @dev Sangat hemat gas untuk operasi sederhana
     */
    function storeValue(uint256 slot, uint256 value) external {
        assembly {
            // SSTORE — simpan value ke storage slot
            sstore(slot, value)
        }
    }

    /**
     * @notice Contoh assembly: send ETH tanpa gas limit specifik
     * @dev Call dengan gas forwarding
     */
    function sendETHAssembly(address payable to, uint256 amount) external returns (bool success) {
        assembly {
            // Kirim ETH pakai call
            success := call(gas(), to, amount, 0, 0, 0, 0)
        }
    }

    /**
     * @notice Membaca calldata langsung pakai assembly
     * @dev Ultra-efficient untuk fungsi yang dipanggil sering
     */
    function readCalldata() external pure returns (uint256 first, uint256 second) {
        assembly {
            // Load 32 bytes pertama dari calldata
            first := calldataload(0)
            // Load 32 bytes kedua dari calldata
            second := calldataload(32)
        }
    }

    // ================================================================
    // 5. FALLBACK & RECEIVE — Assembly-based
    // ================================================================

    /**
     * @notice Receive ETH tanpa data
     * @dev Bisa pakai assembly untuk ultra-efficient receive
     */
    receive() external payable {
        // Simpan sender dan amount di storage untuk tracking
        assembly {
            // Store msg.sender di slot 0
            sstore(0, caller())
            // Store msg.value di slot 1
            sstore(1, callvalue())
        }
    }

    /**
     * @notice Fallback — dipanggil kalau tidak ada fungsi yang match
     */
    fallback() external payable {
        // Forward semua call ke owner
        assembly {
            let result := delegatecall(gas(), caller(), 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }

    // ================================================================
    // VIEW FUNCTIONS
    // ================================================================

    function getOwner() external view returns (address) {
        return owner;
    }
}

/**
 * @title TargetContract
 * @notice Contract lain yang bisa di-call oleh AssemblyCalls
 */
contract TargetContract {
    uint256 public value;

    function setValue(uint256 _value) external {
        value = _value;
    }

    function getValue() external view returns (uint256) {
        return value;
    }

    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }
}
