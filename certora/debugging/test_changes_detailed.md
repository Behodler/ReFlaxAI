# Detailed Test Changes for Rebase Multiplier Implementation

## Unit Test Changes

### New Test Files Needed

#### 1. `test/unit/vault/VaultRebaseMultiplier.t.sol`
```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BaseVaultTest} from "./BaseVaultTest.sol";

contract VaultRebaseMultiplierTest is BaseVaultTest {
    
    function testRebaseMultiplierStartsAtOne() public {
        assertEq(vault.rebaseMultiplier(), 1e18);
    }
    
    function testGetEffectiveDepositWithNormalRebase() public {
        uint256 depositAmount = 1000e18;
        _deposit(user1, depositAmount);
        
        assertEq(vault.getEffectiveDeposit(user1), depositAmount);
        assertEq(vault.originalDeposits(user1), depositAmount);
    }
    
    function testGetEffectiveTotalDepositsWithNormalRebase() public {
        uint256 deposit1 = 1000e18;
        uint256 deposit2 = 500e18;
        
        _deposit(user1, deposit1);
        _deposit(user2, deposit2);
        
        assertEq(vault.getEffectiveTotalDeposits(), deposit1 + deposit2);
        assertEq(vault.totalDeposits(), deposit1 + deposit2);
    }
    
    function testEmergencyWithdrawalSetsRebaseToZero() public {
        uint256 depositAmount = 1000e18;
        _deposit(user1, depositAmount);
        
        vm.prank(owner);
        vault.setEmergencyState(true);
        
        vm.prank(owner);
        vault.emergencyWithdrawFromYieldSource(address(usdc), owner);
        
        assertEq(vault.rebaseMultiplier(), 0);
    }
    
    function testEffectiveDepositsZeroAfterEmergencyWithdrawal() public {
        uint256 depositAmount = 1000e18;
        _deposit(user1, depositAmount);
        _deposit(user2, 500e18);
        
        // Trigger emergency withdrawal
        vm.prank(owner);
        vault.setEmergencyState(true);
        
        vm.prank(owner);
        vault.emergencyWithdrawFromYieldSource(address(usdc), owner);
        
        // All effective deposits should be zero
        assertEq(vault.getEffectiveDeposit(user1), 0);
        assertEq(vault.getEffectiveDeposit(user2), 0);
        assertEq(vault.getEffectiveTotalDeposits(), 0);
        
        // But original deposits remain
        assertEq(vault.originalDeposits(user1), depositAmount);
        assertEq(vault.originalDeposits(user2), 500e18);
    }
    
    function testVaultPermanentlyDisabledAfterEmergency() public {
        uint256 depositAmount = 1000e18;
        _deposit(user1, depositAmount);
        
        vm.prank(owner);
        vault.setEmergencyState(true);
        
        vm.prank(owner);
        vault.emergencyWithdrawFromYieldSource(address(usdc), owner);
        
        // All operations should fail
        vm.expectRevert("Vault permanently disabled");
        _deposit(user1, 100e18);
        
        vm.prank(user1);
        vm.expectRevert("Vault permanently disabled");
        vault.withdraw(100e18, false, 0);
        
        vm.prank(user1);
        vm.expectRevert("Vault permanently disabled");
        vault.claimRewards(0);
        
        vm.prank(owner);
        vm.expectRevert("Vault permanently disabled");
        vault.migrateYieldSource(address(0x123));
    }
    
    function testCannotDepositWhenRebaseIsZero() public {
        // Trigger emergency withdrawal first
        vm.prank(owner);
        vault.setEmergencyState(true);
        
        vm.prank(owner);
        vault.emergencyWithdrawFromYieldSource(address(usdc), owner);
        
        vm.expectRevert("Vault permanently disabled");
        _deposit(user1, 100e18);
    }
}
```

### Modifications to Existing Unit Tests

#### 2. `test/unit/vault/VaultDeposit.t.sol`
```solidity
// Add these test cases to existing file:

function testDepositUpdatesEffectiveBalance() public {
    uint256 depositAmount = 1000e18;
    
    uint256 effectiveBefore = vault.getEffectiveDeposit(user1);
    uint256 effectiveTotalBefore = vault.getEffectiveTotalDeposits();
    
    _deposit(user1, depositAmount);
    
    assertEq(vault.getEffectiveDeposit(user1), effectiveBefore + depositAmount);
    assertEq(vault.getEffectiveTotalDeposits(), effectiveTotalBefore + depositAmount);
}

function testDepositFailsWhenVaultDisabled() public {
    // Disable vault first
    vm.prank(owner);
    vault.setEmergencyState(true);
    
    vm.prank(owner);
    vault.emergencyWithdrawFromYieldSource(address(usdc), owner);
    
    vm.expectRevert("Vault permanently disabled");
    _deposit(user1, 100e18);
}

// Update existing tests to use getEffectiveDeposit where appropriate
```

