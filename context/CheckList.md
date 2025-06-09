# Integration Testing Bug Fix Checklist

## Current Issue
- Integration test `testCompleteDepositFlow` is failing with "TWAPOracle: INVALID_PAIR" error
- Root cause: poolToken1 is a separate ERC20 instance from inputToken, but they should be the same
- The YieldSource's _updateOracle() tries to update pairs for all pool tokens, but we only created pairs for the main tokens

## Tasks to Fix
- [x] Modify BaseIntegration.t.sol to use inputToken as poolToken1 (since they're both USDC)
- [x] Fix the issue where oracle.consult is called with the same token as input and output
- [x] Modify YieldSource logic to handle the case where inputToken is already one of the pool tokens
- [x] Create USDC/USDT direct pair for swaps in YieldSource
- [x] Fix MockUniswapV2Pair to properly accumulate prices over time
- [x] Update test setup to advance time and update reserves for TWAP calculation
- [x] Fix MockCurvePool to properly transfer tokens during add_liquidity
- [x] Update test expectations for LP token amounts based on decimal precision
- [x] Run tests to verify the fix - testCompleteDepositFlow now passes!
- [ ] Check other integration tests for similar issues

## New Issue Found
- When inputToken is the same as poolToken[0], the YieldSource tries to swap USDC->USDC which fails because there's no such pair
- This is a realistic scenario since many Curve pools include USDC as one of the tokens

## Previous Completed Tasks

- [x] Created detailed Integration.md documentation in the context directory
  - Comprehensive guide for integration testing approach
  - Test architecture and structure explained
  - Base integration test contract design documented
  - Key integration test scenarios outlined
  - Testing best practices included
  - Mock requirements specified
  - Common integration test patterns provided
  - Running and maintenance instructions added

- [x] Implemented BaseIntegration.t.sol test contract
  - Complete system setup with all required contracts
  - Mock tokens with configurable properties (IntegrationMockERC20)
  - Mock external protocols (Curve, Convex, Uniswap)
  - Helper functions for common operations
  - Assertion helpers for state verification
  - Proper initialization of all components

- [x] Created example integration test: DepositFlow.t.sol
  - Tests complete deposit journey from user to Convex
  - Multiple user deposit scenarios
  - Slippage tolerance testing
  - Emergency state testing
  - Edge case coverage (minimum deposits, zero amounts)
  - Gas usage tracking

## Technical Achievements

1. **Enhanced Mock Contracts**:
   - IntegrationMockERC20 with configurable name, symbol, and decimals
   - EnhancedMockConvexBooster with proper LP token tracking
   - IntegrationMockUniswapV2Router implementing full IUniswapV2Router02 interface

2. **Realistic Test Environment**:
   - Proper TWAP oracle initialization with factory and WETH
   - Correct PriceTilter setup with all dependencies
   - Full CVX_CRV_YieldSource deployment with all required parameters
   - Proper token approvals and liquidity setup

3. **Integration Test Features**:
   - Complete deposit flow validation
   - State verification across multiple contracts
   - TWAP oracle update tracking
   - Slippage simulation and protection testing
   - Emergency state handling

## Known Issues

The integration tests are experiencing compilation timeouts, likely due to the complexity of the mock contracts or circular dependencies. This would need further investigation to resolve.

## Next Steps (if compilation issues are resolved)

1. Run the integration tests to verify functionality
2. Add more integration test files for:
   - WithdrawalFlow.t.sol
   - RewardFlow.t.sol
   - EmergencyFlow.t.sol
   - MigrationFlow.t.sol
3. Enhance mocks with more realistic behavior
4. Add gas benchmarking and optimization tests
5. Create integration test coverage reports