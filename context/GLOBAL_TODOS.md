# ReFlax Protocol - Global TODO List

**Generated**: June 24, 2025

This document provides a comprehensive list of tasks needed to complete the ReFlax protocol validation and testing. Each TODO includes sufficient context for a fresh agent to pick up and execute.

---

## 🧪 Phase 1: Fix All Tests (PRIORITY 1)

### TODO 1.1: Fix Unit Test Failures
**Status**: PENDING  
**Priority**: CRITICAL  
**Estimated Time**: 2-4 hours

**Context**: Several unit tests are currently failing, preventing reliable mutation testing.

**Failing Tests Identified**:
```bash
# ConvexCRV_ys.t.sol failures:
[FAIL: MockUniswapV3Router: Output less than amountOutMinimum] testCompleteDepositFlow()
[FAIL: MockUniswapV3Router: Output less than amountOutMinimum] testDepositGasUsage()
[FAIL: MockUniswapV3Router: Output less than amountOutMinimum] testDepositWithMaxSlippage()
[FAIL: MockUniswapV3Router: Output less than amountOutMinimum] testMinimumDeposit()
[FAIL: MockUniswapV3Router: Output less than amountOutMinimum] testMultipleUserDeposits()

# integration/EmergencyRebaseIntegration.t.sol failures:
[FAIL: TWAPOracle: ZERO_OUTPUT_AMOUNT] testEmergencyAfterPartialWithdrawals()
[FAIL: TWAPOracle: ZERO_OUTPUT_AMOUNT] testEmergencyScenarioWithMultipleUsers()
[FAIL: TWAPOracle: ZERO_OUTPUT_AMOUNT] testEmergencyStateWithoutInputTokenWithdrawal()
```

**Root Causes**:
1. **Uniswap V3 Mock Issues**: Mock router returning insufficient output amounts
2. **TWAPOracle Issues**: Zero output amounts in oracle calculations

**Action Steps**:
```bash
# 1. Diagnose mock issues
forge test --match-contract ConvexCRVTest -vvv

# 2. Check mock configurations in test/mocks/Mocks.sol
# 3. Adjust slippage parameters or mock return values
# 4. Fix oracle initialization issues in TWAPOracle tests

# 5. Verify fixes
forge test --no-match-test "integration"
```

**Files to Check**:
- `test/ConvexCRV_ys.t.sol` - Main failing test file
- `test/mocks/Mocks.sol` - Mock contract configurations
- `test/integration/EmergencyRebaseIntegration.t.sol` - TWAPOracle issues
- `src/priceTilting/TWAPOracle.sol` - Oracle implementation

**Success Criteria**: All unit tests pass with `forge test --no-match-test "integration"`

---

### TODO 1.2: Fix Integration Test Compiler Version Mismatch
**Status**: PENDING  
**Priority**: HIGH  
**Estimated Time**: 1-2 hours

**Context**: Integration tests are using Solidity ^0.8.20 but project is configured for 0.8.13, causing compilation failures.

**Error Pattern**:
```
Encountered invalid solc version in test-integration/base/ArbitrumConstants.sol: 
No solc version exists that matches the version requirement: ^0.8.20
```

**Root Cause**: 
- Main contracts use Solidity 0.8.13 (for mutation testing compatibility)  
- Integration tests use ^0.8.20 (newer version requirements)

**Action Steps**:
```bash
# 1. Find all files with version mismatches
grep -r "pragma solidity" test-integration/

# 2. Update all integration test files to use 0.8.13
# Change: pragma solidity ^0.8.20;
# To:     pragma solidity ^0.8.13;

# 3. Test compilation
FOUNDRY_PROFILE=integration forge build

# 4. Run integration tests
./scripts/test-integration.sh
```

**Files to Update**:
- `test-integration/base/ArbitrumConstants.sol`
- `test-integration/base/IntegrationTest.sol`  
- All files in `test-integration/priceTilting/`
- All files in `test-integration/vault/`
- All files in `test-integration/yieldSource/`
- All files in `test-integration/gas/`

**Success Criteria**: Integration tests compile and run successfully with `./scripts/test-integration.sh`

---

## 🧬 Phase 2: Complete Mutation Testing (PRIORITY 2)

### TODO 2.1: Complete Baseline Mutation Testing
**Status**: PARTIALLY COMPLETE (20/875 mutations tested)  
**Priority**: HIGH  
**Estimated Time**: 4-6 hours

**Context**: Initial mutation testing shows 60% mutation score on sample. Need to test all contracts once unit tests are fixed.

**Current Status**:
- ✅ **PriceTilterTWAP**: 50% score (5/10 killed)
- ✅ **AYieldSource**: 70% score (7/10 killed)  
- ❌ **CVX_CRV_YieldSource**: Blocked by failing baseline tests
- ❌ **TWAPOracle**: Blocked by failing baseline tests
- ❌ **Vault**: Needs flattened file handling

