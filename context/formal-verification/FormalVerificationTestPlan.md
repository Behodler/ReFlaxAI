# Formal Verification Test Plan

This document outlines the comprehensive formal verification strategy for the ReFlax protocol using Certora Prover. The plan focuses on critical security properties, fund safety, and mathematical correctness.

## Complete

*This section will be populated as formal verification tests are implemented and validated.*

## TODO

### 1. Vault Contract Core Properties

#### 1.1 Fund Safety and Accounting Integrity
**Priority: Critical**  
**Description**: Verify that user funds cannot be lost through accounting errors and that the vault maintains accurate deposit tracking.

**Specifications to Implement**:
- **Invariant**: `totalDeposits == sum(originalDeposits[user] for all users)`
- **Invariant**: `inputToken.balanceOf(address(this)) >= surplusInputToken`
- **Rule**: After deposit, `originalDeposits[user]` increases by exactly the deposited amount
- **Rule**: After withdrawal, user receives their original deposit amount (minus legitimate protocol losses)
- **Rule**: `surplusInputToken` can only increase from yield source operations, never decrease below zero

**Certora Spec Structure**:
```cvl
// Ghost variables to track total user deposits
ghost mapping(address => uint256) ghostUserDeposits;
ghost uint256 ghostTotalUserDeposits;

invariant totalDepositsMatchesUserSum()
    totalDeposits == ghostTotalUserDeposits
```

**Dependencies**: None  
**Implementation Notes**: Use ghost variables to track cumulative deposits and ensure they match contract state.

#### 1.2 Access Control and Ownership
**Priority: High**  
**Description**: Verify that only authorized entities can perform privileged operations and that access control cannot be bypassed.

**Specifications to Implement**:
- **Rule**: Only owner can call `setYieldSource`, `setFlaxPerSFlax`, `setEmergencyState`
- **Rule**: Only whitelisted vaults can call yield source functions
- **Rule**: Emergency state prevents deposits, claims, and migrations
- **Rule**: Owner cannot be set to zero address
- **Invariant**: Emergency state can only be set by owner

**Certora Spec Structure**:
```cvl
rule onlyOwnerCanSetEmergencyState(address caller) {
    env e;
    require e.msg.sender == caller;
    bool emergencyBefore = emergencyState;
    setEmergencyState(e, true);
    bool emergencyAfter = emergencyState;
    assert emergencyBefore != emergencyAfter => caller == owner;
}
```

**Dependencies**: None  
**Implementation Notes**: Test all owner-only functions and verify access control reverts for unauthorized calls.

#### 1.3 Deposit and Withdrawal Logic
**Priority: Critical**  
**Description**: Verify that deposit and withdrawal operations maintain mathematical correctness and proper state transitions.

**Specifications to Implement**:
- **Rule**: Deposit transfers correct amount to yield source, not retained in vault
- **Rule**: Withdrawal returns original deposit amount when possible
- **Rule**: Surplus tokens are used to cover withdrawal shortfalls
- **Rule**: `protectLoss` parameter correctly prevents lossy withdrawals
- **Rule**: Emergency state prevents new deposits

**Certora Spec Structure**:
```cvl
rule depositTransfersToYieldSource(address user, uint256 amount) {
    env e;
    require e.msg.sender == user;
    uint256 vaultBalanceBefore = inputToken.balanceOf(currentContract);
    uint256 yieldSourceBalanceBefore = inputToken.balanceOf(yieldSource);
    
    deposit(e, amount);
    
    uint256 vaultBalanceAfter = inputToken.balanceOf(currentContract);
    uint256 yieldSourceBalanceAfter = inputToken.balanceOf(yieldSource);
    
    assert vaultBalanceAfter == vaultBalanceBefore; // Vault retains no tokens
    assert yieldSourceBalanceAfter == yieldSourceBalanceBefore + amount;
}
```

**Dependencies**: YieldSource contract  
**Implementation Notes**: Focus on the flow of tokens and state changes during deposit/withdrawal operations.

#### 1.4 sFlax Token Burning Mechanism
**Priority: Medium**  
**Description**: Verify that sFlax burning provides correct reward boosts and maintains mathematical consistency.

