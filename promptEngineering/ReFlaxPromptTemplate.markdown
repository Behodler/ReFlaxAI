# ReFlax Project Assistance Prompt

I'm working on an Ethereum project called ReFlax, written in Solidity and using Foundry for testing, compilation, and deployment. Below, I've attached the current source code and a high-level explanation of the project.

## Source Code
All files in src

## High-Level Explanation

ReFlax allows users to deposit a single input token (e.g., USDC) into yield optimizer pools (e.g., Convex targeting Curve pools) to earn rewards, which are converted into Flax tokens. The system tracks deposits, handles reward claims, and manages withdrawals with surplus/shortfall mechanisms.

- **Vault Contract** (abstract, user-facing):
  - Manages deposits, withdrawals, and reward claims for one input token (set at deployment).
  - Tracks user deposits (`originalDeposits`) and total deposits (`totalDeposits`).
  - Stores surplus input tokens (`surplusInputToken`) to offset withdrawal shortfalls.
  - Supports burning `sFlaxToken` to boost Flax rewards based on `flaxPerSFlax` ratio.
    - **Note**: The `sFlaxToken` must implement a `burn(uint256)` function that the Vault can call directly.
  - Allows migration to a new `YieldSource`.
  - Placeholder `canWithdraw` for future governance rules (e.g., auctions, crowdfunds).

- **YieldSource Contract** (abstract, with concrete implementations like `CVX_CRV_YieldSource`):
  - Converts input token to pool tokens (e.g., USDC/USDT), deposits into yield optimizers, and processes rewards.
  - `CVX_CRV_YieldSource`:
    - Swaps input token for pool tokens via Uniswap V3, adds liquidity to Curve, and deposits LP tokens into Convex.
    - Claims rewards (e.g., CRV, CVX), sells for ETH, and calculates Flax value via `PriceTilter`.
    - Withdraws by removing liquidity from Curve and converting to input token.
  - Uses `TWAPOracle` for slippage protection and `PriceTilter` for Flax/ETH operations.

- **PriceTilter Contract** (`PriceTilterTWAP.sol`):
  - Calculates Flax value of ETH using `TWAPOracle` for the Flax/ETH Uniswap V2 pair.
  - Tilts Flax price by adding liquidity to the Flax/ETH Uniswap V2 pair with less Flax than the oracle-derived value (controlled by `priceTiltRatio`), increasing Flax's price in ETH.
  - Supports registering the Flax/ETH pair for TWAP updates and uses `addLiquidityETH` to handle ETH deposits.

- **TWAPOracle Contract**:
  - Provides TWAP prices for token pairs (e.g., Flax/ETH) over a 1-hour period.
  - Requires owner updates, with a bot potentially updating every 6 hours if no activity occurs.

- **Deposit Flow** (single transaction):
  1. Swap input token for pool tokens (e.g., USDC/USDT) on Uniswap V3.
  2. Pool tokens into Curve LP token.
  3. Deposit LP token into Convex.
  
  **Note**: After deposit, input tokens are immediately transferred to the YieldSource and not retained in the Vault.

- **Reward Claim Flow** (single transaction):
  1. Claim rewards from Convex (e.g., CRV, CVX).
  2. Sell rewards for ETH on Uniswap V3.
  3. Use `PriceTilter` to calculate Flax value and tilt Flax/ETH pool liquidity by adding less Flax than the TWAP-derived amount.
  4. Transfer Flax to user (Vault has sufficient Flax balance).

- **Withdrawal Flow** (single transaction):
  1. Withdraw LP tokens from Convex.
  2. Remove liquidity from Curve, converting to input token.
  3. Return original deposit amount, using surplus tokens for shortfalls or storing excess.
  4. Revert if shortfall exceeds surplus and `protectLoss` is true.

- **sFlaxToken**:
  - ERC20 token earned from staking Flax in another project (similar to veCRV but tradable/transferable).
  - Burnable to boost Flax rewards during claims or withdrawals.
  - **Implementation Note**: Must implement a `burn(uint256)` function that can be called by the Vault.

