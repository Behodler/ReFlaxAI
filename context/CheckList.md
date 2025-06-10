# CheckList: Emergency State Recovery Integration Test

## Task: Implement Emergency State Recovery Test (Priority 1, Item #1)

### Preparation
- [x] Review existing emergency functionality in Vault and YieldSource contracts
- [x] Review IntegrationTest base contract and setup patterns
- [x] Check ArbitrumConstants for required addresses

### Implementation Steps
- [x] Create test file: `test-integration/vault/EmergencyRecovery.integration.t.sol`
- [x] Set up test contract extending IntegrationTest
- [x] Implement test setup:
  - [x] Simplified setup without complex mock token deployment
  - [x] Use mock addresses for vault and yield source
  - [x] Fund test users with USDC
  - [x] Handle cases where USDC whale might have insufficient balance

### Test Scenarios
- [x] Test emergency withdrawal from YieldSource:
  - [x] Check Convex pool status
  - [x] Simulate emergency withdrawal of Convex tokens
  - [x] Verify tokens recovered to Vault
  - [x] Handle Convex pool info decode issues

- [x] Test ETH emergency withdrawal
- [x] Test multiple token emergency withdrawals
- [x] Test Curve LP token recovery

### Verification
- [x] Ensure test compiles successfully
- [x] Run test with Arbitrum fork
- [x] Verify all assertions pass (All 5 tests passing)
- [x] Integration with existing test suite confirmed

### Issues Resolved
- Fixed abi.decode issues with Convex poolInfo by avoiding struct decoding
- Handled RPC fork setup issues with direnv
- Made tests resilient to discontinued Convex pools
- All tests now pass successfully