// Certora Specification for Vault Contract
// This file defines formal verification rules for the Vault contract

using Vault as vault
using YieldSource as yieldSource
using ERC20 as inputToken
using ERC20 as flaxToken
using ERC20 as sFlaxToken

methods {
    // Vault methods
    deposit(uint256) envfree
    withdraw(uint256, bool, uint256) envfree
    claimRewards(uint256) envfree
    setFlaxPerSFlax(uint256) envfree
    migrateYieldSource(address) envfree
    canWithdraw() returns (bool) envfree
    
    // View methods
    originalDeposits(address) returns (uint256) envfree
    totalDeposits() returns (uint256) envfree
    surplusInputToken() returns (uint256) envfree
    emergencyState() returns (bool) envfree
    flaxPerSFlax() returns (uint256) envfree
    
    // ERC20 methods
    balanceOf(address) returns (uint256) envfree => DISPATCHER(true)
    totalSupply() returns (uint256) envfree => DISPATCHER(true)
    allowance(address, address) returns (uint256) envfree => DISPATCHER(true)
    
    // YieldSource methods
    yieldSource.deposit(uint256) returns (uint256) => DISPATCHER(true)
    yieldSource.withdraw(uint256) returns (uint256, uint256) => DISPATCHER(true)
    yieldSource.claimRewards() returns (uint256) => DISPATCHER(true)
}

// Ghost variable to track sum of all user deposits
ghost mapping(address => uint256) userDepositsGhost {
    init_state axiom forall address user. userDepositsGhost[user] == 0;
}

ghost uint256 totalDepositsGhost {
    init_state axiom totalDepositsGhost == 0;
}

// Hook to update ghost variables
hook Sstore originalDeposits[KEY address user] uint256 newValue (uint256 oldValue) STORAGE {
    userDepositsGhost[user] = newValue;
    totalDepositsGhost = totalDepositsGhost - oldValue + newValue;
}

// Core Invariants

// The sum of all user deposits equals totalDeposits
invariant totalDepositsIntegrity()
    totalDeposits() == totalDepositsGhost
    {
        preserved {
            requireInvariant emergencyStateConsistency();
        }
    }

// No input tokens retained in vault (except surplus)
invariant noTokenRetention()
    inputToken.balanceOf(vault) == surplusInputToken()
    {
        preserved deposit(uint256 amount) with (env e) {
            require e.msg.sender != vault;
            require e.msg.sender != yieldSource;
        }
    }

// Emergency state prevents deposits, claims, and migrations
invariant emergencyStateConsistency()
    emergencyState() => 
    (forall uint256 amount. forall env e. 
        lastReverted(deposit(e, amount)) &&
        lastReverted(claimRewards(e, 0)) &&
        lastReverted(migrateYieldSource(e, 0)))

// Access Control Rules

rule onlyOwnerCanSetFlaxPerSFlax(env e, uint256 ratio) {
    uint256 rateBefore = flaxPerSFlax();
    
    setFlaxPerSFlax(e, ratio);
    
    assert flaxPerSFlax() != rateBefore => e.msg.sender == owner();
}

rule onlyOwnerCanMigrate(env e, address newYieldSource) {
    address yieldSourceBefore = yieldSource();
    
    migrateYieldSource(e, newYieldSource);
    
    assert yieldSource() != yieldSourceBefore => e.msg.sender == owner();
}

// Deposit Rules

rule depositIncreasesUserBalance(env e, uint256 amount) {
    require amount > 0;
    require !emergencyState();
    require inputToken.balanceOf(e.msg.sender) >= amount;
    require inputToken.allowance(e.msg.sender, vault) >= amount;
    
    uint256 userDepositBefore = originalDeposits(e.msg.sender);
    uint256 totalDepositsBefore = totalDeposits();
    
    deposit(e, amount);
    
    assert originalDeposits(e.msg.sender) == userDepositBefore + amount;
    assert totalDeposits() == totalDepositsBefore + amount;
}

rule depositTransfersToYieldSource(env e, uint256 amount) {
    require amount > 0;
    require !emergencyState();
    require e.msg.sender != vault && e.msg.sender != yieldSource;
    
    uint256 vaultBalanceBefore = inputToken.balanceOf(vault);
    uint256 yieldSourceBalanceBefore = inputToken.balanceOf(yieldSource);
    
    deposit(e, amount);
    
    // Vault should not retain tokens
    assert inputToken.balanceOf(vault) == vaultBalanceBefore;
    // YieldSource should receive the tokens
    assert inputToken.balanceOf(yieldSource) >= yieldSourceBalanceBefore;
}

// Withdrawal Rules

