# Formal Verification Specification for ReFlax Protocol

## Overview

This document outlines the formal verification requirements for the ReFlax protocol, a yield optimization system that allows users to deposit tokens into yield sources and earn Flax rewards. The verification will focus on ensuring the safety of user funds, correctness of mathematical operations, and integrity of state transitions.

## Scope

The formal verification covers five main contracts:
1. **Vault.sol** - User-facing vault managing deposits and rewards
2. **AYieldSource.sol** - Abstract base for yield sources
3. **CVX_CRV_YieldSource.sol** - Concrete Convex/Curve implementation
4. **PriceTilterTWAP.sol** - Price tilting mechanism
5. **TWAPOracle.sol** - Time-weighted average price oracle

## 1. Vault Contract Verification

### 1.1 State Variable Invariants

```solidity
// Core accounting invariants
invariant totalDepositsIntegrity() {
    sum(originalDeposits[user] for all users) == totalDeposits
}

invariant noTokenRetention() {
    inputToken.balanceOf(vault) == surplusInputToken
}

invariant emergencyStateConsistency() {
    emergencyState => no new deposits, claims, or migrations allowed
}
```

### 1.2 Function-Specific Properties

#### deposit()
- **Pre-conditions:**
  - `amount > 0`
  - `!emergencyState`
  - User has sufficient balance and allowance
- **Post-conditions:**
  - `originalDeposits[msg.sender]` increased by `amount`
  - `totalDeposits` increased by `amount`
  - Tokens transferred to YieldSource
  - No tokens retained in vault

#### withdraw()
- **Pre-conditions:**
  - `originalDeposits[msg.sender] >= amount`
  - `canWithdraw() == true`
- **Post-conditions:**
  - `originalDeposits[msg.sender]` decreased by `amount`
  - `totalDeposits` decreased by `amount`
  - User receives at least `min(amount, received + surplus)` tokens
  - If `protectLoss == true` and shortfall > surplus, transaction reverts
  - Surplus updated correctly

#### claimRewards()
- **Pre-conditions:**
  - `!emergencyState`
- **Post-conditions:**
  - User receives correct Flax amount based on YieldSource return
  - If sFlax burned: `flaxReceived = baseFlax + (sFlaxAmount * flaxPerSFlax / 1e18)`
  - sFlax tokens properly burned

#### migrateYieldSource()
- **Pre-conditions:**
  - Only owner can call
  - `!emergencyState`
- **Post-conditions:**
  - All funds withdrawn from old YieldSource
  - All funds deposited to new YieldSource
  - `yieldSource` updated
  - Any losses absorbed by surplus

### 1.3 Access Control Properties

```solidity
invariant ownerOnly() {
    setFlaxPerSFlax, migrateYieldSource, setEmergencyState, emergencyWithdraw* 
    can only be called by owner
}

invariant emergencyWithdrawalSafety() {
    emergencyWithdrawFromYieldSource requires emergencyState == true
}
```

## 2. YieldSource Contracts Verification

### 2.1 AYieldSource Base Contract

#### State Invariants
```solidity
invariant whitelistEnforcement() {
    deposit, withdraw, claimRewards, claimAndSellForInputToken 
    can only be called by whitelisted vaults
}

invariant slippageBounds() {
    0 <= minSlippageBps <= 10000
}
```

#### Oracle Update Properties
- Oracle must be updated at the start of deposit(), withdraw(), and claimRewards()
- Update includes all relevant token pairs (input, pool tokens, reward tokens)

### 2.2 CVX_CRV_YieldSource Implementation

#### Complex Flow Verification

**Deposit Flow:**
1. Input token allocation based on weights
2. Token swaps respect TWAP slippage bounds
3. Liquidity addition to Curve pool
4. LP token staking in Convex
5. `totalDeposited` accurately tracks LP tokens

**Withdrawal Flow:**
1. LP tokens unstaked from Convex
2. Liquidity removed from Curve
3. Conversion back to input token
4. Reward claiming and conversion

#### Mathematical Properties
```solidity
invariant weightSum() {
    sum(underlyingWeights[pool]) == 10000 || weights unset
}

invariant slippageProtection() {
    for all swaps: outputAmount >= TWAPPrice * (10000 - minSlippageBps) / 10000
}
```