**Prerequisites**: Complete TODO 1.1 (fix unit tests)

**Action Steps**:
```bash
# 1. Ensure baseline tests pass (from TODO 1.1)
forge test --no-match-test "integration"

# 2. Run complete mutation testing
./run_working_mutation_tests.sh

# 3. Test remaining contracts after fixes
# Update script to include CVX_CRV_YieldSource and TWAPOracle

# 4. Handle Vault mutations (flattened files)
# Create specialized script for vault_mutations/ directory
```

**Files/Directories**:
- `mutation-reports/CVX_CRV_YieldSource/` - 303 mutations ready
- `mutation-reports/TWAPOracle/` - 116 mutations ready  
- `mutation-reports/PriceTilterTWAP/` - 121 mutations (sample tested)
- `mutation-reports/AYieldSource/` - 72 mutations (sample tested)
- `vault_mutations/` - 263 mutations (flattened format)

**Scripts Available**:
- `run_working_mutation_tests.sh` - Current working script
- `run_actual_mutation_tests.sh` - Full testing script (needs baseline fixes)

**Success Criteria**: 
- All 875 mutations tested
- Mutation scores calculated for each contract
- Results documented in `context/mutation-test/results/execution/`

---

### TODO 2.2: Improve Test Suite Based on Mutation Results
**Status**: PENDING  
**Priority**: MEDIUM  
**Estimated Time**: 3-5 hours

**Context**: Current mutation testing reveals test gaps. Need to add tests to kill survived mutations.

**Known Issues from Sample Testing**:
- **DeleteExpressionMutation** frequently survives (validation removal not caught)
- **RequireMutation** frequently survives (missing negative test cases)
- Need boundary condition testing

**Survived Mutations to Analyze**:
- PriceTilterTWAP: mutants 1, 5, 7, 10, 20
- AYieldSource: mutants 1, 5, 7

**Action Steps**:
```bash
# 1. Analyze specific survived mutations
jq '.[0]' mutation-reports/PriceTilterTWAP/gambit_results.json
# Check diff to understand what was mutated

# 2. For each survived mutation, add test case that would kill it
# Example: If require statement removal survived, add negative test

# 3. Re-run mutation testing to verify improvements
./run_working_mutation_tests.sh

# 4. Target >90% mutation score for critical contracts
```

**Target Scores**:
- Critical contracts (Vault, CVX_CRV_YieldSource): >90%
- High priority (PriceTilter, TWAPOracle): >85%  
- Medium priority (AYieldSource): >80%

**Success Criteria**: Achieve target mutation scores through improved test coverage

---

## 🔬 Phase 3: Mutation Testing vs Formal Verification (PRIORITY 3)

### TODO 3.1: Create Mutation-Resistant Formal Verification Specs
**Status**: PENDING  
**Priority**: MEDIUM  
**Estimated Time**: 4-6 hours

**Context**: Use mutation testing results to strengthen formal verification specifications.

**Rationale**: 
Mutations that survive testing but should be caught by formal verification indicate specification gaps. This creates a feedback loop:
- **Mutation Testing**: Finds test gaps
- **Formal Verification**: Should catch logical/mathematical errors
- **Cross-Validation**: Mutations surviving both indicate serious specification issues

**Current Formal Verification Status**:
- ✅ **Vault**: 81% success rate (17/21 rules)
- ✅ **YieldSource**: 87% success rate  
- ✅ **PriceTilter**: 100% success rate
- ⚠️ **TWAPOracle**: Needs specification fixes

**Action Steps**:
```bash
# 1. Identify mutations that survive testing
grep "SURVIVED" context/mutation-test/results/execution/working_results.csv

# 2. For each survived mutation, check if formal verification would catch it
# Example: If DeleteExpression removes require(), does formal spec catch this?

# 3. Add formal verification rules for gaps identified
cd certora && ./preFlight.sh
# Edit specs to add missing invariants

# 4. Run verification on mutations
# Replace original contract with mutant, run Certora
python $CERTORA/certoraRun.py ... --verify Vault:certora/specs/Vault.spec

# 5. Document results: which mutations formal verification catches vs misses
```

**Process Example**:
```bash
# For PriceTilterTWAP mutant 1 (DeleteExpressionMutation):
# 1. Copy mutant to replace original
cp mutation-reports/PriceTilterTWAP/mutants/1/src/priceTilting/PriceTilterTWAP.sol src/priceTilting/PriceTilterTWAP.sol

# 2. Run formal verification
cd certora && ./run_local_verification.sh

# 3. Check if verification fails (mutation caught) or passes (gap in specs)
# 4. Restore original and document result
git checkout -- src/priceTilting/PriceTilterTWAP.sol
```

