# YieldSource Survival Analysis - Critical Test Coverage Gaps

## Executive Summary
**Total Surviving**: 127 mutations (54% survival rate)
**Critical Finding**: Major test coverage gaps in DeFi integration logic

## Defi Integration (2 mutations)

**Mutation 116**: DeleteExpressionMutation
- Location: 276:9
- Description: "IConvexBooster(convexBooster).deposit(poolId, lpAmount, true)",assert(true)

**Mutation 139**: DeleteExpressionMutation
- Location: 314:13
- Description: "IConvexBooster(convexBooster).withdraw(poolId, lpAmountToWithdraw)",assert(true)

## Weight Distribution (23 mutations)

**Mutation 58**: IfStatementMutation
- Location: 235:13
- Description: weights.length == 0,false

**Mutation 59**: DeleteExpressionMutation
- Location: 236:13
- Description: weights = new uint256[](poolTokens.length),assert(true)

**Mutation 60**: DeleteExpressionMutation
- Location: 238:17
- Description: weights[i] = 10000 / poolTokens.length,assert(true)

**Mutation 61**: AssignmentMutation
- Location: 238:30
- Description: 10000 / poolTokens.length,0

**Mutation 62**: AssignmentMutation
- Location: 238:30
- Description: 10000 / poolTokens.length,1

... and 18 more similar mutations

## If Statements (24 mutations)

**Mutation 51**: IfStatementMutation
- Location: 218:17
- Description: rewardTokens[i] != address(0) && rewardTokens[i] != address(flaxToken),true

**Mutation 52**: IfStatementMutation
- Location: 218:17
- Description: rewardTokens[i] != address(0) && rewardTokens[i] != address(flaxToken),false

**Mutation 83**: IfStatementMutation
- Location: 249:17
- Description: address(poolTokens[i]) == address(inputToken),true

**Mutation 84**: IfStatementMutation
- Location: 249:17
- Description: address(poolTokens[i]) == address(inputToken),false

**Mutation 85**: IfStatementMutation
- Location: 251:24
- Description: allocatedAmount > 0,true

... and 19 more similar mutations

## Assignments (17 mutations)

**Mutation 121**: AssignmentMutation
- Location: 309:34
- Description: 0,1

**Mutation 143**: AssignmentMutation
- Location: 320:39
- Description: i,0

**Mutation 154**: AssignmentMutation
- Location: 351:40
- Description: 0,1

**Mutation 259**: AssignmentMutation
- Location: 495:27
- Description: amounts[0],0

**Mutation 260**: AssignmentMutation
- Location: 495:27
- Description: amounts[0],1

... and 12 more similar mutations

## Other (61 mutations)

**Mutation 63**: BinaryOpMutation
- Location: 238:35
- Description:  / ,+

**Mutation 64**: BinaryOpMutation
- Location: 238:35
- Description:  / ,-

**Mutation 65**: BinaryOpMutation
- Location: 238:35
- Description:  / ,*

**Mutation 66**: BinaryOpMutation
- Location: 238:35
- Description:  / ,%

**Mutation 88**: DeleteExpressionMutation
- Location: 268:17
- Description: amounts[i] = 0,assert(true)

... and 56 more similar mutations

## Major Gap Clusters

### Cluster 1: Weight Distribution (58-66)
- **Pattern**: Binary operations in weight calculations
- **Impact**: Financial calculation security
- **Tests Needed**: Weight edge cases, division by zero

### Cluster 2: DeFi Integration (148-174)
- **Pattern**: 27 consecutive surviving mutations
- **Impact**: Uniswap/Curve interaction security
- **Tests Needed**: DeFi protocol failure scenarios

### Cluster 3: Financial Operations (253-280)
- **Pattern**: Critical arithmetic operations
- **Impact**: User fund safety
- **Tests Needed**: Financial boundary conditions

