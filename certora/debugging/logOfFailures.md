ailures summary:
Failed on CVX_CRV_YieldSource.emergencyWithdraw(address,address):
Assert message: assert weak invariant in post-state - certora/specs/Vault.spec line 58

Invariant breached
Failed on CVX_CRV_YieldSource.claimAndSellForInputToken():
Assert message: assert weak invariant in post-state - certora/specs/Vault.spec line 58

Invariant breached
Failed on emergencyWithdrawalDisablesVault:
Assert message: Vault.rebaseMultiplier() == 0 - certora/specs/Vault.spec line 246


Failed on sFlaxBurnBoostsRewards:
Assert message: flaxIncrease >= expectedBoost - certora/specs/Vault.spec line 290


Failed on CVX_CRV_YieldSource.claimRewards():
Assert message: assert weak invariant in post-state - certora/specs/Vault.spec line 58

Invariant breached
Failed on CVX_CRV_YieldSource.withdraw(uint256):
Assert message: assert weak invariant in post-state - certora/specs/Vault.spec line 58

Invariant breached
Failed on CVX_CRV_YieldSource.deposit(uint256):
Assert message: assert weak invariant in post-state - certora/specs/Vault.spec line 58

Invariant breached
Failed on withdrawalCannotAffectOthers:
Assert message: Vault.originalDeposits(otherUser) == oth... - certora/specs/Vault.spec line 358


Failed on withdrawalDecreasesEffectiveBalance:
Assert message: Vault.getEffectiveDeposit(user=e.msg.sen... - certora/specs/Vault.spec line 149


Failed on withdrawalRespectsSurplus:
Assert message: MockERC20.balanceOf(e, e.msg.sender) > u... - certora/specs/Vault.spec line 176


Failed on userCannotDepositForOthers:
Assert message: Vault.originalDeposits(otherUser) == oth... - certora/specs/Vault.spec line 342


Failed on CVX_CRV_YieldSource.claimAndSellForInputToken():
Assert message: vaultBalanceAfter >= vaultBalanceBefore - certora/specs/Vault.spec line 222


Failed on Vault.claimRewards(uint256):
Assert message: assert weak invariant in post-state - certora/specs/Vault.spec line 58

Invariant breached
Failed on CVX_CRV_YieldSource.claimRewards():
Assert message: vaultBalanceAfter >= vaultBalanceBefore - certora/specs/Vault.spec line 222


Failed on Vault.deposit(uint256):
Assert message: assert weak invariant in post-state - certora/specs/Vault.spec line 58

Invariant breached
Failed on depositIncreasesEffectiveBalance:
Assert message: to_mathint(Vault.getEffectiveDeposit(use... - certora/specs/Vault.spec line 117


Failed on Vault.withdraw(uint256,bool,uint256):
Assert message: assert weak invariant in post-state - certora/specs/Vault.spec line 58

Invariant breached
Failed on CVX_CRV_YieldSource.withdraw(uint256):
Assert message: vaultBalanceAfter >= vaultBalanceBefore - certora/specs/Vault.spec line 222


Failed on Vault.migrateYieldSource(address):
Assert message: assert weak invariant in post-state - certora/specs/Vault.spec line 58

Invariant breached
Failed on rebaseMultiplierValid:
Assert message: assert weak invariant in post-state - certora/specs/Vault.spec line 58
Violated for: 
Vault.migrateYieldSource(address),
Vault.deposit(uint256),
CVX_CRV_YieldSource.deposit(uint256),
Vault.withdraw(uint256,bool,uint256),
CVX_CRV_YieldSource.emergencyWithdraw(address,address),
CVX_CRV_YieldSource.withdraw(uint256),
CVX_CRV_YieldSource.claimRewards(),
Vault.claimRewards(uint256),
CVX_CRV_YieldSource.claimAndSellForInputToken()

Failed on noUnauthorizedTokenOutflows:
Assert message: vaultBalanceAfter >= vaultBalanceBefore - certora/specs/Vault.spec line 222
Violated for: 
CVX_CRV_YieldSource.claimRewards(),
CVX_CRV_YieldSource.withdraw(uint256),
CVX_CRV_YieldSource.claimAndSellForInputToken()

Failed on onlyOwnerCanMigrate:
Assert message: Vault.yieldSource() != yieldSourceBefore... - certora/specs/Vault.spec line 94



[ForkJoinPool-1-worker-31] WARN TREEVIEW_REPORTER - Could not find a tree view node for TREE_VIEW_ROOT_NODE - there is a call to addChildNode missing.
Duration 244600, RuleCheckResultsStats: numTotal = 18; numVerified = 8; numViolated = 10; numTimeout = 0; numError = 0
Done 4m
Done 4m
Event reporter: all events were sent without errors