rule withdrawalDecreasesUserBalance(env e, uint256 amount, bool protectLoss) {
    require originalDeposits(e.msg.sender) >= amount;
    require canWithdraw();
    
    uint256 userDepositBefore = originalDeposits(e.msg.sender);
    uint256 totalDepositsBefore = totalDeposits();
    
    withdraw(e, amount, protectLoss, 0);
    
    assert originalDeposits(e.msg.sender) == userDepositBefore - amount;
    assert totalDeposits() == totalDepositsBefore - amount;
}

rule withdrawalRespectsSurplus(env e, uint256 amount, bool protectLoss) {
    require originalDeposits(e.msg.sender) >= amount;
    require canWithdraw();
    
    uint256 surplusBefore = surplusInputToken();
    uint256 userBalanceBefore = inputToken.balanceOf(e.msg.sender);
    
    uint256 received;
    uint256 flaxValue;
    received, flaxValue = yieldSource.withdraw(e, amount);
    
    withdraw(e, amount, protectLoss, 0);
    
    // User should receive at least min(amount, received + surplus)
    if (received >= amount) {
        assert inputToken.balanceOf(e.msg.sender) == userBalanceBefore + amount;
        assert surplusInputToken() == surplusBefore + (received - amount);
    } else {
        uint256 shortfall = amount - received;
        if (surplusBefore >= shortfall) {
            assert inputToken.balanceOf(e.msg.sender) == userBalanceBefore + amount;
            assert surplusInputToken() == surplusBefore - shortfall;
        } else {
            assert protectLoss => lastReverted;
            assert !protectLoss => inputToken.balanceOf(e.msg.sender) == userBalanceBefore + received;
        }
    }
}

// Reward Rules

rule sFlaxBurnBoostsRewards(env e, uint256 sFlaxAmount) {
    require !emergencyState();
    require sFlaxAmount > 0;
    require flaxPerSFlax() > 0;
    require sFlaxToken.balanceOf(e.msg.sender) >= sFlaxAmount;
    require sFlaxToken.allowance(e.msg.sender, vault) >= sFlaxAmount;
    
    uint256 baseFlaxReward = yieldSource.claimRewards(e);
    uint256 flaxBoost = sFlaxAmount * flaxPerSFlax() / 10^18;
    uint256 userFlaxBefore = flaxToken.balanceOf(e.msg.sender);
    uint256 sFlaxSupplyBefore = sFlaxToken.totalSupply();
    
    claimRewards(e, sFlaxAmount);
    
    assert flaxToken.balanceOf(e.msg.sender) == userFlaxBefore + baseFlaxReward + flaxBoost;
    assert sFlaxToken.totalSupply() == sFlaxSupplyBefore - sFlaxAmount;
}

// Migration Rules

rule migrationPreservesFunds(env e, address newYieldSource) {
    require e.msg.sender == owner();
    require !emergencyState();
    require newYieldSource != 0;
    
    uint256 totalDepositsBefore = totalDeposits();
    uint256 vaultInputBalanceBefore = inputToken.balanceOf(vault);
    
    migrateYieldSource(e, newYieldSource);
    
    // Total deposits should be preserved (or 0 if all withdrawn)
    assert totalDeposits() == totalDepositsBefore || totalDeposits() == 0;
    // No tokens should be left in vault after migration
    assert inputToken.balanceOf(vault) == 0;
}

// Emergency Rules

rule emergencyStateStopsOperations(env e) {
    require emergencyState();
    
    uint256 amount;
    address newYieldSource;
    
    // All these should revert in emergency state
    assert lastReverted(deposit(e, amount));
    assert lastReverted(claimRewards(e, 0));
    assert lastReverted(migrateYieldSource(e, newYieldSource));
}

rule emergencyWithdrawalRequiresEmergencyState(env e, address token, address recipient) {
    require !emergencyState();
    
    emergencyWithdrawFromYieldSource(e, token, recipient);
    
    assert lastReverted;
}

// Additional Safety Properties

rule noNegativeDeposits() {
    env e;
    address user;
    assert originalDeposits(user) >= 0;
    assert totalDeposits() >= 0;
    assert surplusInputToken() >= 0;
}

rule userCannotDepositForOthers(env e, uint256 amount, address otherUser) {
    require e.msg.sender != otherUser;
    
    uint256 otherUserDepositBefore = originalDeposits(otherUser);
    
    deposit(e, amount);
    
    assert originalDeposits(otherUser) == otherUserDepositBefore;
}

rule withdrawalCannotAffectOthers(env e, uint256 amount, bool protectLoss, address otherUser) {
    require e.msg.sender != otherUser;
    
    uint256 otherUserDepositBefore = originalDeposits(otherUser);
    uint256 otherUserBalanceBefore = inputToken.balanceOf(otherUser);
    
    withdraw(e, amount, protectLoss, 0);
    
    assert originalDeposits(otherUser) == otherUserDepositBefore;
    assert inputToken.balanceOf(otherUser) == otherUserBalanceBefore;
}