**Success Criteria**: 
- Document which mutations formal verification catches vs misses
- Identify specification gaps
- Strengthen specs to catch mutation-revealed issues

---

### TODO 3.2: Cross-Validate Critical Survived Mutations with Formal Verification
**Status**: PENDING  
**Priority**: MEDIUM  
**Estimated Time**: 3-4 hours

**Context**: Test ONLY the mutations that survived testing against formal verification to identify specification gaps.

**Scope**: Focus on the 8 mutations that survived sample testing rather than all 875.

**High-Priority Mutations to Test**:
- **PriceTilterTWAP mutants**: 1, 5, 7, 10, 20 (DeleteExpression and RequireMutation types)
- **AYieldSource mutants**: 1, 5, 7 (various mutation types)

**Methodology**:
```bash
# Test each survived mutation against formal verification:
survived_mutations=(
  "PriceTilterTWAP:1" "PriceTilterTWAP:5" "PriceTilterTWAP:7" "PriceTilterTWAP:10" "PriceTilterTWAP:20"
  "AYieldSource:1" "AYieldSource:5" "AYieldSource:7"
)

for mutation in "${survived_mutations[@]}"; do
  contract=$(echo $mutation | cut -d':' -f1)
  mutant=$(echo $mutation | cut -d':' -f2)
  
  # 1. Copy mutant to replace original
  # 2. Run formal verification: cd certora && ./run_local_verification.sh
  # 3. Record: CAUGHT (verification fails) or MISSED (verification passes)
  # 4. Restore original contract
done
```

**Expected Outcomes**:
- **Ideal**: Formal verification catches mutations that testing missed
- **Gaps Found**: Some mutations survive both (critical specification issues)
- **Enhanced Specs**: Add rules to catch mutation-revealed gaps

**Success Criteria**: 
- Document cross-validation results for all 8 survived mutations
- Strengthen formal specs for any mutations that survive both approaches
- No critical financial/security mutations survive both testing and formal verification

---

## 📊 Phase 4: Documentation and Reporting (PRIORITY 4)

### TODO 4.1: Create Comprehensive Testing Report
**Status**: PENDING  
**Priority**: LOW  
**Estimated Time**: 2-3 hours

**Context**: Document complete testing results for stakeholders and future development.

**Report Structure**:
1. **Executive Summary**: Overall testing approach and results
2. **Unit Testing**: Coverage and results  
3. **Integration Testing**: Real-world scenario validation
4. **Mutation Testing**: Test suite robustness validation
5. **Formal Verification**: Mathematical correctness proofs
6. **Cross-Validation**: How different approaches complement each other
7. **Recommendations**: Next steps for production readiness

**Success Criteria**: Comprehensive report suitable for external review

---

### TODO 4.2: Update CLAUDE.md with Complete Workflows
**Status**: PENDING  
**Priority**: LOW  
**Estimated Time**: 1 hour

**Context**: Document complete testing workflows for future development.

**Areas to Update**:
- Complete mutation testing commands
- Cross-validation procedures  
- Troubleshooting guides
- Performance optimization tips

**Success Criteria**: CLAUDE.md provides complete guidance for all testing approaches

---

## 🔧 Supporting Infrastructure

### Available Scripts and Tools
- `run_working_mutation_tests.sh` - Sample mutation testing (working)
- `run_actual_mutation_tests.sh` - Full mutation testing (needs baseline fixes)
- `./scripts/test-integration.sh` - Integration test runner
- `./certora/preFlight.sh` - Formal verification syntax checker
- `./certora/run_local_verification.sh` - Local formal verification

### Key Directories
- `context/mutation-test/results/execution/` - Mutation testing results
- `certora/reports/` - Formal verification reports  
- `mutation-reports/` - Generated mutations for each contract
- `test-integration/` - Integration test suites

### Documentation Context
- `context/unit-test/` - Unit testing guidelines
- `context/integration-test/` - Integration testing setup
- `context/mutation-test/` - Mutation testing documentation
- `context/formal-verification/` - Formal verification approach

---

## 📈 Success Metrics

### Phase 1 Success:
- [ ] All unit tests pass
- [ ] All integration tests pass  
- [ ] Clean baseline for mutation testing

### Phase 2 Success:
- [ ] All 875 mutations tested
- [ ] >90% mutation score for critical contracts
- [ ] Test suite improvements implemented

### Phase 3 Success:
- [ ] Formal verification coverage documented
- [ ] Cross-validation matrix complete
- [ ] No critical gaps between approaches

### Overall Success:
- [ ] Industry-leading validation coverage
- [ ] Production-ready security confidence
- [ ] Comprehensive documentation for stakeholders

---

**Last Updated**: June 24, 2025  
**Status**: Ready for execution - start with Phase 1