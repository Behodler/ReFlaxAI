# Formal Verification Backlog

## Overview
This document tracks remaining formal verification tasks for the ReFlax protocol. Tasks are prioritized based on security impact and deployment readiness.

## Completed Work
- ✅ Vault contract verification (20/24 rules passing)
- ✅ TWAPOracle contract verification (10/14 rules passing)
- ✅ Rebase multiplier implementation in Vault

## TODO Items

### 1. Risk Assessment Report - Vault Edge Cases
**Priority**: High  
**Status**: Not Started

Create a production risk assessment for the 4 failing Vault rules:
- `emergencyWithdrawalDisablesVault`
- `sFlaxBurnBoostsRewards`
- `withdrawalRespectsSurplus`
- `withdrawalCannotAffectOthers`

**Deliverable**: Report analyzing practical risks assuming:
- Proper deployment procedures
- Secure owner key management
- Active monitoring
- Emergency disable mechanisms in place

### 2. Risk Assessment Report - TWAPOracle Edge Cases
**Priority**: High  
**Status**: Not Started

Create a production risk assessment for the 4 failing TWAPOracle rules:
- Time monotonicity violations
- Update count tracking issues
- State preservation for view functions
- Initial state invariant problems

**Deliverable**: Report analyzing whether these edge cases pose real production risks given proper operational procedures.

### 3. YieldSource Formal Verification
**Priority**: Critical  
**Status**: Not Started

Implement formal verification for YieldSource contracts:
- CVX_CRV_YieldSource specification
- DeFi integration safety rules
- Emergency withdrawal mechanisms
- Reward processing verification
- TWAP oracle update requirements

**Tasks**:
1. Create YieldSource.spec file
2. Define safety properties and invariants
3. Run verification and resolve issues
4. Document results

### 4. PriceTilter Formal Verification
**Priority**: Critical  
**Status**: Not Started

Implement formal verification for PriceTilter:
- Pricing accuracy rules
- Manipulation resistance properties
- Liquidity management specifications
- ETH handling verification
- Emergency withdrawal safety

**Tasks**:
1. Create PriceTilter.spec file
2. Define economic invariants
3. Verify price tilting mechanism
4. Document results

### 5. Comprehensive Formal Verification Report
**Priority**: Medium  
**Status**: Not Started

Create a comprehensive report for the dapp community that includes:
- Executive summary of formal verification benefits
- Overview of properties verified for each contract
- Technical details of key invariants
- Risk assessment summaries
- Comparison to industry standards
- Future verification roadmap

**Audience**: Dapp developers and security-conscious users
**Format**: Balance technical accuracy with accessibility

## Notes
- All verification should use local Certora runs for development
- Cloud verification only for final reports
- Each completed item should update `certora/reports/` with results
- Risk assessments should consider ReFlax's specific deployment context