**Specifications to Implement**:
- **Rule**: Burning sFlax tokens increases Flax rewards by `amount * flaxPerSFlax / 1e18`
- **Rule**: sFlax tokens are actually burned (supply decreases)
- **Rule**: Only user's own sFlax tokens can be burned during claims
- **Invariant**: `flaxPerSFlax` can only be set by owner

**Certora Spec Structure**:
```cvl
rule sFlaxBurningIncreasesRewards(address user, uint256 sFlaxAmount) {
    env e;
    require e.msg.sender == user;
    uint256 expectedBoost = sFlaxAmount * flaxPerSFlax / 1e18;
    uint256 rewardsBefore = getExpectedRewards(user);
    
    burnSFlaxForRewards(e, sFlaxAmount);
    
    uint256 rewardsAfter = getExpectedRewards(user);
    assert rewardsAfter == rewardsBefore + expectedBoost;
}
```

**Dependencies**: sFlaxToken contract (mock for burning behavior)  
**Implementation Notes**: Verify the mathematical correctness of reward calculations.

### 2. YieldSource Contract Properties

#### 2.1 DeFi Integration Safety
**Priority: Critical**  
**Description**: Verify that interactions with external DeFi protocols (Curve, Convex, Uniswap) maintain fund safety and slippage protection.

**Specifications to Implement**:
- **Rule**: Slippage protection prevents trades below minimum acceptable rates
- **Rule**: TWAP oracle updates occur at the beginning of deposit, withdraw, and claim operations
- **Rule**: External protocol failures don't cause permanent fund loss
- **Rule**: All reward tokens are properly claimed and converted

**Certora Spec Structure**:
```cvl
rule slippageProtectionEnforced(uint256 amountIn, uint256 minAmountOut) {
    env e;
    uint256 actualAmountOut = performSwap(e, amountIn);
    assert actualAmountOut >= minAmountOut;
}
```

**Dependencies**: Mock external protocols  
**Implementation Notes**: Use harness contracts to simulate external DeFi protocol interactions.

#### 2.2 Emergency Withdrawal Mechanisms
**Priority: High**  
**Description**: Verify that emergency withdrawals can recover funds in all scenarios and maintain access control.

**Specifications to Implement**:
- **Rule**: Owner can always perform emergency withdrawal
- **Rule**: Emergency withdrawal attempts to recover funds from external protocols first
- **Rule**: Emergency withdrawal updates total deposited amounts correctly
- **Rule**: Normal operations are disabled during emergency recovery

**Certora Spec Structure**:
```cvl
rule emergencyWithdrawalRecoversFunds(address token, uint256 amount) {
    env e;
    require e.msg.sender == owner;
    uint256 balanceBefore = IERC20(token).balanceOf(owner);
    
    emergencyWithdraw(e, token, amount);
    
    uint256 balanceAfter = IERC20(token).balanceOf(owner);
    assert balanceAfter >= balanceBefore;
}
```

**Dependencies**: None  
**Implementation Notes**: Test emergency scenarios and recovery mechanisms.

#### 2.3 Reward Processing and Conversion
**Priority: Medium**  
**Description**: Verify that reward claiming, selling, and Flax value calculation maintain mathematical correctness.

**Specifications to Implement**:
- **Rule**: All claimable rewards are processed
- **Rule**: Reward tokens are sold at acceptable rates
- **Rule**: ETH to Flax value calculation uses current oracle prices
- **Rule**: Price tilting operations maintain mathematical consistency

**Certora Spec Structure**:
```cvl
rule rewardConversionMaintainsValue(uint256 ethAmount) {
    env e;
    uint256 flaxValue = calculateFlaxValue(e, ethAmount);
    uint256 oraclePrice = oracle.consult(WETH, ethAmount, flaxToken);
    assert flaxValue <= oraclePrice; // Account for slippage
}
```

**Dependencies**: PriceTilter, Oracle contracts  
**Implementation Notes**: Focus on the mathematical relationships in reward processing.

### 3. PriceTilter Contract Properties

#### 3.1 Pricing Accuracy and Manipulation Resistance
**Priority: Critical**  
**Description**: Verify that price calculations are accurate and resistant to manipulation attacks.

**Specifications to Implement**:
- **Rule**: Flax value calculations use current TWAP prices
- **Rule**: Price tilting ratio is applied correctly to liquidity provision
- **Rule**: All ETH sent to contract is used for liquidity provision
- **Rule**: Price tilting cannot be manipulated by flash loans or MEV attacks

