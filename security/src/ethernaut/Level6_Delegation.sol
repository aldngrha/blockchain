// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Delegator (Ethernaut Level 6 - Factory)
 * @notice Deploys Delegation contracts
 */
contract Delegator {
    address public owner;
    Delegation public delegate;

    constructor(address _delegate) {
        owner = msg.sender;
        delegate = Delegation(_delegate);
    }

    // ⚠️ When ETH received → delegatecall to Delegation.pwn()
    receive() external payable {
        // delegatecall runs pwn() in Delegator's context
        // msg.sender = Delegator (NOT Delegation!)
        // So owner in Delegator gets set to Delegator's address
        (bool success,) = address(delegate).delegatecall(
            abi.encodeWithSignature("pwn()")
        );
        require(success);
    }
}

/**
 * @title Delegation (Ethernaut Level 6)
 * @notice Vulnerable: delegatecall hijack storage
 *
 * EXPLOIT:
 * - Delegation has pwn() that sets owner = msg.sender
 * - Delegator delegatecalls Delegation.pwn() when receiving ETH
 * - In delegatecall: storage is Delegator's, msg.sender = Delegator
 * - So Delegator.owner becomes Delegator's address (msg.sender)
 *
 * Wait... that's not the exploit. Let me re-read.
 *
 * ACTUAL EXPLOIT:
 * - Delegator has public `owner` and `delegate`
 * - When Delegator receives ETH, it delegatecalls Delegation.pwn()
 * - pwn() sets `owner = msg.sender`
 * - In delegatecall context, storage is Delegator's storage
 * - msg.sender = Delegator address (since Delegator calls delegate)
 * - So Delegator.owner = Delegator address → original owner loses ownership
 *
 * Actually the real exploit is:
 * - User calls Delegator's receive() by sending ETH
 * - But user doesn't control msg.sender (it's Delegator)
 *
 * CORRECT FLOW:
 * 1. User sends ETH to Delegator
 * 2. Delegator receives → delegatecall Delegation.pwn()
 * 3. In Delegation.pwn(): owner = msg.sender (Delegator)
 * 4. Delegator.owner = Delegator.address
 * 5. BUT... the user wants to set owner to THEMSELVES
 *
 * Hmm, let me re-read the actual Ethernaut challenge.
 *
 * ACTUAL ETHernaut Level 6:
 * - Delegator contract with owner
 * - Delegation contract with pwn() function
 * - User needs to become owner of Delegator
 * - Exploit: send transaction to Delegation that triggers pwn()
 *   OR: call Delegation's pwn() directly → msg.sender = user
 *   In delegatecall context, user becomes owner of Delegator
 */
contract Delegation {
    address public owner;

    constructor(address _owner) {
        owner = _owner;
    }

    function pwn() public {
        owner = msg.sender;
    }
}
