# Example Audit Findings — ExampleVulnerable.sol

> Ini adalah contoh findings dari audit ExampleVulnerable.sol.
> Gunakan sebagai referensi format audit report.

---

## Finding 1: CRITICAL — Reentrancy in `withdraw()`

| Field | Value |
|-------|-------|
| **Severity** | 🔴 CRITICAL |
| **Title** | Reentrancy Vulnerability in `withdraw()` |
| **Location** | `ExampleVulnerable.sol:28-33` |
| **Status** | Open |

### Description

`withdraw()` function makes an external call to `msg.sender` **before** updating the state variable `balances[msg.sender]`. This allows a malicious contract to re-enter `withdraw()` before the balance is decremented.

### Proof of Concept

```solidity
// Attacker contract
contract Attacker {
    ExampleVulnerable public vuln;
    
    constructor(address _vuln) {
        vuln = ExampleVulnerable(_vuln);
    }
    
    function attack() external payable {
        vuln.deposit{value: 1 ether}();
        vuln.withdraw(1 ether);
    }
    
    // This is called by ExampleVulnerable.withdraw() before state is updated
    receive() external payable {
        if (address(vuln).balance >= 1 ether) {
            vuln.withdraw(1 ether); // Re-enter! Balance not yet decremented
        }
    }
}
```

### Impact

Attacker can drain the entire contract balance.

### Recommendation

Use Checks-Effects-Interactions (CEI) pattern:

```solidity
function withdraw(uint256 amount) external {
    require(balances[msg.sender] >= amount, "Insufficient balance");
    
    // EFFECTS: Update state BEFORE external call
    balances[msg.sender] -= amount;
    
    // INTERACTIONS: External call last
    (bool success,) = msg.sender.call{value: amount}("");
    require(success, "Transfer failed");
}
```

Or use OpenZeppelin's `ReentrancyGuard`:

```solidity
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract ExampleVulnerable is ReentrancyGuard {
    function withdraw(uint256 amount) external nonReentrant {
        // ...
    }
}
```

---

## Finding 2: HIGH — Missing Access Control on `authorize()`

| Field | Value |
|-------|-------|
| **Severity** | 🟠 HIGH |
| **Title** | Anyone Can Authorize Addresses |
| **Location** | `ExampleVulnerable.sol:43-45` |
| **Status** | Open |

### Description

`authorize()` function has no access control — any address can call it to grant authorization to any other address. This function should be restricted to the contract owner or admin.

### Impact

Any user can authorize any address, completely bypassing the authorization system.

### Recommendation

Add access control modifier:

```solidity
function authorize(address user) external onlyOwner {
    isAuthorized[user] = true;
}
```

---

## Finding 3: MEDIUM — Front-Running Vulnerability

| Field | Value |
|-------|-------|
| **Severity** | 🟡 MEDIUM |
| **Title** | Predictable Reward Calculation Enables Front-Running |
| **Location** | `ExampleVulnerable.sol:40-42` |
| **Status** | Open |

### Description

`calculateReward()` uses a simple and predictable formula (`balances[user] * 2`). An attacker can:
1. See a pending transaction that will increase a user's balance
2. Front-run it by depositing on behalf of that user
3. Collect the doubled reward

### Impact

Attacker can extract value by front-running legitimate deposits.

### Recommendation

- Use Chainlink VRF for random reward calculation
- Use commit-reveal scheme
- Add time-lock between deposit and reward calculation

---

## Finding 4: LOW — Timestamp Dependence

| Field | Value |
|-------|-------|
| **Severity** | 🔵 LOW |
| **Title** | Timestamp Can Be Manipulated by Miners |
| **Location** | `ExampleVulnerable.sol:48-50` |
| **Status** | Open |

### Description

`isDepositRecent()` relies on `block.timestamp`, which can be manipulated by miners within ~15 seconds. For critical time-based logic, this is unreliable.

### Impact

Minor: Miners can slightly manipulate the timestamp to make deposits appear more/less recent.

### Recommendation

Use `block.number` for more reliable timing (though still approximate), or use a longer time window to make the 15-second manipulation negligible.

---

## Finding 5: INFO — No Event Emission on `authorize()`

| Field | Value |
|-------|-------|
| **Severity** | ℹ️ INFO |
| **Title** | Missing Event Emission |
| **Location** | `ExampleVulnerable.sol:43-45` |
| **Status** | Open |

### Description

`authorize()` does not emit an event when authorization is granted. Events are important for off-chain monitoring and indexing.

### Recommendation

```solidity
event Authorized(address indexed user, bool status);

function authorize(address user) external {
    isAuthorized[user] = true;
    emit Authorized(user, true);
}
```

---

## Finding 6: INFO — Unchecked Return Value of `call()`

| Field | Value |
|-------|-------|
| **Severity** | ℹ️ INFO |
| **Title** | `receive()` Does Not Emit Event |
| **Location** | `ExampleVulnerable.sol:52-55` |
| **Status** | Open |

### Description

`receive()` function accepts ETH without emitting an event. Best practice is to emit events for all state changes.

### Recommendation

Emit `Deposited` event in `receive()` as well.