**Certora Spec Structure**:
```cvl
rule priceTiltingUsesCorrectRatio(uint256 ethAmount) {
    env e;
    uint256 flaxAmount = calculateFlaxForLiquidity(e, ethAmount);
    uint256 oracleFlaxAmount = oracle.consult(WETH, ethAmount, flaxToken);
    uint256 expectedFlaxAmount = oracleFlaxAmount * priceTiltRatio / 10000;
    assert flaxAmount == expectedFlaxAmount;
}
```

**Dependencies**: TWAPOracle, Uniswap V2 contracts  
**Implementation Notes**: Verify mathematical relationships and oracle dependency.

#### 3.2 Liquidity Management
**Priority: Medium**  
**Description**: Verify that liquidity provision operations maintain fund safety and proper state management.

**Specifications to Implement**:
- **Rule**: All ETH balance is used for liquidity provision
- **Rule**: Flax tokens are transferred correctly for liquidity operations
- **Rule**: LP tokens are handled appropriately
- **Rule**: Owner can register and manage pairs correctly

**Certora Spec Structure**:
```cvl
rule ethBalanceUsedForLiquidity() {
    env e;
    uint256 ethBalanceBefore = address(this).balance;
    addLiquidityETH(e);
    uint256 ethBalanceAfter = address(this).balance;
    assert ethBalanceAfter == 0; // All ETH should be used
}
```

**Dependencies**: Uniswap V2 Router  
**Implementation Notes**: Track ETH and token balances through liquidity operations.

### 4. TWAPOracle Contract Properties

#### 4.1 Time-Based Calculations
**Priority: Critical**  
**Description**: Verify that TWAP calculations are mathematically correct and time-dependent operations function properly.

**Specifications to Implement**:
- **Rule**: TWAP calculations use exactly 1-hour periods
- **Rule**: Oracle updates require minimum time elapsed
- **Rule**: Price accumulator updates are mathematically correct
- **Rule**: Consultation returns accurate time-weighted prices

**Certora Spec Structure**:
```cvl
rule twapRequiresMinimumPeriod(address pair) {
    env e1; env e2;
    require e2.block.timestamp >= e1.block.timestamp + PERIOD;
    
    update(e1, pair);
    update(e2, pair);
    
    assert pairMeasurements[pair].lastUpdateTimestamp == e2.block.timestamp;
}
```

**Dependencies**: Uniswap V2 pair contracts  
**Implementation Notes**: Focus on time-based logic and mathematical precision.

#### 4.2 Oracle Manipulation Resistance
**Priority: Critical**  
**Description**: Verify that the oracle is resistant to price manipulation and maintains data integrity.

**Specifications to Implement**:
- **Rule**: Single-block price manipulation cannot affect TWAP
- **Rule**: Flash loan attacks cannot manipulate TWAP calculations
- **Rule**: Historical price data cannot be altered
- **Rule**: Oracle updates maintain cumulative price consistency

**Certora Spec Structure**:
```cvl
rule flashLoanCannotManipulateTWAP(address pair, uint256 manipulatedPrice) {
    env e1; env e2;
    require e2.block.timestamp == e1.block.timestamp; // Same block
    
    uint256 twapBefore = consult(e1, pair, 1e18, token0);
    // Simulate price manipulation in same block
    uint256 twapAfter = consult(e2, pair, 1e18, token0);
    
    assert twapBefore == twapAfter; // TWAP should be unchanged
}
```

**Dependencies**: Uniswap V2 pair contracts  
**Implementation Notes**: Test various manipulation scenarios and time-based protections.

### 5. Cross-Contract Integration Properties

#### 5.1 Vault-YieldSource Interaction
**Priority: Critical**  
**Description**: Verify that interactions between Vault and YieldSource contracts maintain consistency and fund safety.

**Specifications to Implement**:
- **Rule**: Deposit flow correctly transfers tokens from user to yield source
- **Rule**: Withdrawal flow returns correct amounts to users
- **Rule**: Migration between yield sources preserves user deposits
- **Rule**: Access control prevents unauthorized yield source interactions

**Certora Spec Structure**:
```cvl
rule vaultYieldSourceConsistency() {
    // Multi-contract invariant checking
    assert vault.totalDeposits() == yieldSource.totalDeposited();
}
```

