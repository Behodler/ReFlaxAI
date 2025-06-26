// Minimal Certora Specification for Vault Contract - Testing Core Issues

using Vault as vault;
using CVX_CRV_YieldSource as yieldSource;
using MockERC20 as inputToken;

methods {
    // View methods (envfree)
    function rebaseMultiplier() external returns (uint256) envfree;
    function emergencyState() external returns (bool) envfree;
    function owner() external returns (address) envfree;
    function originalDeposits(address) external returns (uint256) envfree;
    function totalDeposits() external returns (uint256) envfree;
    
    // ERC20 methods
    function _.balanceOf(address) external => DISPATCHER(true);
    function _.transferFrom(address, address, uint256) external => DISPATCHER(true);
    function _.transfer(address, uint256) external => DISPATCHER(true);
    function _.approve(address, uint256) external => DISPATCHER(true);
    
    // YieldSource methods - use NONDET to avoid complexity
    function CVX_CRV_YieldSource.deposit(uint256) external returns (uint256) => NONDET;
    function CVX_CRV_YieldSource.withdraw(uint256) external returns (uint256, uint256) => NONDET;
    function CVX_CRV_YieldSource.claimRewards() external returns (uint256) => NONDET;
    function CVX_CRV_YieldSource.claimAndSellForInputToken() external returns (uint256) => NONDET;
}

// Simple rule to test rebase multiplier preservation
rule rebaseMultiplierPreservation(method f) filtered {
    f -> f.contract == currentContract && !f.isView && 
         f.selector != sig:emergencyWithdrawFromYieldSource(address,address).selector
} {
    env e;
    calldataarg args;
    
    require rebaseMultiplier() == 1000000000000000000;
    
    f@withrevert(e, args);
    
    if (!lastReverted) {
        assert rebaseMultiplier() == 1000000000000000000;
    } else {
        assert true;
    }
}

// Simple rule to test deposit basic functionality
rule depositBasic(env e, uint256 amount) {
    require amount > 0 && amount < 1000;
    require rebaseMultiplier() == 1000000000000000000;
    require !emergencyState();
    require inputToken.balanceOf(e, e.msg.sender) >= amount;
    require inputToken.allowance(e, e.msg.sender, currentContract) >= amount;
    require originalDeposits(e.msg.sender) == 0; // Start with clean state
    require totalDeposits() == 0; // Start with clean state
    
    deposit@withrevert(e, amount);
    
    if (!lastReverted) {
        assert originalDeposits(e.msg.sender) == amount;
        assert totalDeposits() == amount;
        assert rebaseMultiplier() == 1000000000000000000;
    } else {
        assert true;
    }
}