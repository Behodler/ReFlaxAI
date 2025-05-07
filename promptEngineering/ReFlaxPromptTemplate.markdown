# ReFlax Project Assistance Prompt

I’m working on an Ethereum project called ReFlax, written in Solidity and using Foundry for testing, compilation, and deployment. Below, I’ve attached the current source code and a high-level explanation of the project. My goal is to [state specific goal, e.g., debug a function, fix tests, optimize gas, add a feature]. Please review the code and explanation, then [specific request, e.g., identify issues, suggest improvements, help write tests]. If anything is unclear, ask targeted questions to clarify before proceeding.

## Source Code
[Attach relevant files, e.g., `Vault.sol`, `AYieldSource.sol`, `CVX_CRV_YieldSource.sol`, `PriceTilterTWAP.sol`, `TWAPOracle.sol`]

## High-Level Explanation
ReFlax allows users to deposit a single input token (e.g., USDC) into yield optimizer pools (e.g., Convex targeting Curve pools) to earn rewards, which are converted into Flax tokens. The system tracks deposits, handles reward claims, and manages withdrawals with surplus/shortfall mechanisms.

- **Vault Contract** (abstract, user-facing):
  - Manages deposits, withdrawals, and reward claims for one input token (set at deployment).
  - Tracks user deposits (`originalDeposits`) and total deposits (`totalDeposits`).
  - Stores surplus input tokens (`surplusInputToken`) to offset withdrawal shortfalls.
  - Supports burning `sFlaxToken` to boost Flax rewards based on `flaxPerSFlax` ratio.
  - Allows migration to a new `YieldSource`.
  - Placeholder `canWithdraw` for future governance rules (e.g., auctions, crowdfunds).

- **YieldSource Contract** (abstract, with concrete implementations like `CVX_CRV_YieldSource`):
  - Converts input token to pool tokens (e.g., USDS/USDT), deposits into yield optimizers, and processes rewards.
  - `CVX_CRV_YieldSource`:
    - Swaps input token for pool tokens via Uniswap V3, adds liquidity to Curve, and deposits LP tokens into Convex.
    - Claims rewards (e.g., CRV, CVX), sells for ETH, and calculates Flax value via `PriceTilter`.
    - Withdraws by removing liquidity from Curve and converting to input token.
  - Uses `TWAPOracle` for slippage protection and `PriceTilter` for Flax/ETH operations.

- **PriceTilter Contract** (`PriceTilterTWAP.sol`):
  - Calculates Flax value of ETH using `TWAPOracle` for the Flax/ETH Uniswap V2 pair.
  - Tilts Flax price by adding liquidity to the Flax/ETH Uniswap V2 pair with less Flax than the oracle-derived value (controlled by `priceTiltRatio`), increasing Flax’s price in ETH.
  - Supports registering the Flax/ETH pair for TWAP updates and uses `addLiquidityETH` to handle ETH deposits.

- **TWAPOracle Contract**:
  - Provides TWAP prices for token pairs (e.g., Flax/ETH) over a 1-hour period.
  - Requires owner updates, with a bot potentially updating every 6 hours if no activity occurs.

- **Deposit Flow** (single transaction):
  1. Swap input token for pool tokens (e.g., USDS/USDT) on Uniswap V3.
  2. Pool tokens into Curve LP token.
  3. Deposit LP token into Convex.

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

- **Surplus/Loss**:
  - Surplus tokens offset shortfalls; users bear impermanent loss/fees during migrations or withdrawals.
  - Migration losses are mitigated by campaigns encouraging pre-migration withdrawals.

- **Architecture**:
  - Each `Vault` supports one input token and one `YieldSource` (migratable).
  - Contracts use `Ownable` for configuration (e.g., setting `flaxPerSFlax`, registering pairs).

## Specific Request
[placeholder for request]

## Notes
- Assume `Vault` has sufficient Flax balance (no minting logic in scope).
- Only the Flax/ETH Uniswap V2 pair is used for price tilting.
- ETH sent to `PriceTilter` should be used immediately for liquidity addition (no retention).