# Current Story: Curve Pool Imbalance Integration Test

## Purpose of This Story

Implement comprehensive integration tests that verify the ReFlax protocol's behavior when Curve pools experience significant imbalances, ensuring proper handling of slippage, LP token calculations, and user protection.

## Story Status

**Status**: Completed

**Last Updated**: 2025-06-16

## Story Title
Curve Pool Imbalance Integration Test Implementation

### Background & Motivation
- Curve pools can become significantly imbalanced when one asset is in high demand or low supply
- Pool imbalances affect LP token calculations, slippage, and withdrawal values
- The protocol needs to handle extreme imbalances gracefully without exposing users to excessive losses
- Slippage protection mechanisms must prevent bad trades during imbalanced conditions
- This test ensures the protocol operates safely even under stressed market conditions

### Success Criteria
- Test passes with real Arbitrum mainnet fork
- Successfully creates and tests various pool imbalance scenarios
- Slippage protection correctly prevents excessive losses
- LP token calculations accurately reflect pool conditions
- Users are protected from unfavorable trades
- Clear documentation of imbalance effects on protocol operations

### Technical Requirements
- Extend IntegrationTest base contract following project patterns
- Use real Curve pool (USDC/USDe) on Arbitrum mainnet fork
- Manipulate pool balance through large one-sided trades
- Test deposit, withdrawal, and slippage protection under imbalanced conditions
- Use calc_token_amount() for realistic LP calculations
- Follow existing test patterns from RealisticDepositFlow.integration.t.sol

### Implementation Plan

1. **Phase 1**: Setup and Infrastructure
   - [x] Clear context/TestLog.md 
   - [x] Update context/CurrentStory.md with task details
   - [x] Create test file: `test-integration/yieldSource/CurveImbalance.integration.t.sol`
   - [x] Set up test structure extending IntegrationTest

2. **Phase 2**: Core Test Implementation
   - [x] Implement testDepositWithSevereImbalance()
   - [x] Implement testWithdrawalFromImbalancedPool()
   - [x] Implement testSlippageProtectionPreventsImbalancedTrades()
   - [x] Implement testPoolRebalancingEffects()
   - [x] Implement testMultiUserImbalanceScenario()

3. **Phase 3**: Testing and Validation
   - [x] Run tests and ensure they pass
   - [x] Update context/TestLog.md with results
   - [x] Update IntegrationCoverage.md to mark completed

### Progress Log
- **2025-06-16**: Started implementation, cleared TestLog.md and updated CurrentStory.md
- **2025-06-16**: Completed all 5 test implementations
- **2025-06-16**: Fixed whale balance issues by adjusting deposit amounts
- **2025-06-16**: All tests passing, updated documentation

### Notes and Discoveries
- Will use USDC/USDe Curve pool on Arbitrum for testing
- Need to create imbalances by executing large one-sided trades
- Must handle StableSwapNG interface with dynamic arrays
- Consider pool virtual price effects on LP calculations
- Discovered that extreme pool imbalances can lead to counterintuitive behavior where withdrawing to the abundant token gives more value
- USDe whale balance constraints required reducing test amounts from initial plans
- Scarce token deposits receive over 100x bonus LP tokens in heavily imbalanced pools
- Slippage protection successfully prevents trades with >54% slippage