## 3. PriceTilterTWAP Verification

### 3.1 Core Properties

```solidity
invariant priceTiltBounds() {
    0 <= priceTiltRatio <= 10000
}

invariant flaxCalculation() {
    flaxValue == (ethAmount * 1e18) / ethPerFlax
    where ethPerFlax = oracle.consult(flax, weth, 1e18)
}

invariant liquidityAddition() {
    flaxAmount == (flaxValue * priceTiltRatio) / 10000
    all ETH in contract used for liquidity
}
```

### 3.2 Security Properties
- Only registered pairs can be used for price tilting
- Contract must have sufficient Flax balance
- ETH amount must match msg.value
- No ETH retained after liquidity addition

## 4. TWAPOracle Verification

### 4.1 Time-Based Properties

```solidity
invariant updatePeriod() {
    price update only occurs if timeElapsed >= PERIOD (1 hour)
}

invariant cumulativePriceMonotonicity() {
    currentPrice0Cumulative >= lastPrice0Cumulative
    currentPrice1Cumulative >= lastPrice1Cumulative
}
```

### 4.2 TWAP Calculation Correctness

```solidity
invariant twapFormula() {
    price0Average = (price0Cumulative_new - price0Cumulative_old) / timeElapsed
    price1Average = (price1Cumulative_new - price1Cumulative_old) / timeElapsed
}

invariant consultAccuracy() {
    consult(tokenA, tokenB, amount) returns amount * TWAP_price
}
```

## 5. Cross-Contract Properties

### 5.1 Token Flow Integrity

```solidity
invariant depositFlow() {
    User -> Vault -> YieldSource -> External Protocol
    No intermediate token retention
}

invariant withdrawalFlow() {
    External Protocol -> YieldSource -> Vault -> User
    Losses properly handled through surplus mechanism
}
```

### 5.2 Access Control Chain

```solidity
invariant accessHierarchy() {
    Owner -> Vault configuration
    Vault -> YieldSource (only if whitelisted)
    No direct user access to YieldSource
}
```

### 5.3 Emergency Procedures

```solidity
invariant emergencyConsistency() {
    All contracts have emergency withdrawal
    Only owner can trigger emergency functions
    Emergency state prevents normal operations
}
```

## 6. Security Properties

### 6.1 Reentrancy Protection
- All external-facing functions use ReentrancyGuard
- State changes before external calls

### 6.2 Integer Overflow/Underflow
- All arithmetic operations checked for overflow
- Proper scaling for decimal conversions

### 6.3 Front-Running Protection
- TWAP provides resistance to price manipulation
- Slippage bounds prevent sandwich attacks

## 7. Liveness Properties

### 7.1 User Withdrawal Guarantee
```solidity
property withdrawalAvailability() {
    User can always withdraw their share of funds
    (minus legitimate protocol losses)
}
```

### 7.2 Reward Distribution
```solidity
property rewardFairness() {
    Rewards distributed proportionally to contribution
    No reward tokens locked in contracts
}
```

## 8. Gas and Economic Properties

### 8.1 Gas Optimization Verification
- Batch operations where possible
- Efficient storage patterns
- Minimal external calls

### 8.2 Economic Invariants
- Price tilting increases Flax value as intended
- No economic exploits through repeated operations

## 9. Formal Verification Tools Recommendations

1. **Certora Prover** - For complex invariants and cross-contract properties
2. **SMTChecker** - For arithmetic overflow/underflow
3. **Echidna/Medusa** - For fuzz testing edge cases
4. **Halmos** - For symbolic execution of critical paths

## 10. Priority Verification Order

1. **High Priority**
   - User fund safety (deposits/withdrawals)
   - Access control enforcement
   - Mathematical correctness

2. **Medium Priority**
   - TWAP oracle accuracy
   - Slippage protection
   - Emergency procedures

3. **Lower Priority**
   - Gas optimizations
   - Event emissions
   - View function correctness

## Conclusion

This specification provides a comprehensive framework for formally verifying the ReFlax protocol. The verification should ensure that user funds are safe, mathematical operations are correct, and the system behaves as intended under all conditions including edge cases and adversarial scenarios.