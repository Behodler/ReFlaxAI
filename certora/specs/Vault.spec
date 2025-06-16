// Certora Specification for Vault Contract
// This file defines formal verification rules for the Vault contract

using Vault as vault;
using CVX_CRV_YieldSource as yieldSource;
using MockERC20 as inputToken;
using MockERC20 as flaxToken;
using MockERC20 as sFlaxToken;

methods {
    // View methods (envfree)
    function canWithdraw() external returns (bool) envfree;
    
    // View methods
    function originalDeposits(address) external returns (uint256) envfree;
    function totalDeposits() external returns (uint256) envfree;
    function surplusInputToken() external returns (uint256) envfree;
    function emergencyState() external returns (bool) envfree;
    function flaxPerSFlax() external returns (uint256) envfree;
    function owner() external returns (address) envfree;
    function yieldSource() external returns (address) envfree;
    
    // ERC20 methods - use wildcard receiver for DISPATCHER
    function _.balanceOf(address) external => DISPATCHER(true);
    function _.totalSupply() external => DISPATCHER(true);
    function _.allowance(address, address) external => DISPATCHER(true);
    
    // YieldSource methods - use wildcard receiver for DISPATCHER
    function _.deposit(uint256) external => DISPATCHER(true);
    function _.withdraw(uint256) external => DISPATCHER(true);
    function _.claimRewards() external => DISPATCHER(true);
}

// Ghost variable to track sum of all user deposits
ghost mapping(address => uint256) userDepositsGhost {
    init_state axiom forall address user. userDepositsGhost[user] == 0;
}

ghost mathint totalDepositsGhost {
    init_state axiom totalDepositsGhost == 0;
}

// Hook to update ghost variables
hook Sstore originalDeposits[KEY address user] uint256 newValue (uint256 oldValue) {
    userDepositsGhost[user] = newValue;
    totalDepositsGhost = totalDepositsGhost - to_mathint(oldValue) + to_mathint(newValue);
}

// Core Invariants

// The sum of all user deposits equals totalDeposits
invariant totalDepositsIntegrity()
    to_mathint(totalDeposits()) == totalDepositsGhost;

// No input tokens retained in vault (except surplus)
invariant noTokenRetention(env e)
    inputToken.balanceOf(e, currentContract) == surplusInputToken()
    {
        preserved deposit(uint256 amount) with (env e2) {
            require e2.msg.sender != currentContract;
            require e2.msg.sender != yieldSource();
        }
    }

// Emergency state prevents deposits, claims, and migrations
rule emergencyStatePreventsFunctions(env e, uint256 amount, address newYieldSource) {
    require emergencyState();
    
    deposit@withrevert(e, amount);
    assert lastReverted;
    
    claimRewards@withrevert(e, 0);
    assert lastReverted;
    
    migrateYieldSource@withrevert(e, newYieldSource);
    assert lastReverted;
}

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
    require inputToken.balanceOf(e, e.msg.sender) >= amount;
    require inputToken.allowance(e, e.msg.sender, currentContract) >= amount;
    
    uint256 userDepositBefore = originalDeposits(e.msg.sender);
    uint256 totalDepositsBefore = totalDeposits();
    
    deposit(e, amount);
    
    assert originalDeposits(e.msg.sender) == userDepositBefore + amount;
    assert totalDeposits() == totalDepositsBefore + amount;
}

