// Minimal test to check CVL syntax

using MockERC20 as token;

methods {
    function balanceOf(address) external returns (uint256) envfree;
}

rule simple_test() {
    env e;
    assert true;
}