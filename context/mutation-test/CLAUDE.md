# Mutation Testing Guidelines for ReFlax Protocol

This document provides guidance for mutation testing using Gambit in the ReFlax codebase.

## Phase 4 Active - Structured Completion

**Current Phase**: Phase 4 - Smart filtering and efficient execution
**Action Plan**: See `Phase4ActionPlan.md` for detailed execution steps
**Status**: Organizing mutation testing evolution with focus on signal over noise

### Quick Navigation for Fresh Agents
1. **Start Here**: Read `Phase4ActionPlan.md` for current strategy
2. **Understanding Progress**: Check `contracts/<Contract>/phase*/` directories
3. **Current Work**: Phase 4 focuses on excluding low-value mutations (OpenZeppelin, getters)
4. **Key Principle**: Test ReFlax-specific logic, not battle-tested library code

## Overview

Mutation testing helps verify the quality of our test suite by introducing small changes (mutations) to the source code and checking if tests can detect these changes. A good test suite should "kill" most mutations.

## Response Format
- When performing mutation testing tasks, begin responses with "**ReFlax Mutation:** "

## Key Concepts

### Mutation Score
- **Killed Mutations**: Tests failed when mutation was introduced (good)
- **Survived Mutations**: Tests passed despite mutation (indicates potential test gaps)
- **Equivalent Mutations**: Mutations that don't change behavior (can be ignored)
- **Target Score**: Aim for >80% mutation score for critical contracts

### Priority Contracts
1. **Critical** (>90% target):
   - Vault.sol
   - YieldSource contracts
   - PriceTilterTWAP.sol

2. **High** (>80% target):
   - TWAPOracle.sol
   - Emergency functions

3. **Medium** (>70% target):
   - Supporting contracts
   - Interfaces

## Workflow Rules

### 1. Pre-Mutation Checklist
- Ensure all tests pass on Solidity 0.8.13
- Run baseline test coverage report
- Document current test execution time
- Clean build artifacts

### 2. Running Mutation Tests
```bash
# Always run from project root
cd /home/justin/code/BehodlerReborn/Grok/reflax

# 1. Install Gambit (if not already installed)
pip install gambit-tools

# 2. Generate mutations for a specific contract
gambit mutate --contract src/vault/Vault.sol

# 3. Run mutation testing
gambit test --mutation-testing
```

### 3. Analyzing Results
- Check `gambit_results.json` for detailed results
- Focus on survived mutations in critical functions
- Prioritize mutations in:
  - Financial calculations
  - Access control checks
  - State transitions
  - Emergency functions

### 4. Improving Tests
When a mutation survives:
1. Understand what the mutation changed
2. Determine if it's an equivalent mutation
3. If not equivalent, write a test that would kill it
4. Re-run mutation testing to verify improvement

## Mutation Operators

### Arithmetic Mutations
- `+` → `-`, `*`, `/`
- `>` → `>=`, `<`, `<=`, `==`, `!=`
- Be careful with SafeMath - some mutations may be equivalent

### Boolean Mutations
- `true` → `false`
- `&&` → `||`
- `!` operator removal

### Statement Mutations
- `require` → `revert`
- Remove `require` statements
- Change return values

## Special Considerations for DeFi

### 1. Precision Mutations
- Pay special attention to decimal calculations
- Mutations in precision constants should be caught

### 2. Reentrancy Guards
- Mutations removing reentrancy protection must be killed
- Test order-dependent operations

### 3. Oracle Mutations
- TWAP window mutations
- Price calculation mutations
- Slippage protection mutations

## Performance Tips

### 1. Selective Mutation
```bash
# Mutate only specific functions
gambit mutate --contract src/vault/Vault.sol --function deposit

# Skip view functions
gambit mutate --skip-view-functions
```

### 2. Parallel Execution
```bash
# Run with multiple threads
gambit test --threads 4
```

### 3. Timeout Management
```bash
# Set appropriate timeout for complex tests
gambit test --timeout 300
```

## Integration with Existing Tests

### Unit Tests
- Run mutation testing on unit tests first (faster)
- Use `forge test --match-contract <Contract>` for targeted testing

### Integration Tests
- Run on critical paths only due to performance
- Consider mocking external calls for faster execution

### Formal Verification
- Mutations that survive both tests AND formal verification indicate specification gaps
- Use mutation results to improve Certora specs

## Common Patterns and Solutions

### Pattern 1: Uncaught Boundary Mutations
**Mutation**: `>` becomes `>=`
**Solution**: Add explicit boundary test cases

### Pattern 2: Missing Revert Tests
**Mutation**: Removed `require` statement
**Solution**: Test both success and failure paths

### Pattern 3: Arithmetic Precision
**Mutation**: Changed decimal places
**Solution**: Test with precise expected values

## Debugging Failed Mutation Tests

1. Check mutation log: `cat .gambit/mutations.log`
2. Isolate the mutated contract: `cp .gambit/mutants/1/Contract.sol test/`
3. Run specific test: `forge test --match-test testName -vvv`
4. Compare with original to understand the change

## Best Practices

1. **Start Small**: Begin with one contract at a time
2. **Document Decisions**: Keep track of equivalent mutations
3. **Regular Runs**: Include in PR checks for critical contracts
4. **Balance Coverage**: Don't aim for 100% - focus on critical paths
5. **Learn from Survivors**: Each survived mutation teaches about test gaps

## Maintenance

- Update Gambit version quarterly
- Review mutation configurations when adding new contracts
- Archive old mutation reports for trend analysis
- Update this guide based on team learnings

## Mutation Testing Evolution Navigation

### Directory Structure
```
contracts/
├── Vault/
│   ├── phase1-baseline/      # Initial mutation testing results
│   ├── phase2-improvements/  # First round of test improvements
│   ├── phase3-targeted/      # Targeted killer tests for survivors
│   └── summary.md           # Evolution narrative for this contract
├── YieldSource/
├── PriceTilter/
└── TWAPOracle/
```

### Understanding the Evolution
1. Each contract has its own evolution tracked in phases
2. Phase directories contain results, analysis, and improvements
3. Summary files provide narrative continuity
4. Final results will update ComprehensiveFormalVerificationReport.md

### Smart Filtering Philosophy (Phase 4)
- **Exclude**: OpenZeppelin code, view functions, simple getters
- **Include**: ReFlax-specific business logic, DeFi integrations, financial calculations
- **Goal**: ~500 meaningful mutations tested (vs 875 generated)
- **Principle**: Signal over noise - test what matters

### For Fresh Agents
If picking up mutation testing work:
1. Read `Phase4ActionPlan.md` first
2. Check the latest phase directory for each contract
3. Continue from where previous work stopped
4. Follow the smart filtering criteria
5. Document all decisions in appropriate phase directories