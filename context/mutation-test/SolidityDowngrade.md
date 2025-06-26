# Solidity Version Downgrade Guide: 0.8.20 → 0.8.13

## Overview
This guide documents the process of downgrading ReFlax from Solidity 0.8.20 to 0.8.13 for Gambit compatibility.

## Pre-Downgrade Checklist

### 1. Create Baseline
- [ ] Run full test suite and save results
- [ ] Run Certora formal verification and save results
- [ ] Generate gas report for comparison
- [ ] Create git branch for downgrade: `git checkout -b solidity-0.8.13-downgrade`
- [ ] Document current compiler settings from foundry.toml

### 2. Feature Compatibility Check

| Feature | 0.8.20 | 0.8.13 | Action Required |
|---------|---------|---------|-----------------|
| Custom Errors | ✅ | ✅ | None |
| User-defined Value Types | ✅ | ✅ | None |
| Block.prevrandao | ✅ | ❌ | Check if used |
| PUSH0 opcode | ✅ | ❌ | Disable in optimizer |
| Optimizer improvements | Enhanced | Standard | May affect gas |
| String.concat() | ✅ | ✅ | None |
| abi.encodeCall | ✅ | ✅ | None |

### 3. Code Analysis
Run these commands to check for version-specific features:
```bash
# Check for block.prevrandao usage
grep -r "prevrandao" src/

# Check for specific 0.8.14+ features
grep -r "push0" src/
```

## Downgrade Steps

### Step 1: Update Pragma Statements
```bash
# Update all Solidity files
find src test -name "*.sol" -exec sed -i 's/pragma solidity ^0.8.20;/pragma solidity ^0.8.13;/g' {} +

# Verify changes
grep -r "pragma solidity" src/ test/
```

### Step 2: Update Foundry Configuration
Edit `foundry.toml`:
```toml
[profile.default]
solc_version = "0.8.13"
# Remove or comment out any 0.8.14+ specific optimizer settings
# optimizer_details = { yul = true, yulDetails = { stackAllocation = true } }
```

### Step 3: Update Library Dependencies
Check if any dependencies require specific versions:
```bash
# Check OpenZeppelin version compatibility
grep -r "pragma solidity" lib/oz_reflax/

# Check Uniswap libraries
grep -r "pragma solidity" lib/UniswapReFlax/
```

### Step 4: Compiler-Specific Adjustments

#### Remove PUSH0 Opcode Usage
In `foundry.toml`, ensure:
```toml
[profile.default]
# Disable PUSH0 for 0.8.13 compatibility
# This is automatic in 0.8.13, but good to document
optimizer = true
optimizer_runs = 200
```

#### Check Assembly Blocks
If using inline assembly:
```solidity
// May need adjustment if using 0.8.20-specific assembly features
assembly {
    // Check for any prevrandao or push0 usage
}
```

### Step 5: Test and Verify

#### Run Tests
```bash
# Clean build
forge clean

# Rebuild with new compiler
forge build

# Run all tests
forge test

# Run with verbose output if issues
forge test -vvv
```

#### Run Gas Comparison
```bash
# Generate new gas report
forge test --gas-report > gas-report-0.8.13.txt

# Compare with baseline
diff gas-report-0.8.20.txt gas-report-0.8.13.txt
```

#### Run Formal Verification
```bash
cd certora
./preFlight.sh
./run_local_verification.sh
```

## Common Issues and Solutions

### Issue: Stack Too Deep
**Solution**: Refactor functions to use fewer local variables or introduce internal functions

### Issue: Optimizer Differences
**Solution**: Adjust optimizer_runs if significant gas differences:
```toml
optimizer_runs = 200  # Try 1000 or 10000 for different trade-offs
```

### Issue: Library Incompatibility
**Solution**: May need to use older versions of libraries or create compatibility wrappers

## Rollback Plan

If issues are insurmountable:
```bash
# Revert all changes
git checkout main

# Or keep changes in branch for reference
git checkout -b attempted-downgrade-backup
git checkout main
```

## Post-Downgrade Verification

### 1. Functional Tests
- [ ] All unit tests pass
- [ ] All integration tests pass
- [ ] Manual testing of critical paths

### 2. Security Verification
- [ ] Formal verification passes
- [ ] No new compiler warnings
- [ ] Slither/other tools show no new issues

### 3. Performance
- [ ] Gas usage within acceptable range (±5%)
- [ ] Deployment costs documented
- [ ] No significant optimization losses

### 4. Documentation Updates
- [ ] Update README with new compiler version
- [ ] Update CI/CD configurations
- [ ] Document any workarounds needed

## Version-Specific Code Patterns

### Pattern 1: Error Handling
Both versions support custom errors:
```solidity
// Works in both 0.8.13 and 0.8.20
error InsufficientBalance(uint256 requested, uint256 available);
```

### Pattern 2: Overflow Checks
Built-in overflow protection available in both:
```solidity
// Safe in both versions
uint256 result = a + b;  // Automatically checks for overflow
```

### Pattern 3: ABI Encoding
Both support abi.encodeCall:
```solidity
// Works in both versions
bytes memory data = abi.encodeCall(IERC20.transfer, (recipient, amount));
```

## Maintenance Notes

1. **Keep Downgrade Branch**: Maintain the 0.8.13 branch for mutation testing
2. **Dual Testing**: Consider running tests on both versions periodically
3. **Version Documentation**: Document which version is used for:
   - Production deployment
   - Development
   - Mutation testing
   - Formal verification

## Automation Script

Create `scripts/downgrade-solidity.sh`:
```bash
#!/bin/bash
set -e

echo "Downgrading Solidity from 0.8.20 to 0.8.13..."

# Update pragma statements
find src test -name "*.sol" -exec sed -i 's/pragma solidity ^0.8.20;/pragma solidity ^0.8.13;/g' {} +

# Update foundry.toml
sed -i 's/solc_version = "0.8.20"/solc_version = "0.8.13"/g' foundry.toml

# Clean and rebuild
forge clean
forge build

echo "Downgrade complete. Run 'forge test' to verify."
```