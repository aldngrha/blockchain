# Ethernaut Level 1-6 Write-up

Smart Contract Security CTF — Review & Analysis

---

## Level 1: Fallback

### Vulnerability
`receive()` function checks `msg.value < contributions[msg.sender]`. If attacker contributes first, then sends a smaller amount directly → becomes owner.

### Exploit
```
1. contribute{0.001 ETH} → contribution = 0.001 ETH
2. send{0.0001 ETH} → receive() → msg.value(0.0001) < contribution(0.001) → owner = attacker!
3. withdraw() → drain all ETH
```

### Fix
- Don't use `receive()` for authentication
- Use explicit modifier for ownership checks

---

## Level 2: Fallout

### Vulnerability
Constructor is misspelled as `Fal1out()` (number 1 instead of letter l) → becomes public function anyone can call.

### Exploit
```
1. Call Fal1out{0.001 ETH}
2. owner = attacker
```

### Fix
- Always use `constructor()` keyword (can't be misspelled)
- Use `constructor() {}` with proper syntax

---

## Level 3: CoinFlip

### Vulnerability
Randomness uses `block.timestamp` → predictable. Everyone can calculate the same "random" number.

### Exploit
```
1. Calculate: blockValue = keccak256(block.number - 1, lastHash)
2. coinFlip = blockValue / FACTOR
3. If coinFlip == 1 → bet "true"
4. Repeat 10x → guaranteed wins
```

### Fix
- Never use `block.timestamp` for randomness
- Use Chainlink VRF (Verifiable Random Function)
- Or use commit-reveal scheme

---

## Level 4: Telephone

### Vulnerability
Uses `tx.origin != msg.sender` for auth. Attacker can deploy contract → call function → tx.origin (attacker) != msg.sender (contract) → passes check.

### Exploit
```
1. Deploy TelephoneAttacker(target)
2. Call attack(attacker)
3. Inside: target.changeOwner(attacker)
4. tx.origin (attacker EOA) != msg.sender (attacker contract) → owner = attacker
```

### Fix
- Never use `tx.origin` for authentication
- Always use `msg.sender`

---

## Level 5: Token

### Vulnerability
`transfer()` doesn't check if sender has enough balance. Underflow possible when transferring more than owned → balance becomes MAX_UINT256.

### Exploit
```
1. Have 20 tokens
2. Transfer 21 tokens to anyone
3. unchecked { balances[msg.sender] -= _value }
4. 20 - 21 = MAX_UINT256 (underflow)
5. Attacker has 115792089... tokens
```

### Fix
- Use Solidity 0.8+ (built-in overflow check)
- Add explicit: `require(balances[msg.sender] >= _value)`
- Or use OpenZeppelin SafeMath

---

## Level 6: Delegation

### Vulnerability
Delegator uses `delegatecall` to Delegation contract. `pwn()` sets `owner = msg.sender`. In delegatecall context, storage writes go to Delegator's storage.

### Exploit
```
1. Call Delegation.pwn() directly
2. msg.sender = attacker EOA
3. Delegation's storage: owner = attacker
4. But in Delegator context: Delegator.owner = attacker
```

### Fix
- Be extremely careful with `delegatecall`
- Audit which functions can be delegatecalled
- Restrict who can call sensitive functions

---

## Summary: Vulnerability Patterns

| Level | Vulnerability | Pattern | Real-World Impact |
|-------|---------------|---------|-------------------|
| 1 (Fallback) | receive() auth | Auth via receive | Phishing |
| 2 (Fallout) | Misspelled constructor | Human error | Unauthorized access |
| 3 (CoinFlip) | Predictable randomness | block.timestamp | Manipulation |
| 4 (Telephone) | tx.origin phishing | tx.origin != msg.sender | Ownership hijack |
| 5 (Token) | Integer underflow | Unchecked arithmetic | Infinite tokens |
| 6 (Delegation) | delegatecall storage | Storage collision | Ownership hijack |

---

## Key Takeaways

1. **Authentication**: Always use `msg.sender`, never `tx.origin`
2. **State Changes**: Apply checks-effects-interactions pattern
3. **Randomness**: Use oracles (Chainlink VRF), never block variables
4. **Arithmetic**: Use Solidity 0.8+ or SafeMath
5. **Delegatecall**: Audit thoroughly, restrict access
6. **Constructors**: Use proper syntax, test deployment

---

## Next Levels (7-13)

Coming up in next sessions:
- Level 7 (Force): Force-send ETH via selfdestruct
- Level 8 (Vault): Read private variables from storage
- Level 9 (King): Prevent receive() DoS
- Level 10 (Re-entrancy): Classic reentrancy exploit
- Level 11 (Elevator): Function state manipulation
- Level 12 (Privacy): All storage is public
- Level 13 (Gatekeeper One): Type casting tricks