**Dependencies**: Vault, YieldSource contracts  
**Implementation Notes**: Use multi-contract verification features to check cross-contract invariants.

#### 5.2 Oracle-PriceTilter Integration
**Priority: High**  
**Description**: Verify that PriceTilter correctly uses oracle data and maintains pricing consistency.

**Specifications to Implement**:
- **Rule**: PriceTilter uses current oracle prices for calculations
- **Rule**: Oracle updates are triggered correctly during operations
- **Rule**: Price consistency is maintained across operations
- **Rule**: Circular dependencies are avoided

**Certora Spec Structure**:
```cvl
rule priceTilterUsesCorrectOracleData(uint256 ethAmount) {
    env e;
    uint256 oraclePrice = oracle.consult(e, WETH, ethAmount, flaxToken);
    uint256 calculatedValue = priceTilter.calculateFlaxValue(e, ethAmount);
    assert calculatedValue == oraclePrice; // Before tilting adjustments
}
```

**Dependencies**: TWAPOracle, PriceTilter contracts  
**Implementation Notes**: Verify data flow and consistency between oracle and price tilting operations.

### 6. Mathematical Property Verification

#### 6.1 Arithmetic Safety
**Priority: High**  
**Description**: Verify that all mathematical operations are safe from overflow, underflow, and precision loss.

**Specifications to Implement**:
- **Rule**: All multiplication operations check for overflow
- **Rule**: All division operations check for zero divisors
- **Rule**: Percentage calculations maintain precision
- **Rule**: Token amount calculations never result in loss of funds

**Certora Spec Structure**:
```cvl
rule noArithmeticOverflow(uint256 a, uint256 b) {
    uint256 result = safeMul(a, b);
    assert a == 0 || result / a == b; // Overflow check
}
```

**Dependencies**: None  
**Implementation Notes**: Verify SafeMath usage and arithmetic operations throughout contracts.

#### 6.2 Economic Invariants
**Priority: Medium**  
**Description**: Verify that economic relationships and incentive structures are maintained.

**Specifications to Implement**:
- **Rule**: Total value in system equals user deposits plus accumulated rewards
- **Rule**: Price tilting creates positive price pressure on Flax
- **Rule**: Reward distribution maintains proportionality
- **Rule**: Slippage protection maintains minimum return guarantees

**Certora Spec Structure**:
```cvl
invariant totalValueConservation()
    getTotalSystemValue() == getUserDepositsValue() + getAccumulatedRewards()
```

**Dependencies**: All contracts  
**Implementation Notes**: Focus on system-wide economic properties and value conservation.

## Implementation Priorities

1. **Phase 1 (Critical)**: Vault fund safety, access control, and deposit/withdrawal logic
2. **Phase 2 (High)**: Oracle manipulation resistance and YieldSource integration safety  
3. **Phase 3 (Medium)**: Mathematical operations, sFlax burning, and economic invariants
4. **Phase 4 (Low)**: Performance optimizations and edge case handling

## Project Structure

Following Certora's conventions, formal verification files will be organized in the project root:

```
certora/
├── specs/                    # Specification files (.spec)
│   ├── Vault.spec
│   ├── YieldSource.spec
│   ├── PriceTilter.spec
│   ├── TWAPOracle.spec
│   └── Integration.spec
├── harness/                  # Harness contracts for verification
│   ├── VaultHarness.sol
│   ├── YieldSourceHarness.sol
│   └── MockContracts.sol
├── conf/                     # Configuration files
│   ├── Vault.conf
│   ├── YieldSource.conf
│   └── Integration.conf
└── scripts/                  # Verification scripts
    ├── run-all-specs.sh
    └── verify-contract.sh
```

## Verification Environment Setup

Each formal verification test should include:
- **Spec Files**: Located in `certora/specs/` directory
- **Mock Contracts**: For external dependencies (Uniswap, Curve, Convex) in `certora/harness/`
- **Harness Contracts**: To expose internal state for verification in `certora/harness/`
- **Configuration Files**: Certora Prover settings in `certora/conf/`
- **Test Scripts**: Automation scripts in `certora/scripts/`

## Success Criteria

- All critical properties pass formal verification
- No false positives or verification timeouts
- Clear documentation of assumptions and limitations
- Integration with CI/CD pipeline for continuous verification