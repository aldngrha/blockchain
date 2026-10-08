// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title SimpleAccount
 * @notice Simplified ERC-4337 Account Abstraction account
 * @dev This is the STARTER contract for Cyfrin Advanced Foundry Section 7
 *      Follow the Cyfrin course to implement the full AA logic with EntryPoint
 *
 * Key Concepts:
 * - UserOperation: A struct that represents a user's intent (like a transaction but for AA)
 * - EntryPoint: A singleton contract that validates and executes UserOperations
 * - validateUserOp: Validates that the signature is valid
 * - execute: Executes the actual call
 */
contract SimpleAccount {
    address public owner;
    address public entryPoint;

    error SimpleAccount__NotOwner();
    error SimpleAccount__NotEntryPoint();
    error SimpleAccount__InvalidSignature();

    event UserOpExecuted(address indexed target, uint256 value, bytes data);

    modifier onlyOwner() {
        if (msg.sender != owner) revert SimpleAccount__NotOwner();
        _;
    }

    modifier onlyEntryPoint() {
        if (msg.sender != entryPoint) revert SimpleAccount__NotEntryPoint();
        _;
    }

    constructor(address _owner, address _entryPoint) {
        owner = _owner;
        entryPoint = _entryPoint;
    }

    /**
     * @notice Validate a UserOperation
     * @dev Called by the EntryPoint before executing the UserOperation
     * @param userOpHash Hash of the UserOperation
     * @param signature Signature from the owner
     * @return validationData 0 for success, non-zero for failure
     */
    function validateUserOp(
        bytes32 userOpHash,
        bytes calldata signature
    ) external onlyEntryPoint returns (uint256 validationData) {
        // TODO: Verify ECDSA signature against owner
        // bytes32 ethSignedHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", userOpHash));
        // address signer = ECDSA.recover(ethSignedHash, signature);
        // if (signer != owner) return 1; // failure
        return 0; // success
    }

    /**
     * @notice Execute a call from the account
     * @dev Called by the EntryPoint after validation
     */
    function execute(address dest, uint256 value, bytes calldata func) external onlyEntryPoint {
        (bool success,) = dest.call{value: value}(func);
        require(success, "SimpleAccount: call failed");
        emit UserOpExecuted(dest, value, func);
    }

    receive() external payable {}
}
