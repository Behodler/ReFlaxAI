Failed on rebaseMultiplier():
Assert message: multiplierAfter == 1000000000000000000 |... - certora/specs/Vault.spec line 76

Failed on setEmergencyState(bool):
Assert message: multiplierAfter == 1000000000000000000 |... - certora/specs/Vault.spec line 76

Failed on surplusInputToken():
Assert message: multiplierAfter == 1000000000000000000 |... - certora/specs/Vault.spec line 76

Failed on inputToken():
Assert message: multiplierAfter == 1000000000000000000 |... - certora/specs/Vault.spec line 76

Failed on sFlaxToken():
Assert message: multiplierAfter == 1000000000000000000 |... - certora/specs/Vault.spec line 76

Failed on yieldSource():
Assert message: multiplierAfter == 1000000000000000000 |... - certora/specs/Vault.spec line 76

Failed on totalDeposits():
Assert message: multiplierAfter == 1000000000000000000 |... - certora/specs/Vault.spec line 76

Failed on flaxToken():
Assert message: multiplierAfter == 1000000000000000000 |... - certora/specs/Vault.spec line 76

Failed on owner():
Assert message: multiplierAfter == 1000000000000000000 |... - certora/specs/Vault.spec line 76

Failed on flaxPerSFlax():
Assert message: multiplierAfter == 1000000000000000000 |... - certora/specs/Vault.spec line 76

Failed on priceTilter():
Assert message: multiplierAfter == 1000000000000000000 |... - certora/specs/Vault.spec line 76

Failed on emergencyState():
Assert message: multiplierAfter == 1000000000000000000 |... - certora/specs/Vault.spec line 76

Failed on canWithdraw():
Assert message: multiplierAfter == 1000000000000000000 |... - certora/specs/Vault.spec line 76

Failed on renounceOwnership():
Assert message: multiplierAfter == 1000000000000000000 |... - certora/specs/Vault.spec line 76

Failed on <receiveOrFallback>():
Assert message: multiplierAfter == 1000000000000000000 |... - certora/specs/Vault.spec line 76

Failed on getEffectiveTotalDeposits():
Assert message: multiplierAfter == 1000000000000000000 |... - certora/specs/Vault.spec line 76

Failed on emergencyWithdraw(address,address):
Assert message: multiplierAfter == 1000000000000000000 |... - certora/specs/Vault.spec line 76

Failed on originalDeposits(address):
Assert message: multiplierAfter == 1000000000000000000 |... - certora/specs/Vault.spec line 76

Failed on getEffectiveDeposit(address):
Assert message: multiplierAfter == 1000000000000000000 |... - certora/specs/Vault.spec line 76

Failed on transferOwnership(address):
Assert message: multiplierAfter == 1000000000000000000 |... - certora/specs/Vault.spec line 76

Failed on emergencyWithdrawETH(address):
Assert message: multiplierAfter == 1000000000000000000 |... - certora/specs/Vault.spec line 76

Failed on claimRewards(uint256):
Assert message: multiplierAfter == 1000000000000000000 |... - certora/specs/Vault.spec line 76

Failed on emergencyWithdrawFromYieldSource(address,address):
Assert message: multiplierAfter == 1000000000000000000 |... - certora/specs/Vault.spec line 76

Failed on emergencyWithdrawalDisablesVault:
Assert message: Vault.rebaseMultiplier() == 0 - certora/specs/Vault.spec line 256

Failed on sFlaxBurnBoostsRewards:
Assert message: sFlaxAmount > 0 => flaxIncrease >= expec... - certora/specs/Vault.spec line 302

Failed on userCannotDepositForOthers:
Assert message: Vault.originalDeposits(otherUser) == oth... - certora/specs/Vault.spec line 358

Failed on withdrawalRespectsSurplus:
Assert message: MockERC20.balanceOf(e, e.msg.sender) > u... - certora/specs/Vault.spec line 193

Failed on deposit(uint256):
Assert message: multiplierAfter == 1000000000000000000 |... - certora/specs/Vault.spec line 76

Failed on withdrawalDecreasesEffectiveBalance:
Assert message: Vault.getEffectiveDeposit(user=e.msg.sen... - certora/specs/Vault.spec line 166

Failed on depositIncreasesEffectiveBalance:
Assert message: Vault.getEffectiveDeposit(user=e.msg.sen... - certora/specs/Vault.spec line 136

Failed on setFlaxPerSFlax(uint256):
Assert message: multiplierAfter == 1000000000000000000 |... - certora/specs/Vault.spec line 76

Failed on withdrawalCannotAffectOthers:
Assert message: Vault.originalDeposits(otherUser) == oth... - certora/specs/Vault.spec line 382

Failed on withdraw(uint256,bool,uint256):
Assert message: multiplierAfter == 1000000000000000000 |... - certora/specs/Vault.spec line 76

Failed on migrateYieldSource(address):
Assert message: multiplierAfter == 1000000000000000000 |... - certora/specs/Vault.spec line 76

Failed on rebaseMultiplierIsValid:
Assert message: multiplierAfter == 1000000000000000000 |... - certora/specs/Vault.spec line 76
Violated for: 
emergencyWithdrawETH(address),
setFlaxPerSFlax(uint256),
withdraw(uint256,bool,uint256),
<receiveOrFallback>(),
originalDeposits(address),
claimRewards(uint256),
flaxPerSFlax(),
yieldSource(),
canWithdraw(),
priceTilter(),
sFlaxToken(),
flaxToken(),
totalDeposits(),
deposit(uint256),
emergencyWithdraw(address,address),
setEmergencyState(bool),
getEffectiveTotalDeposits(),
renounceOwnership(),
getEffectiveDeposit(address),
rebaseMultiplier(),
owner(),
emergencyState(),
transferOwnership(address),
inputToken(),
surplusInputToken(),
emergencyWithdrawFromYieldSource(address,address),
migrateYieldSource(address)
Failed on onlyOwnerCanMigrate:
Assert message: !(lastReverted) && Vault.yieldSource() !... - certora/specs/Vault.spec line 115

[ForkJoinPool-1-worker-30] WARN TREEVIEW_REPORTER - Could not find a tree view node for TREE_VIEW_ROOT_NODE - there is a call to addChildNode missing.
Duration 239976, RuleCheckResultsStats: numTotal = 18; numVerified = 9; numViolated = 9; numTimeout = 0; numError = 0
Ping 4m - Processed 19/19 (100%) rules. 128 tasks complete, 0 pending.
Done 4m
Done 4m
Event repor
