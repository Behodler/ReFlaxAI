# Smart Mutation Filter Configuration

## Philosophy: Signal Over Noise

This filter focuses mutation testing on ReFlax-specific business logic while excluding well-tested library code and low-value mutations that don't provide meaningful security insights.

## Exclusion Criteria

### 1. OpenZeppelin Library Code
**Rationale**: Battle-tested, extensively audited, not ReFlax-specific
- **Ownership Functions**: `_checkOwner()`, `_transferOwnership()`, `transferOwnership()`
- **Access Control**: Standard Ownable modifiers and checks
- **ERC20 Interactions**: Standard SafeERC20 operations
- **Reentrancy Guards**: Standard OpenZeppelin patterns

**Excluded Mutation Types**:
- DeleteExpressionMutation on `_checkOwner()`
- IfStatementMutation on `owner() == msg.sender`
- RequireMutation on standard ownership requires

### 2. View Functions and Getters
**Rationale**: No state changes, minimal security impact
- **Simple Getters**: `flaxToken()`, `sFlaxToken()`, `inputToken()`, `owner()`
- **View Functions**: `getEffectiveDeposit()`, `getEffectiveTotalDeposits()`
- **State Readers**: `emergencyState()`, `rebaseMultiplier()`

**Excluded Mutation Types**:
- Any mutations in functions marked `view` or `pure`
- Return value mutations for simple getters

### 3. Equivalent Mutations
**Rationale**: Don't change behavior, waste testing time
- **Arithmetic Equivalents**: `x * 1` → `x / 1` (both equivalent to `x`)
- **Boolean Equivalents**: `!(!condition)` → `condition`
- **Assignment Equivalents**: `x = x + 0` → `x = x - 0`

### 4. Low-Impact Boundary Mutations
**Rationale**: Already covered by comprehensive boundary testing
- **Off-by-one on Constants**: `1e18` → `1e18 + 1`
- **Precision Mutations**: Minor decimal place changes that don't affect logic

## Inclusion Criteria (High Priority)

### 1. ReFlax Business Logic
**Critical Functions**:
- `deposit()` - Core user interaction
- `withdraw()` - Fund recovery logic
- `claimRewards()` - Reward distribution
- `migrateYieldSource()` - Protocol migration

**High-Value Mutations**:
- Amount validation logic
- Balance calculations
- Surplus/shortfall handling
- Emergency state enforcement

### 2. Financial Calculations
**Critical Areas**:
- `effectiveBalance()` calculations
- Surplus token management
- Shortfall protection logic
- Rebase multiplier operations

**High-Value Mutations**:
- Arithmetic operations in financial logic
- Condition checks in loss protection
- Balance update sequences

### 3. State Transitions
**Critical Functions**:
- Emergency state changes
- Vault permanent disabling
- YieldSource migration state updates

**High-Value Mutations**:
- State validation logic
- Transition condition checks
- State consistency enforcement

### 4. DeFi Integration Points
**Critical Areas**:
- YieldSource interaction calls
- Token transfer operations
- External contract state assumptions

**High-Value Mutations**:
- Return value handling
- Error condition responses
- Integration assumption checks

## Filter Implementation Strategy

### Phase 1: Manual Exclusion
1. **Identify Mutation IDs**: Review mutation generation output
2. **Categorize by Function**: Group mutations by the function they target
3. **Apply Exclusion Rules**: Mark mutations that match exclusion criteria
4. **Document Decisions**: Record why each category was excluded

### Phase 2: Automated Filtering
1. **Create Filter Script**: Develop script to automatically exclude based on rules
2. **Validate Against Manual**: Ensure automated filter matches manual decisions
3. **Apply to All Contracts**: Extend filtering to YieldSource, PriceTilter, TWAPOracle

### Expected Results

#### Vault Contract Filtering
- **Total Mutations Generated**: 263 (from previous testing)
- **Excluded (OpenZeppelin)**: ~50-60 mutations
- **Excluded (View Functions)**: ~15-20 mutations  
- **Excluded (Equivalent)**: ~10-15 mutations
- **Remaining (High-Value)**: ~180-200 mutations

#### Protocol-Wide Filtering
- **Total Generated**: 875 mutations across all contracts
- **Expected Filtered**: ~500 high-value mutations
- **Efficiency Gain**: 43% time savings, 100% quality focus

### Quality Metrics

#### Success Indicators
1. **Mutation Score**: 85%+ on filtered mutations
2. **Time Efficiency**: <50% of total generation time
3. **Coverage Quality**: All critical business logic tested
4. **False Positive Rate**: <5% of excluded mutations should have been included

#### Validation Checks
1. **No Critical Logic Excluded**: Manual review ensures no business logic excluded
2. **Appropriate OpenZeppelin Exclusion**: Only standard library patterns excluded
3. **Equivalent Mutation Detection**: Mutations that don't change behavior properly identified

## Implementation Commands

### Generate Filtered Mutations
```bash
# Generate all mutations first
gambit mutate --contract src/vault/Vault.sol

# Apply smart filter (manual process for now)
# 1. Review mutation output
# 2. Identify exclusion categories
# 3. Create filtered test command

# Run filtered testing
gambit test --mutation-testing --skip-equivalent
```

### Documentation Requirements
Each exclusion decision must be documented with:
1. **Mutation ID**: Specific mutation identifier
2. **Function**: Which function contains the mutation
3. **Exclusion Reason**: Which filter rule applies
4. **Risk Assessment**: Why this mutation is low-value

---

**Created**: June 25, 2025  
**Purpose**: Focus mutation testing on signal over noise  
**Expected Outcome**: 85%+ mutation score on ReFlax-specific business logic  
**Key Principle**: Test what matters, skip what's already battle-tested