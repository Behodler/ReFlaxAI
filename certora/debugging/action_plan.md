# Action Plan for Certora Verification Fixes

## 1. Clarification: Vault.spec vs Vault_fixed.spec
**Answer**: Yes, `Vault_fixed.spec` is intended to replace `Vault.spec`. The "_fixed" suffix was just for clarity during development. The final action will be to update the original `Vault.spec` with the fixes.

## 2. Contract Changes

### A. Implement Rebase Multiplier for Emergency Withdrawals

**Vault.sol changes:**

```solidity
contract Vault is Ownable, ReentrancyGuard {
    // Add new state variable
    uint256 public rebaseMultiplier = 1e18; // 18 decimals, starts at 1.0
    
    // Modify getter functions to apply rebase
    function getEffectiveDeposit(address user) public view returns (uint256) {
        return (originalDeposits[user] * rebaseMultiplier) / 1e18;
    }
    
    function getEffectiveTotalDeposits() public view returns (uint256) {
        return (totalDeposits * rebaseMultiplier) / 1e18;
    }
    
    // Update withdraw function to use effective deposits
    function withdraw(uint256 amount, bool protectLoss, uint256 sFlaxAmount) external nonReentrant {
        require(canWithdraw(), "Withdrawal not allowed");
        require(getEffectiveDeposit(msg.sender) >= amount, "Insufficient deposit");
        // ... rest of function
    }
    
    // Update emergencyWithdrawFromYieldSource
    function emergencyWithdrawFromYieldSource(address token, address recipient) external onlyOwner {
        require(emergencyState, "Not in emergency state");
        
        // First withdraw all funds from yield source if it's the input token
        if (token == address(inputToken) && totalDeposits > 0) {
            (uint256 received, ) = IYieldsSource(yieldSource).withdraw(totalDeposits);
            // Set rebase multiplier to 0 instead of totalDeposits = 0
            rebaseMultiplier = 0;
            surplusInputToken += received;
        }
        
        // ... rest of function
    }
}
```

### B. Add Permanent Disable After Emergency

```solidity
// Add modifier to prevent operations after emergency withdrawal
modifier notPermanentlyDisabled() {
    require(rebaseMultiplier > 0, "Vault permanently disabled");
    _;
}

// Apply to deposit, withdraw, claimRewards, migrateYieldSource
function deposit(uint256 amount) external nonReentrant notInEmergencyState notPermanentlyDisabled {
    // ...
}
```

## 3. Specification Updates

### A. Update Original Vault.spec

```solidity
// Core Invariants - Updated for rebase multiplier
invariant totalDepositsIntegrity()
    rebaseMultiplier > 0 => to_mathint(getEffectiveTotalDeposits()) == 
    sum(address user => to_mathint(getEffectiveDeposit(user)));

// Token retention - Focus only on outflows
invariant noInappropriateTokenOutflows(env e)
    // After any function call, vault balance should not decrease more than expected
    // This will be implemented as rules rather than invariant for better control
```

### B. New Rules for Token Outflow Protection

```solidity
// Ensure no tokens leave vault inappropriately
rule noUnexpectedTokenOutflows(env e, method f) {
    require f.selector != sig:emergencyWithdraw(address,address).selector;
    require f.selector != sig:emergencyWithdrawETH(address).selector;
    
    uint256 vaultBalanceBefore = inputToken.balanceOf(e, currentContract);
    uint256 surplusBefore = surplusInputToken();
    
    calldataarg args;
    f(e, args);
    
    uint256 vaultBalanceAfter = inputToken.balanceOf(e, currentContract);
    
    // Vault balance should only decrease by surplus reduction or user withdrawals
    assert vaultBalanceAfter >= vaultBalanceBefore - (surplusBefore - surplusInputToken());
}
```

## 4. Test Updates

### A. Unit Test Changes

**New test cases needed:**

1. **RebaseMultiplierTest.t.sol**
```solidity
function testRebaseMultiplierStartsAtOne()
function testDepositWithRebaseMultiplier()
function testWithdrawWithRebaseMultiplier()
function testEmergencyWithdrawalSetsRebaseToZero()
function testVaultPermanentlyDisabledAfterEmergency()
function testCannotDepositWhenRebaseIsZero()
function testCannotWithdrawWhenRebaseIsZero()
function testEffectiveDepositsCalculation()
```

2. **Update existing tests:**
- `VaultDeposit.t.sol`: Update deposit assertions to check effective deposits
- `VaultWithdraw.t.sol`: Update to use getEffectiveDeposit()
- `VaultEmergency.t.sol`: Add tests for rebase multiplier behavior

### B. Integration Test Changes

**New integration tests:**

1. **EmergencyRebaseIntegration.t.sol**
```solidity
function testFullEmergencyFlowWithRebase() {
    // 1. Multiple users deposit
    // 2. Trigger emergency withdrawal
    // 3. Verify all user deposits show as 0
    // 4. Verify vault is permanently disabled
    // 5. Verify no further operations possible
}

function testYieldSourceInteractionAfterEmergency() {
    // Verify yield source is properly disconnected after emergency
}
```

2. **Update existing integration tests:**
- Add assertions for rebase multiplier state
- Update balance checks to use effective deposits

## 5. Implementation Order

### Phase 1: Contract Updates (Priority: High)
1. Add rebase multiplier to Vault.sol
2. Update all deposit/withdrawal logic to use effective amounts
3. Implement permanent disable mechanism
4. Update emergency withdrawal function

### Phase 2: Specification Reconciliation (Priority: High)
1. Merge Vault_fixed.spec improvements into Vault.spec
2. Add rebase multiplier support to specifications
3. Replace token retention invariant with outflow protection rules
4. Add new rules for permanent disable state

### Phase 3: Test Updates (Priority: Medium)
1. Create new unit tests for rebase functionality
2. Update existing unit tests for new getters
3. Create integration tests for emergency scenarios
4. Update existing integration tests

### Phase 4: Verification (Priority: High)
1. Run preflight checks on updated spec
2. Run full Certora verification
3. Address any new issues
4. Document final results

## 6. Files to Modify

### Contracts:
- `src/vault/Vault.sol` - Add rebase multiplier logic

### Specifications:
- `certora/specs/Vault.spec` - Update with fixes and rebase support
- Delete `certora/specs/Vault_fixed.spec` after merging

### Tests:
- `test/unit/vault/VaultDeposit.t.sol`
- `test/unit/vault/VaultWithdraw.t.sol`
- `test/unit/vault/VaultEmergency.t.sol` (new)
- `test/integration/EmergencyRebaseIntegration.t.sol` (new)

## 7. Additional Considerations

1. **Migration Path**: Since emergency withdrawal makes vault unusable, consider documenting deployment of new vault instance as recovery mechanism

2. **Event Updates**: Add events for rebase multiplier changes

3. **Gas Optimization**: The rebase calculation adds minimal gas overhead but provides clean emergency handling

4. **Documentation**: Update NatSpec comments to explain rebase multiplier concept