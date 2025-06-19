// Minimal Vault specification to test basic syntax

using Vault as vault;
using MockERC20 as inputToken;

methods {
    function rebaseMultiplier() external returns (uint256) envfree;
    function originalDeposits(address) external returns (uint256) envfree;
    function totalDeposits() external returns (uint256) envfree;
    function emergencyState() external returns (bool) envfree;
    function owner() external returns (address) envfree;
    
    function _.balanceOf(address) external => DISPATCHER(true);
    function _.allowance(address, address) external => DISPATCHER(true);
}

rule basicTest(env e) {
    assert rebaseMultiplier() >= 0;
}