#### 3. `test/unit/vault/VaultWithdraw.t.sol`
```solidity
// Add these test cases and update existing ones:

function testWithdrawUsesEffectiveBalance() public {
    uint256 depositAmount = 1000e18;
    _deposit(user1, depositAmount);
    
    uint256 withdrawAmount = 500e18;
    
    vm.prank(user1);
    vault.withdraw(withdrawAmount, false, 0);
    
    assertEq(vault.getEffectiveDeposit(user1), depositAmount - withdrawAmount);
}

function testWithdrawFailsWhenVaultDisabled() public {
    uint256 depositAmount = 1000e18;
    _deposit(user1, depositAmount);
    
    // Disable vault
    vm.prank(owner);
    vault.setEmergencyState(true);
    
    vm.prank(owner);
    vault.emergencyWithdrawFromYieldSource(address(usdc), owner);
    
    vm.prank(user1);
    vm.expectRevert("Vault permanently disabled");
    vault.withdraw(100e18, false, 0);
}

function testWithdrawFailsWhenEffectiveBalanceInsufficient() public {
    uint256 depositAmount = 1000e18;
    _deposit(user1, depositAmount);
    
    // Try to withdraw more than effective balance
    vm.prank(user1);
    vm.expectRevert("Insufficient effective deposit");
    vault.withdraw(depositAmount + 1, false, 0);
}

// Update all existing withdrawal tests to use getEffectiveDeposit
```

#### 4. `test/unit/vault/VaultEmergency.t.sol` (New file)
```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BaseVaultTest} from "./BaseVaultTest.sol";

contract VaultEmergencyTest is BaseVaultTest {
    
    function testEmergencyWithdrawalFromYieldSourceRequiresEmergencyState() public {
        vm.prank(owner);
        vm.expectRevert("Not in emergency state");
        vault.emergencyWithdrawFromYieldSource(address(usdc), owner);
    }
    
    function testEmergencyWithdrawalFromYieldSourceOnlyOwner() public {
        vm.prank(owner);
        vault.setEmergencyState(true);
        
        vm.prank(user1);
        vm.expectRevert("Ownable: caller is not the owner");
        vault.emergencyWithdrawFromYieldSource(address(usdc), owner);
    }
    
    function testEmergencyWithdrawalResetsRebaseMultiplier() public {
        uint256 depositAmount = 1000e18;
        _deposit(user1, depositAmount);
        
        assertEq(vault.rebaseMultiplier(), 1e18);
        
        vm.prank(owner);
        vault.setEmergencyState(true);
        
        vm.prank(owner);
        vault.emergencyWithdrawFromYieldSource(address(usdc), owner);
        
        assertEq(vault.rebaseMultiplier(), 0);
    }
    
    function testEmergencyWithdrawalWithNonInputToken() public {
        vm.prank(owner);
        vault.setEmergencyState(true);
        
        // Should not reset rebase multiplier for non-input tokens
        uint256 rebaseBefore = vault.rebaseMultiplier();
        
        vm.prank(owner);
        vault.emergencyWithdrawFromYieldSource(address(flax), owner);
        
        assertEq(vault.rebaseMultiplier(), rebaseBefore);
    }
    
    function testEmergencyStatePreventsCoreOperations() public {
        vm.prank(owner);
        vault.setEmergencyState(true);
        
        vm.expectRevert("Emergency state active");
        _deposit(user1, 100e18);
        
        vm.prank(user1);
        vm.expectRevert("Emergency state active");
        vault.claimRewards(0);
        
        vm.prank(owner);
        vm.expectRevert("Emergency state active");
        vault.migrateYieldSource(address(0x123));
    }
}
```

## Integration Test Changes

