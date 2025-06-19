
Failures summary:
Failed on CVX_CRV_YieldSource.emergencyWithdraw(address,address):
Assert message: assert weak invariant in post-state - certora/specs/Vault.spec line 78

Invariant breached
Failed on CVX_CRV_YieldSource.emergencyWithdraw(address,address):
Assert message: assert weak invariant in post-state - certora/specs/Vault.spec line 65

Invariant breached
Failed on emergencyWithdrawalDisablesVault:
Assert message: Vault.rebaseMultiplier() == 0 - certora/specs/Vault.spec line 231


Failed on CVX_CRV_YieldSource.claimAndSellForInputToken():
Assert message: assert weak invariant in post-state - certora/specs/Vault.spec line 78

Invariant breached
Failed on sFlaxBurnBoostsRewards:
Assert message: to_mathint(MockERC20.balanceOf(e, e.msg.... - certora/specs/Vault.spec line 273


Failed on CVX_CRV_YieldSource.claimRewards():
Assert message: assert weak invariant in post-state - certora/specs/Vault.spec line 78

Invariant breached
Failed on CVX_CRV_YieldSource.claimRewards():
Assert message: assert weak invariant in post-state - certora/specs/Vault.spec line 65

Invariant breached
Failed on Vault.setEmergencyState(bool):
Assert message: assert weak invariant in post-state - certora/specs/Vault.spec line 78

Invariant breached
Failed on CVX_CRV_YieldSource.withdraw(uint256):
Assert message: assert weak invariant in post-state - certora/specs/Vault.spec line 78

Invariant breached
Failed on withdrawalDecreasesEffectiveBalance:
Assert message: Vault.getEffectiveDeposit(user=e.msg.sen... - certora/specs/Vault.spec line 151


Failed on withdrawalRespectsSurplus:
Assert message: MockERC20.balanceOf(e, e.msg.sender) >= ... - certora/specs/Vault.spec line 178


Failed on CVX_CRV_YieldSource.withdraw(uint256):
Assert message: assert weak invariant in post-state - certora/specs/Vault.spec line 65

Invariant breached
Failed on CVX_CRV_YieldSource.deposit(uint256):
Assert message: assert weak invariant in post-state - certora/specs/Vault.spec line 78

Invariant breached
Failed on CVX_CRV_YieldSource.deposit(uint256):
Assert message: assert weak invariant in post-state - certora/specs/Vault.spec line 65

Invariant breached
Failed on depositIncreasesEffectiveBalance:
Assert message: Vault.getEffectiveDeposit(user=e.msg.sen... - certora/specs/Vault.spec line 122


Failed on CVX_CRV_YieldSource.claimAndSellForInputToken():
Assert message: assert weak invariant in post-state - certora/specs/Vault.spec line 65

Invariant breached
Failed on Vault.claimRewards(uint256):
Assert message: assert weak invariant in post-state - certora/specs/Vault.spec line 78

Invariant breached
Failed on CVX_CRV_YieldSource.claimAndSellForInputToken():
Assert message: vaultBalanceBefore - vaultBalanceAfter <... - certora/specs/Vault.spec line 208


Failed on Vault.claimRewards(uint256):
Assert message: assert weak invariant in post-state - certora/specs/Vault.spec line 65

Invariant breached
Failed on Vault.emergencyWithdrawFromYieldSource(address,address):
Assert message: assert weak invariant in post-state - certora/specs/Vault.spec line 78

Invariant breached
Failed on MockERC20.transfer(address,uint256):
Assert message: vaultBalanceBefore - vaultBalanceAfter <... - certora/specs/Vault.spec line 208


Failed on MockERC20.burn(uint256):
Assert message: vaultBalanceBefore - vaultBalanceAfter <... - certora/specs/Vault.spec line 208


Failed on MockERC20.transferFrom(address,address,uint256):
Assert message: vaultBalanceBefore - vaultBalanceAfter <... - certora/specs/Vault.spec line 208


Failed on CVX_CRV_YieldSource.deposit(uint256):
Assert message: vaultBalanceBefore - vaultBalanceAfter <... - certora/specs/Vault.spec line 208


Failed on CVX_CRV_YieldSource.withdraw(uint256):
Assert message: vaultBalanceBefore - vaultBalanceAfter <... - certora/specs/Vault.spec line 208


Failed on Vault.withdraw(uint256,bool,uint256):
Assert message: assert weak invariant in post-state - certora/specs/Vault.spec line 65

Invariant breached
Failed on CVX_CRV_YieldSource.claimRewards():
Assert message: vaultBalanceBefore - vaultBalanceAfter <... - certora/specs/Vault.spec line 208


Failed on Vault.deposit(uint256):
Assert message: assert weak invariant in post-state - certora/specs/Vault.spec line 78

Invariant breached
Failed on Vault.deposit(uint256):
Assert message: assert weak invariant in post-state - certora/specs/Vault.spec line 65

Invariant breached
Failed on Vault.withdraw(uint256,bool,uint256):
Assert message: assert weak invariant in post-state - certora/specs/Vault.spec line 78

Invariant breached
Failed on onlyOwnerCanMigrate:
Assert message: e.msg.sender == Vault.owner() - certora/specs/Vault.spec line 99


Failed on Vault.claimRewards(uint256):
Assert message: vaultBalanceBefore - vaultBalanceAfter <... - certora/specs/Vault.spec line 208


Failed on Vault.deposit(uint256):
Assert message: vaultBalanceBefore - vaultBalanceAfter <... - certora/specs/Vault.spec line 208


Failed on Vault.migrateYieldSource(address):
Assert message: assert weak invariant in post-state - certora/specs/Vault.spec line 65

Invariant breached
Failed on rebaseMultiplierValid:
Assert message: assert weak invariant in post-state - certora/specs/Vault.spec line 65
Violated for: 
CVX_CRV_YieldSource.withdraw(uint256),
Vault.claimRewards(uint256),
Vault.migrateYieldSource(address),
CVX_CRV_YieldSource.emergencyWithdraw(address,address),
CVX_CRV_YieldSource.deposit(uint256),
Vault.deposit(uint256),
CVX_CRV_YieldSource.claimAndSellForInputToken(),
CVX_CRV_YieldSource.claimRewards(),
Vault.withdraw(uint256,bool,uint256)

Failed on Vault.withdraw(uint256,bool,uint256):
Assert message: vaultBalanceBefore - vaultBalanceAfter <... - certora/specs/Vault.spec line 208


Failed on Vault.migrateYieldSource(address):
Assert message: assert weak invariant in post-state - certora/specs/Vault.spec line 78

Invariant breached
Failed on vaultStateConsistency:
Assert message: assert weak invariant in post-state - certora/specs/Vault.spec line 78
Violated for: 
Vault.deposit(uint256),
Vault.migrateYieldSource(address),
CVX_CRV_YieldSource.claimAndSellForInputToken(),
CVX_CRV_YieldSource.claimRewards(),
Vault.withdraw(uint256,bool,uint256),
Vault.claimRewards(uint256),
Vault.setEmergencyState(bool),
CVX_CRV_YieldSource.emergencyWithdraw(address,address),
Vault.emergencyWithdrawFromYieldSource(address,address),
CVX_CRV_YieldSource.deposit(uint256),
CVX_CRV_YieldSource.withdraw(uint256)

Failed on userCannotDepositForOthers:
Assert message: Vault.getEffectiveDeposit(user=otherUser... - certora/specs/Vault.spec line 324


Failed on Vault.migrateYieldSource(address):
Assert message: vaultBalanceBefore - vaultBalanceAfter <... - certora/specs/Vault.spec line 208


Failed on noUnauthorizedTokenOutflows:
Assert message: vaultBalanceBefore - vaultBalanceAfter <... - certora/specs/Vault.spec line 208
Violated for: 
CVX_CRV_YieldSource.claimRewards(),
CVX_CRV_YieldSource.deposit(uint256),
MockERC20.transferFrom(address,address,uint256),
MockERC20.burn(uint256),
MockERC20.transfer(address,uint256),
Vault.claimRewards(uint256),
CVX_CRV_YieldSource.claimAndSellForInputToken(),
CVX_CRV_YieldSource.withdraw(uint256),
Vault.deposit(uint256),
Vault.migrateYieldSource(address),
Vault.withdraw(uint256,bool,uint256)

Failed on withdrawalCannotAffectOthers:
Assert message: Vault.getEffectiveDeposit(user=otherUser... - certora/specs/Vault.spec line 339



[ForkJoinPool-1-worker-25] WARN TREEVIEW_REPORTER - Could not find a tree view node for TREE_VIEW_ROOT_NODE - there is a call to addChildNode missing.
Duration 581359, RuleCheckResultsStats: numTotal = 19; numVerified = 8; numViolated = 11; numTimeout = 0; numError = 0
Done 9m
Done 9m
Event reporter: all events were sent without errors
