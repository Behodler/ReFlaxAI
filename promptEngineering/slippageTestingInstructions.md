# Instructions for Testing Deposits with Maximum Tolerable Slippage

This document outlines the steps to create a test case that verifies the deposit functionality when the swap incurs the maximum tolerable slippage allowed by the `YieldSource`.

## Test Implementation Steps:

1.  **Create a New Test Function:**
    *   In `test/SlippageProtection.t.sol`, duplicate the existing `testAllowAcceptableSlippage()` function.
    *   Rename the new function to `testDepositWithMaximumTolerableSlippage()`.

2.  **Configure `underlyingWeights` to Force a Swap:**
    *   Within `testDepositWithMaximumTolerableSlippage()`, before the deposit call, invoke `yieldSource.setUnderlyingWeights(...)` using `vm.prank(owner)`.
    *   Assign weights to ensure a portion of the `inputToken` is swapped. For example, if `poolTokens.length` is 3 (as in the `setUp` function):
        *   `uint256[] memory weights = new uint256[](3);`
        *   `weights[0] = 8000; // 80% for inputToken (poolTokens[0])`
        *   `weights[1] = 2000; // 20% for poolToken1 (poolTokens[1])`
        *   `weights[2] = 0;    // 0% for poolToken2 (poolTokens[2])`
        *   `vm.prank(owner);`
        *   `yieldSource.setUnderlyingWeights(address(curvePool), weights);`

3.  **Set the Maximum Acceptable Slippage on `YieldSource`:**
    *   Define the maximum slippage basis points. For this test, use `1000` (10%).
        *   `uint256 maxTolerableSlippageBps = 1000;`
    *   Set this value on the `yieldSource`:
        *   `vm.prank(owner);`
        *   `yieldSource.setMinSlippageBps(maxTolerableSlippageBps);`

4.  **Configure the `SlippageOracle` for Ideal Price Feed:**
    *   To isolate the `YieldSource`'s slippage tolerance, configure the `SlippageOracle` (the mock named `oracle` in the test) to return the input amount directly, simulating a 1:1 price with no external slippage from its perspective for the targeted swap.
        *   `oracle.setSlippageRate(10000); // Signifies oracle.consult returns amountIn`

5.  **Configure `MockUniswapV3Router` to Simulate Exact Maximum Slippage:**
    *   Let `depositAmount` be the total amount being deposited (e.g., `100 ether`).
    *   Calculate the amount of `inputToken` designated for swapping to `poolToken1`:
        *   `uint256 swapAmountForPoolToken1 = (depositAmount * weights[1]) / 10000; // e.g., 100 ether * (2000/10000) = 20 ether`
    *   Calculate the `amountOutMinimum` that the `CVX_CRV_YieldSource` contract will expect for this swap, based on its internal logic. Given the `SlippageOracle` configuration in step 4, `idealOutput` from the oracle will be `swapAmountForPoolToken1`.
        *   `uint256 idealOutputFromOracle = swapAmountForPoolToken1;`
        *   `uint256 amountOutMinimumForYieldSource = (idealOutputFromOracle * (10000 - maxTolerableSlippageBps)) / 10000; // e.g., 20 ether * (10000 - 1000) / 10000 = 18 ether`
    *   Instruct the `MockUniswapV3Router` (named `uniswapRouter` in the test) to return exactly this `amountOutMinimumForYieldSource` when its `exactInputSingle` function is called for the swap from `inputToken` to `poolToken1`.
        *   `uniswapRouter.setReturnedAmount(amountOutMinimumForYieldSource);`

6.  **Perform the Deposit:**
    *   Execute the deposit from the `vault` account:
        *   `vm.prank(vault);`
        *   `yieldSource.deposit(depositAmount);`

7.  **Calculate the Expected `totalDeposited` Value:**
    *   The amount of `inputToken` that remains (was not designated for swapping):
        *   `uint256 retainedInputToken = (depositAmount * weights[0]) / 10000; // e.g., 100 ether * (8000/10000) = 80 ether`
    *   The amount of `poolToken1` received from the swap (as configured in step 5):
        *   `uint256 receivedPoolToken1 = amountOutMinimumForYieldSource; // e.g., 18 ether`
    *   The `MockCurvePool.add_liquidity` in `test/mocks/Mocks.sol` sums the input amounts to determine LP tokens. Therefore, the expected total LP tokens, which `totalDeposited` tracks, will be:
        *   `uint256 expectedLPTokens = retainedInputToken + receivedPoolToken1; // e.g., 80 ether + 18 ether = 98 ether`

8.  **Update the Assertion:**
    *   Verify that the deposit succeeded and that `yieldSource.totalDeposited()` equals the calculated `expectedLPTokens`.
        *   `assertEq(yieldSource.totalDeposited(), expectedLPTokens, "Deposit should succeed with maximum tolerable slippage");`

This test will confirm that the deposit proceeds correctly when the actual slippage encountered during an internal swap matches the maximum slippage tolerance set in the `YieldSource`. 