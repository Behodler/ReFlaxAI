# YieldSource Test Improvements - Targeting 45% → 75% Mutation Score

## Executive Summary
**Current Issue**: 45% mutation score reveals major test coverage gaps
**Target**: Achieve 75%+ mutation score through focused test improvements
**Strategy**: Add DeFi-aware tests respecting protocol fee friction

## Critical Test Gaps Identified

### 1. Weight Distribution Logic (High Priority)
**Surviving Mutations**: 58-66 (Weight calculation arithmetic)
**Current Coverage**: Basic weight validation only
**Gap**: Edge cases and arithmetic boundary conditions

#### Missing Tests:
```solidity
function testWeightDistributionArithmeticEdgeCases() public {
    // Test division precision in weight calculations
    // Mutation: 10000 / poolTokens.length with different operators
    
    // Test with pool sizes that don't divide evenly into 10000
    uint256[] memory amounts = new uint256[](3); // 10000/3 = 3333.33...
    // Verify behavior with remainder handling
}

function testWeightDistributionZeroPool() public {
    // Test weight distribution when poolTokens array is manipulated
    // Targets IfStatementMutation on weights.length == 0
}

function testWeightCalculationOverflow() public {
    // Test large amounts that could cause overflow in (amount * weights[i]) / 10000
    // But use reasonable bounds to avoid unrealistic scenarios
}
```

### 2. DeFi Integration Failure Scenarios (Critical)
**Surviving Mutations**: 116, 139 (Convex deposit/withdraw deletions)
**Current Coverage**: Only happy path testing
**Gap**: Protocol failure and error recovery

#### Missing Tests:
```solidity
function testConvexDepositFailure() public {
    // Test behavior when IConvexBooster.deposit() fails
    // Mock the booster to revert and verify error handling
    // This targets DeleteExpressionMutation ID 116
}

function testConvexWithdrawFailure() public {
    // Test behavior when IConvexBooster.withdraw() fails  
    // Mock the booster to revert and verify error handling
    // This targets DeleteExpressionMutation ID 139
}

function testCurvePoolFailures() public {
    // Test behavior when Curve add_liquidity/remove_liquidity fails
    // Critical for DeFi integration robustness
}
```

### 3. Financial Arithmetic Boundaries (DeFi-Aware)
**Surviving Mutations**: 253-280 (Critical arithmetic operations)
**Current Coverage**: Basic amount validation
**Gap**: Boundary conditions respecting DeFi friction

#### DeFi-Aware Financial Testing:
```solidity
function testSlippageProtectionBounds() public {
    // Test slippage calculation: (minOut * (10000 - minSlippageBps)) / 10000
    // Use ranges instead of exact matches due to protocol fees
    // Verify slippage is within acceptable bounds, not exact amounts
}

function testAmountAllocationWithFees() public {
    // Test: (amount * weights[i]) / 10000
    // Account for the fact that DeFi protocols take fees
    // Use assertApproxEq with reasonable tolerance (e.g., 0.1%)
}

function testMinimumAmountThresholds() public {
    // Test behavior with very small amounts that might round to zero
    // Ensure system doesn't break with dust amounts
}
```

### 4. Conditional Logic Coverage (Medium Priority)
**Surviving Mutations**: 51, 52, 83-86 (If statement mutations)
**Current Coverage**: Happy path conditions only
**Gap**: Edge case condition testing

#### Missing Conditional Tests:
```solidity
function testRewardTokenFiltering() public {
    // Test: rewardTokens[i] != address(0) && rewardTokens[i] != address(flaxToken)
    // Cover cases where reward token is zero address or flax token
}

function testPoolTokenMatching() public {
    // Test: address(poolTokens[i]) == address(inputToken)
    // Cover both matching and non-matching scenarios
}

function testAllocatedAmountConditions() public {
    // Test: allocatedAmount > 0
    // Cover zero allocation scenarios
}
```

## Implementation Strategy

### Phase 1: High-Impact Quick Wins (Target: +15% score)
1. **DeFi Integration Failures**: Add Convex/Curve failure tests
2. **Weight Edge Cases**: Add arithmetic boundary tests
3. **Conditional Coverage**: Add missing if/else branch tests

### Phase 2: Financial Arithmetic (Target: +10% score)  
1. **Slippage Boundaries**: Test with DeFi-aware tolerance
2. **Amount Calculations**: Use bounds-based assertions
3. **Precision Handling**: Test division remainder scenarios

### Phase 3: Advanced Edge Cases (Target: +5% score)
1. **Assignment Mutations**: Test state variable edge cases
2. **Loop Boundary**: Test array manipulation edge cases
3. **Error Propagation**: Test error handling chains

## DeFi Friction Considerations

### Testing Philosophy
- **Use Bounds, Not Exact Matches**: `assertApproxEq` with 0.1-1% tolerance
- **Account for Protocol Fees**: Every swap/add/remove liquidity takes fees
- **Test MEV Protection**: Ensure slippage bounds prevent sandwich attacks
- **Realistic Scenarios**: Use amounts that reflect actual usage

### Example Pattern:
```solidity
// WRONG: Exact matching (will fail due to fees)
assertEq(outputAmount, expectedAmount);

// RIGHT: Bounds-based testing  
assertApproxEq(outputAmount, expectedAmount, 1e16); // 1% tolerance
assertTrue(outputAmount >= minAcceptable, "Below MEV protection");
assertTrue(outputAmount <= maxReasonable, "Suspiciously high");
```

## Expected Results
- **Target Mutation Score**: 75% (up from 45%)
- **Focus**: Kill 30+ additional mutations in critical areas
- **Priority Order**: DeFi integration > Financial calculations > Conditionals
- **Implementation Time**: ~4-6 hours for Phase 1 tests

## Risk Mitigation
- **Start with Mocked Tests**: Test logic without external dependencies
- **Add Integration Tests**: Test with realistic DeFi scenarios
- **Validate Against MEV**: Ensure bounds prevent exploitation
- **Document Assumptions**: Clearly state what "acceptable" means