rule depositTransfersToYieldSource(env e, uint256 amount) {
    require amount > 0;
    require !emergencyState();
    require e.msg.sender != currentContract && e.msg.sender != yieldSource();
    
    uint256 vaultBalanceBefore = inputToken.balanceOf(e, currentContract);
    uint256 yieldSourceBalanceBefore = inputToken.balanceOf(e, yieldSource());
    
    deposit(e, amount);
    
    // Vault should not retain tokens
    assert inputToken.balanceOf(e, currentContract) == vaultBalanceBefore;
    // YieldSource should receive the tokens
    assert inputToken.balanceOf(e, yieldSource()) >= yieldSourceBalanceBefore;
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
    uint256 userBalanceBefore = inputToken.balanceOf(e, e.msg.sender);
    
    uint256 received;
    uint256 flaxValue;
    received, flaxValue = yieldSource.withdraw(e, amount);
    
    mathint shortfall = to_mathint(amount) - to_mathint(received);
    
    if (received >= amount) {
        withdraw(e, amount, protectLoss, 0);
        assert inputToken.balanceOf(e, e.msg.sender) == userBalanceBefore + amount;
        assert surplusInputToken() == surplusBefore + (received - amount);
    } else if (surplusBefore >= shortfall) {
        withdraw(e, amount, protectLoss, 0);
        assert inputToken.balanceOf(e, e.msg.sender) == userBalanceBefore + amount;
        assert surplusInputToken() == surplusBefore - shortfall;
    } else {
        withdraw@withrevert(e, amount, protectLoss, 0);
        if (protectLoss) {
            assert lastReverted;
        } else {
            assert !lastReverted;
            assert inputToken.balanceOf(e, e.msg.sender) == userBalanceBefore + received;
        }
    }
}

// Reward Rules

rule sFlaxBurnBoostsRewards(env e, uint256 sFlaxAmount) {
    require !emergencyState();
    require sFlaxAmount > 0;
    require flaxPerSFlax() > 0;
    require sFlaxToken.balanceOf(e, e.msg.sender) >= sFlaxAmount;
    require sFlaxToken.allowance(e, e.msg.sender, currentContract) >= sFlaxAmount;
    
    uint256 baseFlaxReward = yieldSource.claimRewards(e);
    mathint flaxBoost = to_mathint(sFlaxAmount) * to_mathint(flaxPerSFlax()) / 10^18;
    uint256 userFlaxBefore = flaxToken.balanceOf(e, e.msg.sender);
    uint256 sFlaxSupplyBefore = sFlaxToken.totalSupply(e);
    
    claimRewards(e, sFlaxAmount);
    
    assert to_mathint(flaxToken.balanceOf(e, e.msg.sender)) == to_mathint(userFlaxBefore) + to_mathint(baseFlaxReward) + flaxBoost;
    assert sFlaxToken.totalSupply(e) == sFlaxSupplyBefore - sFlaxAmount;
}

// Migration Rules

rule migrationPreservesFunds(env e, address newYieldSource) {
    require e.msg.sender == owner();
    require !emergencyState();
    require newYieldSource != 0;
    
    uint256 totalDepositsBefore = totalDeposits();
    uint256 vaultInputBalanceBefore = inputToken.balanceOf(e, currentContract);
    
    migrateYieldSource(e, newYieldSource);
    
    // Total deposits should be preserved (or 0 if all withdrawn)
    assert totalDeposits() == totalDepositsBefore || totalDeposits() == 0;
    // No tokens should be left in vault after migration
    assert inputToken.balanceOf(e, currentContract) == 0;
}

// Emergency Rules

rule emergencyStateStopsOperations(env e) {
    require emergencyState();
    
    uint256 amount;
    address newYieldSource;
    
    // All these should revert in emergency state
    deposit@withrevert(e, amount);
    assert lastReverted;
    
    claimRewards@withrevert(e, 0);
    assert lastReverted;
    
    migrateYieldSource@withrevert(e, newYieldSource);
    assert lastReverted;
}

rule emergencyWithdrawalRequiresEmergencyState(env e, address token, address recipient) {
    require !emergencyState();
    
    emergencyWithdrawFromYieldSource@withrevert(e, token, recipient);
    
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
    uint256 otherUserBalanceBefore = inputToken.balanceOf(e, otherUser);
    
    withdraw(e, amount, protectLoss, 0);
    
    assert originalDeposits(otherUser) == otherUserDepositBefore;
    assert inputToken.balanceOf(e, otherUser) == otherUserBalanceBefore;
}