- **Surplus/Loss**:
  - Surplus tokens offset shortfalls; users bear impermanent loss/fees during migrations or withdrawals.
  - Migration losses are mitigated by campaigns encouraging pre-migration withdrawals.

- **Architecture**:
  - Each `Vault` supports one input token and one `YieldSource` (migratable).
  - Contracts use `Ownable` for configuration (e.g., setting `flaxPerSFlax`, registering pairs).

- **Testing**:
  - Unit tests are written using Foundry, with test files corresponding to specific contracts:
    - `YieldSource.t.sol`: Tests `CVX_CRV_YieldSource` functionality (deposit, withdraw, reward claims) using mocks for external dependencies (e.g., Uniswap, Curve, Convex).
    - `Vault.t.sol`: Tests `Vault` functionality (deposit, withdraw, reward claims, surplus/shortfall handling) using mocks for `YieldSource` and `PriceTilter`.
      - **Test Note**: `testDeposit` verifies that tokens are correctly sent to the YieldSource and not retained in the Vault.
  - Tests use a `Mocks.sol` file containing minimally invasive mock contracts (e.g., `MockERC20`, `MockYieldSource`, `MockUniswapV3Router`, `MockCurvePool`, `MockPriceTilter`) that simulate only the behavior required by the corresponding test file, ensuring isolated testing of each contract's functionality.
  - Mocking Philosophy: Mocks are designed to be minimal, implementing only the functions and state necessary for the test cases, avoiding unnecessary complexity or over-mocking of dependencies. For example, `MockYieldSource` in `Vault.t.sol` only mocks `deposit`, `withdraw`, and `claimRewards` with configurable return values, while `MockCurvePool` in `YieldSource.t.sol` focuses on `add_liquidity` and `remove_liquidity_one_coin`.
  - New tests should follow this approach, creating or extending test files (e.g., `PriceTilterTWAP.t.sol`) with mocks tailored to the contract's test requirements, added to `Mocks.sol` if shared across test files.
  - **Mock Requirements**:
    - `MockERC20` must implement a `burn(uint256)` function for tokens used as `sFlaxToken`.
  - **Recent Test Fixes**:
    - Fixed `testWithdraw` in `YieldSource.t.sol` by adding proper LP token approval for the Curve pool.
    - Implemented a simple `MockOracle` for tests that don't need the full TWAP oracle functionality.
    - Ensured proper setup of price cumulative values in the `MockUniswapV2Pair` for TWAP oracle tests.

## Specific Request

[state specific request, e.g., "Write unit tests for `PriceTilterTWAP.sol` in a new `PriceTilterTWAP.t.sol` file, including any necessary mocks to test its functionality in isolation. Ensure mocks are minimally invasive, implementing only the behavior required by the test cases, and add new mocks to `Mocks.sol` if they are reusable across test files."]

## Notes

- Assume `Vault` has sufficient Flax balance (no minting logic in scope).
- Only the Flax/ETH Uniswap V2 pair is used for price tilting.
- ETH sent to `PriceTilter` should be used immediately for liquidity addition (no retention).
- For new tests, prioritize isolated testing of the target contract, using minimal mocks to simulate external dependencies. Add new mocks to `Mocks.sol` if they are reusable (e.g., `MockUniswapV2Router` for `PriceTilterTWAP.t.sol`) or keep them in the test file if specific to one contract.
- Ensure test files are named after the contract they test (e.g., `TWAPOracle.t.sol` for `TWAPOracle.sol`) and follow the structure of `Vault.t.sol` and `YieldSource.t.sol` for consistency.
- When working with mocks that interact with Uniswap V2 pairs, ensure proper initialization of price cumulatives and reserves for TWAP calculations.
- For Curve pool interactions, remember to properly approve LP tokens before attempting to remove liquidity.