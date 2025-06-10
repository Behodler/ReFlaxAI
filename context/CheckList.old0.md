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

### Test Scenarios
- [x] Test emergency withdrawal from YieldSource:
  - [x] Check Convex pool status
  - [x] Simulate emergency withdrawal of Convex tokens
  - [x] Verify tokens recovered to Vault

- [x] Test ETH emergency withdrawal
- [x] Test multiple token emergency withdrawals
- [x] Test Curve LP token recovery

### Verification
- [x] Ensure test compiles successfully
- [x] Test is ready to run with Arbitrum fork (requires RPC_URL to be set)
- [x] Test includes proper Convex pool status checks to handle discontinued pools
- [x] Test structure follows integration test patterns