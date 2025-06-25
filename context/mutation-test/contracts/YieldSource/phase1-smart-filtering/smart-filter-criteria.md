# Smart Filtering Criteria for CVX_CRV_YieldSource

## Filtering Philosophy
Based on proven Vault methodology, focus on ReFlax-specific business logic while excluding noise mutations.

## Exclusion Categories

### 1. View/Pure Function Mutations (Estimated: 15-20)
**Criteria**: Functions that don't modify state or handle critical business logic
**Rationale**: View functions typically don't contain security vulnerabilities

**Target Exclusions**:
- Getter functions (if any)
- Internal view helpers
- Pure calculation utilities

### 2. Constructor Validation (Estimated: 10-15)  
**Criteria**: Obvious constructor validation mutations that don't test business logic
**Rationale**: Constructor validation is important but some mutations are equivalent

**Target Exclusions**:
- `assert(true)` replacements for obvious requires
- Trivial parameter validation mutations

### 3. Low-Risk Access Control (Estimated: 5-10)
**Criteria**: Standard OpenZeppelin access control patterns
**Rationale**: Well-tested patterns, focus on ReFlax-specific logic

**Target Exclusions**:
- Standard `onlyOwner` mutations (keep critical ones)
- Whitelist validation mutations that are equivalent

### 4. Equivalent Mathematical Operations (Estimated: 8-12)
**Criteria**: Math operations that produce equivalent results
**Rationale**: Focus on meaningful arithmetic changes

**Target Exclusions**:
- Division by same constant with different operators  
- Equivalent percentage calculations
- Order-independent operations

### 5. Oracle Update Calls (Estimated: 5-8)
**Criteria**: TWAP oracle update calls that are infrastructure
**Rationale**: Oracle updates are infrastructure, not core business logic

**Target Exclusions**:
- `oracle.update()` calls that are pure infrastructure
- Oracle update mutations in constructor

## High-Value Inclusions (Priority Testing)

### 1. DeFi Integration Logic (Priority: CRITICAL)
**Lines ~240-300**: Core deposit/withdrawal flows
- Uniswap V3 swap logic
- Curve liquidity addition/removal  
- Slippage protection calculations
- Token allocation logic

### 2. Financial Calculations (Priority: CRITICAL)
**Lines ~246-268**: Amount calculations and weight distributions
- Pool token allocation: `(amount * weights[i]) / 10000`
- Slippage calculations: `(minOut * (10000 - minSlippageBps)) / 10000`
- Balance tracking logic

### 3. Convex Integration (Priority: HIGH)
**Lines ~300-400**: Convex protocol interactions
- Convex booster deposits
- Reward claiming logic
- LP token management

### 4. Emergency Functions (Priority: HIGH)
**Lines ~500+**: Emergency withdrawal mechanisms
- Emergency state handling
- Asset recovery logic
- Owner-only emergency functions

### 5. Input Validation (Priority: MEDIUM)
**Lines ~149-191**: Constructor and parameter validation
- Pool token validation
- Weight validation logic  
- Token approval setup

## Filtering Targets by Mutation Type

### DeleteExpressionMutation
**Include**: Critical requires, state modifications, DeFi calls
**Exclude**: Obvious infrastructure, constructor validation

### RequireMutation  
**Include**: Financial validation, DeFi safety checks
**Exclude**: Obvious true/false toggles, constructor basics

### IfStatementMutation
**Include**: Business logic conditions, DeFi flow control
**Exclude**: Null checks, basic validation

### BinaryOpMutation
**Include**: Financial calculations, slippage logic
**Exclude**: Equivalent math, constant operations

### AssignmentMutation
**Include**: Critical state variables, financial values
**Exclude**: Trivial assignments, constructor setup

## Expected Results
- **Total Mutations**: 303
- **Estimated Exclusions**: 40-60 (13-20%)
- **High-Value Target**: 240-260 mutations
- **Target Score**: 85%+ on filtered set
- **Focus**: DeFi integration security and financial calculation correctness

## Success Metrics
1. **Efficient Execution**: 15-25% time savings vs full set
2. **Higher Quality Score**: 85%+ vs estimated 75% on full set  
3. **Security Focus**: High kill rate on DeFi integration mutations
4. **Reusable Methodology**: Approach applicable to PriceTilter and TWAPOracle