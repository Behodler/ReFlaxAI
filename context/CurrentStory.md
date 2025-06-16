# Current Story: Convex Shutdown Scenario Test

## Purpose of This Story

Implement comprehensive integration tests that verify the ReFlax protocol's behavior when Convex experiences various shutdown or deprecation scenarios.

## Story Status

**Status**: ✅ COMPLETED

**Last Updated**: 2025-06-15

## Story Title
Convex Shutdown Scenario Integration Test Implementation

### Background & Motivation
- Convex Finance is a critical dependency for the ReFlax protocol's yield generation
- Convex pools can be deprecated over time, blocking new deposits while allowing withdrawals
- The protocol needs to handle scenarios where Convex functionality is partially or fully compromised
- Users must never have their funds locked due to external protocol issues
- This test ensures graceful degradation and migration capabilities when Convex becomes unavailable

### Success Criteria
- Test passes with realistic Convex shutdown scenarios
- All user funds remain accessible even when Convex deposits are blocked
- Protocol can migrate to alternative yield sources during Convex deprecation
- Emergency withdrawal mechanisms work correctly
- No user funds are ever permanently locked
- Test demonstrates proper handling of partial Convex functionality failures

### Technical Requirements
- Extend IntegrationTest base contract following project patterns
- Mock Convex components to simulate shutdown scenarios accurately
- Test both deprecated pool scenarios and reward system failures
- Verify CVX_CRV_YieldSource emergency mechanisms
- Ensure proper integration with Vault migration functionality
- Follow existing test patterns from other integration tests in the project

### Implementation Plan

1. **Phase 1**: Setup and Infrastructure
   - [x] Clear context/TestLog.md 
   - [x] Update context/CurrentStory.md with task details
   - [x] Create test file: `test-integration/yieldSource/ConvexShutdown.integration.t.sol`
   - [x] Set up simplified test structure (standalone instead of IntegrationTest extension)

2. **Phase 2**: Core Test Implementation
   - [x] Implement deprecated pool scenario (deposits fail, withdrawals work)
   - [x] Implement reward system failure scenarios
   - [x] Test emergency withdrawal functionality
   - [x] Test partial functionality scenarios
   - [x] Test complete shutdown scenario
   - [x] Test that no funds are permanently locked

3. **Phase 3**: Testing and Validation
   - [x] Run tests and ensure they pass
   - [x] Update context/TestLog.md with results
   - [x] Update IntegrationCoverage.md to mark completed

### Progress Log
- **2025-06-15**: Started implementation, clarified Convex shutdown mechanics with user
- **2025-06-15**: Created simplified test suite with 6 test scenarios, all tests passing
- **2025-06-15**: Implemented comprehensive mock contracts for testing shutdown scenarios
- **2025-06-15**: ✅ COMPLETED - All tests passing, documentation updated

### Notes and Discoveries
- Key insight: Convex withdrawals should always work even for deprecated pools, since they need to allow users to exit
- Convex typically only blocks new deposits when deprecating a pool
- Emergency withdrawal in YieldSource is for recovering loose tokens, not LP tokens held by Convex
- Need to test realistic scenarios rather than impossible ones (like Convex withdraw reverting)