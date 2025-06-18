# Current Story: Rebase Multiplier for Emergency Withdrawal & Formal Verification Fixes

## Purpose of This Story

Implement a rebase multiplier solution to handle emergency withdrawals while maintaining accounting integrity, and fix all Certora formal verification failures to ensure protocol safety.

## Story Status

**Status**: In Progress

**Last Updated**: 2025-06-18

## Story Title
Rebase Multiplier Emergency Withdrawal System & Formal Verification Fixes

### Background & Motivation
- Certora formal verification revealed 11 rule violations and 2 critical invariant failures
- Emergency withdrawal functions break accounting invariants by setting `totalDeposits = 0` without updating user deposits
- The protocol needs a clean way to handle emergency scenarios that makes the vault unusable afterward
- Formal verification must pass to ensure protocol safety and correctness
- Token retention invariants need to focus on preventing inappropriate outflows rather than inflows

### Success Criteria
- All Certora formal verification tests pass
- Emergency withdrawal permanently disables vault in a clean, mathematically sound way
- All user deposits effectively become zero after emergency withdrawal while preserving accounting history
- Updated test suites cover all new functionality
- Specification files are clean and maintainable (no temporary "_fixed" versions)
- Protocol maintains safety properties under all conditions

### Technical Requirements
- Implement rebase multiplier starting at 1e18 (normal operation)
- Emergency withdrawal sets rebase multiplier to 0 (permanently disables vault)
- All user-facing deposit queries use effective deposits (`originalDeposits * rebaseMultiplier / 1e18`)
- Replace token retention invariant with token outflow protection rules
- Update all tests to use effective deposit calculations
- Maintain backward compatibility for existing functionality

### Implementation Plan

1. **Phase 1**: Specification Updates and Cleanup
   - [x] Analyze Certora verification failures
   - [x] Design rebase multiplier solution
   - [x] Create reconciled specification with all fixes
   - [x] Replace Vault.spec with reconciled version
   - [x] Delete temporary specification files

2. **Phase 2**: Contract Implementation
   - [x] Add rebase multiplier to Vault.sol
   - [x] Implement getEffectiveDeposit() and getEffectiveTotalDeposits() functions
   - [x] Update deposit/withdrawal logic to use effective amounts
   - [x] Add permanent disable mechanism (notPermanentlyDisabled modifier)
   - [x] Update emergencyWithdrawFromYieldSource to set rebase multiplier to 0
   - [x] Add appropriate events for rebase multiplier changes

3. **Phase 3**: Test Implementation
   - [ ] Create VaultRebaseMultiplier.t.sol unit tests
   - [ ] Update existing unit tests to use effective deposits
   - [ ] Create VaultEmergency.t.sol for emergency scenarios
   - [ ] Update VaultDeposit.t.sol and VaultWithdraw.t.sol
   - [ ] Create EmergencyRebaseIntegration.t.sol integration tests
   - [ ] Update existing integration tests

4. **Phase 4**: Validation and Documentation
   - [ ] Run all unit tests and ensure they pass
   - [ ] Run all integration tests and ensure they pass
   - [ ] Run Certora preflight checks
   - [ ] Run full Certora verification
   - [ ] Update CLAUDE.md with new functionality
   - [ ] Update TestLog.md with final results

### Progress Log
- **2025-06-18**: Started analysis of Certora failures, identified core issues with emergency functions
- **2025-06-18**: Designed rebase multiplier solution to cleanly handle emergency withdrawals
- **2025-06-18**: Created comprehensive action plan and detailed implementation specifications
- **2025-06-18**: Created reconciled Vault specification with all fixes
- **2025-06-18**: Cleared TestLog.md and started new feature story
- **2025-06-18**: Completed Phase 1 - Replaced Vault.spec with reconciled version, deleted temporary files
- **2025-06-18**: Completed Phase 2 - Implemented rebase multiplier in Vault.sol, all functions updated with new logic

### Notes and Discoveries
- **Root Cause**: Emergency functions directly modify `totalDeposits` without updating individual user deposits, breaking accounting invariants
- **Solution**: Rebase multiplier allows mathematical zeroing of all user deposits without breaking storage consistency
- **Key Insight**: Emergency withdrawal should permanently disable vault - this is appropriate for true emergencies
- **Token Safety**: Focus shifted from preventing token inflows (impossible to prevent) to preventing inappropriate outflows
- **Specification Strategy**: Use rules instead of strict invariants for token retention to allow better control over edge cases

### Files to Modify

#### Contracts:
- `src/vault/Vault.sol` - Add rebase multiplier functionality

#### Specifications:
- `certora/specs/Vault.spec` - Replace with reconciled version
- Delete: `certora/specs/Vault_fixed.spec`, `certora/debugging/Vault_reconciled.spec`

#### Tests:
- `test/unit/vault/VaultRebaseMultiplier.t.sol` (new)
- `test/unit/vault/VaultEmergency.t.sol` (new)
- `test/unit/vault/VaultDeposit.t.sol` (update)
- `test/unit/vault/VaultWithdraw.t.sol` (update)
- `test/integration/EmergencyRebaseIntegration.t.sol` (new)

### Current Focus
Moving to Phase 3: Test implementation - Creating new unit tests for rebase multiplier functionality and updating existing tests.