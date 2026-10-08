// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title IntegerOverflowDemo
 * @dev Demonstrates integer overflow/underflow vulnerabilities
 * 
 * PROBLEM:
 * Before Solidity 0.8, arithmetic operations didn't check for overflow/underflow
 * This led to critical vulnerabilities:
 * - Underflow: 0 - 1 = MAX_UINT256 (not 0 or revert)
 * - Overflow: MAX_UINT256 + 1 = 0 (not revert)
 * 
 * EXAMPLES:
 * - BeautyChain (BEC) 2018: overflow → infinite tokens minted
 * - SMT Token 2018: overflow → balance manipulation
 * 
 * SOLUTION:
 * - Use Solidity 0.8+ (built-in checks)
 * - Or use OpenZeppelin SafeMath (for older versions)
 */
contract IntegerOverflowDemo {
    mapping(address => uint256) public balances;
    
    // Vulnerable function (pre-0.8 style logic)
    // This would be vulnerable in Solidity <0.8
    function vulnerableTransfer(address to, uint256 amount) external {
        // No overflow check in older versions
        // balances[msg.sender] -= amount; // Underflow if amount > balance
        balances[to] += amount; // Overflow if too large
    }
    
    // Safe function (0.8+ style)
    function safeTransfer(address to, uint256 amount) external {
        require(balances[msg.sender] >= amount, "Insufficient balance");
        balances[msg.sender] -= amount;
        balances[to] += amount;
    }
    
    // Deposit ETH
    function deposit() external payable {
        balances[msg.sender] += msg.value;
    }
}

/**
 * @title FlashLoanAttackDemo
 * @dev Demonstrates flash loan attack concept
 * 
 * PROBLEM:
 * Flash loans allow borrowing millions with no collateral in one transaction
 * Attacker can:
 * 1. Borrow huge amount
 * 2. Manipulate price oracle
 * 3. Profit from manipulation
 * 4. Repay loan
 * All in ONE transaction
 * 
 * REAL EXAMPLES:
 * - bZx 2020: $8M stolen via flash loan + oracle manipulation
 * - Pancake Bunny 2021: $45M stolen
 * - Cream Finance 2021: $130M stolen
 */
contract FlashLoanAttackDemo {
    uint256 public totalDeposits;
    mapping(address => uint256) public deposits;
    
    // Simulated price oracle (VULNERABLE - single source)
    uint256 public price;
    
    function setPrice(uint256 _price) external {
        price = _price;
    }
    
    function deposit() external payable {
        deposits[msg.sender] += msg.value;
        totalDeposits += msg.value;
    }
    
    // Vulnerable: calculates value based on manipulatable price
    function getValue(address user) public view returns (uint256) {
        // price is in 1e18 format (1e18 = 1.0)
        return (deposits[user] * price) / 1e18;
    }
    
    // Flash loan callback (simplified)
    function flashLoanCallback(uint256 amount) external {
        // In real flash loan:
        // 1. Aave/dYdX sends tokens
        // 2. Callback executes logic
        // 3. Must repay principal + fee
        
        // VULNERABLE: Attacker can manipulate price here
        // Then call getValue() to get inflated value
        // Then withdraw
    }
}

/**
 * @title PriceOracleManipulationDemo
 * @dev Demonstrates price oracle manipulation attacks
 * 
 * PROBLEM:
 * If protocol uses single DEX price as oracle:
 * 1. Attacker borrows flash loan
2. Swaps large amount on DEX → price changes
 * 3. Calls protocol functions at manipulated price
 * 4. Profits from price difference
 * 5. Repays flash loan
 * 
 * SOLUTIONS:
 * - Use TWAP (Time-Weighted Average Price)
 * - Use multiple oracles (Chainlink)
 * - Use Uniswap V3 oracle (cumulative prices)
 * - Add price checks with slippage protection
 */
contract PriceOracleManipulationDemo {
    // Simulated DEX pool
    uint256 public reserveA;
    uint256 public reserveB;
    
    // Protocol using DEX price as oracle (VULNERABLE)
    uint256 public totalDeposits;
    mapping(address => uint256) public deposits;
    
    // Get price from pool (MANIPULABLE!)
    function getPrice() public view returns (uint256) {
        if (reserveA == 0) return 0;
        return (reserveB * 1e18) / reserveA;
    }
    
    // Deposit with price check (VULNERABLE)
    function deposit() external payable {
        uint256 price = getPrice();
        uint256 value = msg.value * price / 1e18;
        deposits[msg.sender] += value;
        totalDeposits += value;
    }
    
    // Swap function (can be exploited)
    function swap(uint256 amountA) external {
        require(amountA > 0, "Invalid amount");
        
        uint256 amountB = (amountA * reserveB) / reserveA;
        
        reserveA += amountA;
        reserveB -= amountB;
        
        // Transfer tokens...
    }
}
