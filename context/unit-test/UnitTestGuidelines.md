# Unit Test Guidelines

## Testing Philosophy

Tests are written using Foundry with minimal mocks (`test/mocks/Mocks.sol`) that implement only required functionality:
- Each contract has its own test file (e.g., `Vault.t.sol`, `YieldSource.t.sol`, `PriceTilterTWAP.t.sol`)
- Mocks are designed to be minimal, implementing only functions and state necessary for test cases
- Focus on isolated unit testing of each component's functionality
- New tests should follow this approach, creating or extending test files with mocks tailored to contract requirements 

## Test Structure
- Test files are named after the contract they test (e.g., `TWAPOracle.t.sol` for `TWAPOracle.sol`)
- Mocks simulate only behavior required by corresponding test file (e.g., `MockYieldSource` only mocks `deposit`, `withdraw`, and `claimRewards`)
- Shared mocks are added to `Mocks.sol`, while test-specific mocks remain in the test file

## Mock Requirements
- `MockERC20` must implement a `burn(uint256)` function for tokens used as sFlaxToken
- When working with Uniswap V2 pairs, ensure proper initialization of price cumulatives and reserves for TWAP calculations
- For Curve pool interactions, remember to properly approve LP tokens before attempting to remove liquidity

## Recent Test Improvements
- Fixed `testWithdraw` in `YieldSource.t.sol` by adding proper LP token approval for the Curve pool
- Implemented a simple `MockOracle` for tests that don't need full TWAP oracle functionality
- Ensured proper setup of price cumulative values in `MockUniswapV2Pair` for TWAP oracle tests
- Implemented comprehensive slippage protection tests in `SlippageProtection.t.sol` including:
  - `testDepositWithMaximumTolerableSlippage()`: Tests deposits when swap incurs exactly the maximum tolerable slippage
  - `testRevertOnExcessiveSlippage()`: Tests that deposits revert when slippage exceeds tolerance
  - Enhanced `MockUniswapV3Router` with `setSpecificReturnAmount()` for precise control over individual swap returns
  - Fixed mock ETH handling for reward token sales and ETH-to-token swaps
  - Addressed a source code issue where `_sellEthForInputToken` doesn't send ETH with the Uniswap call

## Important Notes

- The `sFlaxToken` must implement a `burn(uint256)` function callable by the Vault
- Input tokens are immediately transferred to YieldSource after deposit (not retained in Vault)
- Emergency functionality exists in both Vault and YieldSource for security
- TWAP oracles are updated at the beginning of deposit, withdraw, and claim operations
- `testDeposit` verifies that tokens are correctly sent to the YieldSource and not retained in the Vault