# Certora Invariant Failure Analysis

## Critical Invariant Failures

### 1. totalDepositsIntegrity (line 57)
**Issue**: The invariant expects `totalDeposits` to equal the sum of all `originalDeposits[user]`.

**Root Cause**: 
- `emergencyWithdrawFromYieldSource` sets `totalDeposits = 0` without updating individual user deposits
- This creates a mismatch where sum(originalDeposits) > 0 but totalDeposits = 0

**Failed Functions**:
- CVX_CRV_YieldSource.emergencyWithdraw
- CVX_CRV_YieldSource.claimAndSellForInputToken
- CVX_CRV_YieldSource.claimRewards
- CVX_CRV_YieldSource.deposit
- CVX_CRV_YieldSource.withdraw
- Vault.emergencyWithdraw
- Vault.emergencyWithdrawETH
- Vault.emergencyWithdrawFromYieldSource
- Vault.claimRewards
- Vault.withdraw
- Vault.migrateYieldSource

### 2. noTokenRetention (line 61)
**Issue**: The invariant expects vault to only hold `surplusInputToken` amount of input tokens.

**Root Cause**:
- Emergency functions can withdraw tokens without updating `surplusInputToken`
- Functions may receive tokens directly (e.g., via transfer) breaking the invariant
- Mock ERC20 functions (mint, transfer, burn) can change balances externally

**Failed Functions**:
- All Vault functions that handle tokens
- All YieldSource functions
- MockERC20 functions (mint, transfer, burn, transferFrom)

## Rule Failures Analysis

### 3. sFlaxBurnBoostsRewards (line 197)
**Issue**: Assert fails on balance check after claiming rewards
**Root Cause**: The rule expects user to receive at least the boost amount, but the actual implementation might have rounding differences or the flax balance might not be sufficient

### 4. withdrawalDecreasesUserBalance (line 151)
**Issue**: Assert fails on user deposit check
**Root Cause**: The rule doesn't account for emergency state or other edge cases

### 5. depositTransfersToYieldSource (line 132)
**Issue**: Vault balance assertion fails
**Root Cause**: The vault might temporarily hold tokens during the deposit process

### 6. depositIncreasesUserBalance (line 117)
**Issue**: User deposit increase assertion fails
**Root Cause**: The deposit might fail or be prevented by emergency state

### 7. migrationPreservesFunds (line 217)
**Issue**: Total deposits assertion fails
**Root Cause**: Migration can result in losses that aren't properly tracked

### 8. withdrawalRespectsSurplus (line 176)
**Issue**: User balance assertion fails
**Root Cause**: The withdrawal logic might not properly handle all cases

### 9. userCannotDepositForOthers (line 269)
**Issue**: Other user's deposit assertion fails
**Root Cause**: The rule logic might be incorrect

### 10. withdrawalCannotAffectOthers (line 283)
**Issue**: Other user's balance assertion fails
**Root Cause**: The rule doesn't properly isolate user actions

### 11. onlyOwnerCanMigrate (line 96)
**Issue**: Owner check assertion fails
**Root Cause**: The rule might not properly check the owner requirement

## Recommendations

1. **Fix Emergency Functions**: Emergency functions should either:
   - Not modify `totalDeposits` directly, OR
   - Update the invariant to exclude emergency state scenarios

2. **Fix Token Retention**: 
   - Add checks to prevent direct token transfers
   - Update invariant to account for temporary holding during operations

3. **Fix Rule Logic**:
   - Add proper preconditions for emergency state
   - Account for rounding and edge cases
   - Properly isolate user actions in multi-user rules