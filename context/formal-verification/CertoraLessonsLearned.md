# Certora CVL Syntax Lessons Learned

This document captures key syntax issues and solutions encountered when working with Certora Verification Language (CVL) version 2.

## Critical Syntax Rules

### 1. Environment Parameters for ERC20 Functions
**Problem**: ERC20 functions like `balanceOf`, `allowance`, `totalSupply` require environment parameters.
```cvl
// ❌ WRONG
require inputToken.balanceOf(user) >= amount;

// ✅ CORRECT  
require inputToken.balanceOf(e, user) >= amount;
```

### 2. Type Safety with mathint
**Problem**: Arithmetic operations can overflow when using uint256.
```cvl
// ❌ WRONG - can overflow
uint256 shortfall = amount - received;

// ✅ CORRECT - use mathint for calculations
mathint shortfall = to_mathint(amount) - to_mathint(received);
```

### 3. Ghost Variable Type Consistency
**Problem**: Ghost variables used in arithmetic need mathint type.
```cvl
// ❌ WRONG
ghost uint256 totalDepositsGhost;
totalDepositsGhost = totalDepositsGhost - oldValue + newValue;

// ✅ CORRECT
ghost mathint totalDepositsGhost;
totalDepositsGhost = totalDepositsGhost - to_mathint(oldValue) + to_mathint(newValue);
```

### 4. Invariant Syntax
**Problem**: CVL 2 requires semicolons after invariants.
```cvl
// ❌ WRONG
invariant totalDepositsIntegrity()
    to_mathint(totalDeposits()) == totalDepositsGhost

// ✅ CORRECT
invariant totalDepositsIntegrity()
    to_mathint(totalDeposits()) == totalDepositsGhost;
```

### 5. lastReverted Usage
**Problem**: `lastReverted` can only be used after `@withrevert` calls.
```cvl
// ❌ WRONG
withdraw(e, amount, protectLoss, 0);
assert protectLoss => lastReverted;

// ✅ CORRECT
withdraw@withrevert(e, amount, protectLoss, 0);
assert protectLoss => lastReverted;
```

### 6. Method Declarations
**Problem**: Method declarations without `envfree`, `optional`, or summaries have no effect and generate warnings.
```cvl
// ❌ UNNECESSARY - generates warning
function deposit(uint256) external;

// ✅ CORRECT - only declare if envfree or summarized
function canWithdraw() external returns (bool) envfree;
```

### 7. Using Statements
**Problem**: CVL 2 requires semicolons after using statements.
```cvl
// ❌ WRONG
using Vault as vault

// ✅ CORRECT
using Vault as vault;
```

### 8. DISPATCHER Syntax
**Problem**: Cannot use DISPATCHER with concrete contract receivers.
```cvl
// ❌ WRONG
function MockERC20.balanceOf(address) external => DISPATCHER(true);

// ✅ CORRECT - use wildcard receiver
function _.balanceOf(address) external => DISPATCHER(true);
```

## Environment Parameter Best Practices

1. **Always pass environment to ERC20 functions**: `balanceOf(e, address)`, `allowance(e, from, to)`, `totalSupply(e)`
2. **Use mathint for arithmetic**: Prevents overflow issues in formal verification
3. **Convert types explicitly**: Use `to_mathint()` when mixing uint256 and mathint
4. **Structure conditionals carefully**: Use `@withrevert` before checking `lastReverted`

## Common Patterns

### Safe Balance Checking
```cvl
require inputToken.balanceOf(e, user) >= amount;
require inputToken.allowance(e, user, currentContract) >= amount;
```

### Safe Arithmetic
```cvl
mathint difference = to_mathint(total) - to_mathint(used);
assert difference >= 0;
```

### Revert Testing
```cvl
functionCall@withrevert(e, params);
assert expectedRevert => lastReverted;
assert !expectedRevert => !lastReverted;
```

## Setup Requirements

1. **Solidity Version**: Must match contract requirements (0.8.20 for this project)
2. **Python Environment**: Use virtual environment for Certora CLI
3. **Contract References**: Include all required contracts and mocks in certoraRun command
4. **Package Mappings**: Ensure all imports are properly mapped with --packages flags