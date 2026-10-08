// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @title SimpleProxy
/// @notice Basic proxy contract — delegates all calls to an implementation contract
/// @dev Uses EIP-1967 storage slots to avoid collision with implementation storage
///      Slot: keccak256("eip1967.proxy.admin") - 1
contract SimpleProxy {
    // EIP-1967 admin slot — avoids collision with implementation storage
    // This stores at a pseudo-random slot that won't overlap with normal variables
    bytes32 private constant ADMIN_SLOT =
        0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    // EIP-1967 implementation slot
    bytes32 private constant IMPLEMENTATION_SLOT =
        0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    error SimpleProxy__NotAdmin();
    error SimpleProxy__ZeroAddress();

    event Upgraded(address indexed oldImpl, address indexed newImpl);

    modifier onlyAdmin() {
        if (msg.sender != _getAdmin()) revert SimpleProxy__NotAdmin();
        _;
    }

    constructor(address implementation) {
        if (implementation == address(0)) revert SimpleProxy__ZeroAddress();
        _setImplementation(implementation);
        _setAdmin(msg.sender);
    }

    /// @notice Delegate all calls to implementation contract
    fallback() external payable {
        _delegate(_getImplementation());
    }

    receive() external payable {}

    /// @notice Upgrade implementation (only admin)
    function upgradeTo(address newImplementation) external onlyAdmin {
        if (newImplementation == address(0)) revert SimpleProxy__ZeroAddress();
        address oldImpl = _getImplementation();
        _setImplementation(newImplementation);
        emit Upgraded(oldImpl, newImplementation);
    }

    /// @notice Get admin address
    function getAdmin() external view returns (address) {
        return _getAdmin();
    }

    /// @notice Get implementation address
    function getImplementation() external view returns (address) {
        return _getImplementation();
    }

    /*//////////////////////////////////////////////////////////////
                        EIP-1967 STORAGE
    //////////////////////////////////////////////////////////*/

    function _getAdmin() internal view returns (address) {
        bytes32 slot = ADMIN_SLOT;
        address admin;
        assembly {
            admin := sload(slot)
        }
        return admin;
    }

    function _setAdmin(address newAdmin) internal {
        bytes32 slot = ADMIN_SLOT;
        assembly {
            sstore(slot, newAdmin)
        }
    }

    function _getImplementation() internal view returns (address impl) {
        bytes32 slot = IMPLEMENTATION_SLOT;
        assembly {
            impl := sload(slot)
        }
    }

    function _setImplementation(address newImpl) internal {
        bytes32 slot = IMPLEMENTATION_SLOT;
        assembly {
            sstore(slot, newImpl)
        }
    }

    /*//////////////////////////////////////////////////////////////
                        DELEGATECALL
    //////////////////////////////////////////////////////////*/

    function _delegate(address implementation) internal {
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), implementation, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }
}