#### 5. `test/integration/EmergencyRebaseIntegration.t.sol` (New file)
```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BaseIntegrationTest} from "./BaseIntegrationTest.sol";

contract EmergencyRebaseIntegrationTest is BaseIntegrationTest {
    
    function testFullEmergencyFlowWithMultipleUsers() public {
        // Setup: Multiple users deposit
        uint256 deposit1 = 1000e6; // USDC has 6 decimals
        uint256 deposit2 = 500e6;
        uint256 deposit3 = 2000e6;
        
        _deposit(user1, deposit1);
        _deposit(user2, deposit2);
        _deposit(user3, deposit3);
        
        uint256 totalBefore = vault.getEffectiveTotalDeposits();
        assertEq(totalBefore, deposit1 + deposit2 + deposit3);
        
        // Verify yield source has received funds
        assertTrue(usdc.balanceOf(address(yieldSource)) > 0);
        
        // Trigger emergency withdrawal
        vm.prank(owner);
        vault.setEmergencyState(true);
        
        vm.prank(owner);
        vault.emergencyWithdrawFromYieldSource(address(usdc), owner);
        
        // Verify all effective deposits are zero
        assertEq(vault.getEffectiveDeposit(user1), 0);
        assertEq(vault.getEffectiveDeposit(user2), 0);
        assertEq(vault.getEffectiveDeposit(user3), 0);
        assertEq(vault.getEffectiveTotalDeposits(), 0);
        
        // Verify original deposits remain
        assertEq(vault.originalDeposits(user1), deposit1);
        assertEq(vault.originalDeposits(user2), deposit2);
        assertEq(vault.originalDeposits(user3), deposit3);
        
        // Verify vault is permanently disabled
        assertEq(vault.rebaseMultiplier(), 0);
        
        // Verify no further operations are possible
        vm.expectRevert("Vault permanently disabled");
        _deposit(user1, 100e6);
        
        vm.prank(user1);
        vm.expectRevert("Vault permanently disabled");
        vault.withdraw(100e6, false, 0);
        
        // Verify owner recovered funds
        assertTrue(usdc.balanceOf(owner) > 0);
    }
    
    function testYieldSourceInteractionAfterEmergency() public {
        uint256 depositAmount = 1000e6;
        _deposit(user1, depositAmount);
        
        // Verify yield source has funds
        uint256 yieldSourceBalanceBefore = usdc.balanceOf(address(yieldSource));
        assertTrue(yieldSourceBalanceBefore > 0);
        
        // Trigger emergency withdrawal
        vm.prank(owner);
        vault.setEmergencyState(true);
        
        vm.prank(owner);
        vault.emergencyWithdrawFromYieldSource(address(usdc), owner);
        
        // Verify yield source funds were withdrawn
        uint256 yieldSourceBalanceAfter = usdc.balanceOf(address(yieldSource));
        assertLt(yieldSourceBalanceAfter, yieldSourceBalanceBefore);
        
        // Verify vault cannot interact with yield source anymore
        vm.prank(owner);
        vm.expectRevert("Vault permanently disabled");
        vault.migrateYieldSource(address(0x123));
    }
    
    function testEmergencyWithdrawalPreservesAccountingHistory() public {
        uint256 deposit1 = 1000e6;
        uint256 deposit2 = 500e6;
        
        _deposit(user1, deposit1);
        _deposit(user2, deposit2);
        
        // Partial withdrawal before emergency
        vm.prank(user1);
        vault.withdraw(200e6, false, 0);
        
        uint256 user1OriginalBefore = vault.originalDeposits(user1);
        uint256 user2OriginalBefore = vault.originalDeposits(user2);
        uint256 totalDepositsBefore = vault.totalDeposits();
        
        // Trigger emergency withdrawal
        vm.prank(owner);
        vault.setEmergencyState(true);
        
        vm.prank(owner);
        vault.emergencyWithdrawFromYieldSource(address(usdc), owner);
        
        // Original deposits should remain unchanged
        assertEq(vault.originalDeposits(user1), user1OriginalBefore);
        assertEq(vault.originalDeposits(user2), user2OriginalBefore);
        assertEq(vault.totalDeposits(), totalDepositsBefore);
        
        // Only effective deposits should be zero
        assertEq(vault.getEffectiveDeposit(user1), 0);
        assertEq(vault.getEffectiveDeposit(user2), 0);
        assertEq(vault.getEffectiveTotalDeposits(), 0);
    }
}
```

#### 6. Updates to Existing Integration Tests

```solidity
// In existing integration test files, update assertions like:

// OLD:
assertEq(vault.originalDeposits(user), expectedAmount);

// NEW:
assertEq(vault.getEffectiveDeposit(user), expectedAmount);
assertEq(vault.originalDeposits(user), expectedRawAmount);

// Add checks for vault state:
assertTrue(vault.rebaseMultiplier() > 0); // Vault is operational

// In multi-user scenarios, verify isolation:
// After user1 operations, user2's effective deposit should be unchanged
assertEq(vault.getEffectiveDeposit(user2), user2ExpectedDeposit);
```

## Test Helper Updates

#### 7. Update `BaseVaultTest.sol` and `BaseIntegrationTest.sol`

```solidity
// Add helper functions:

function _getEffectiveDepositSum(address[] memory users) internal view returns (uint256) {
    uint256 sum = 0;
    for (uint256 i = 0; i < users.length; i++) {
        sum += vault.getEffectiveDeposit(users[i]);
    }
    return sum;
}

function _assertVaultNotDisabled() internal {
    assertTrue(vault.rebaseMultiplier() > 0, "Vault should not be disabled");
}

function _assertVaultDisabled() internal {
    assertEq(vault.rebaseMultiplier(), 0, "Vault should be disabled");
}

function _triggerEmergencyDisable() internal {
    vm.prank(owner);
    vault.setEmergencyState(true);
    
    vm.prank(owner);
    vault.emergencyWithdrawFromYieldSource(address(usdc), owner);
    
    _assertVaultDisabled();
}
```

## Summary of Changes Required

### Critical Test Updates:
1. **Replace `originalDeposits` checks with `getEffectiveDeposit`** in user-facing scenarios
2. **Add rebase multiplier state checks** to all relevant tests
3. **Add permanent disable functionality tests** for all core operations
4. **Create comprehensive emergency withdrawal test scenarios**
5. **Update multi-user tests** to verify proper isolation

### Test Coverage Goals:
- ✅ Rebase multiplier starts at 1e18
- ✅ Effective deposits calculated correctly
- ✅ Emergency withdrawal sets rebase to 0
- ✅ Vault permanently disabled after emergency
- ✅ All operations fail when disabled
- ✅ Multi-user scenarios work correctly
- ✅ Accounting history preserved after emergency
- ✅ Yield source interaction disabled after emergency