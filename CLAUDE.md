# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Workflow Rules
- When beginnning a task, always produce a checklist which you progressively check ooff.
- When implementing new features or making significant architectural changes, proactively update relevant sections of this CLAUDE.md file
- Document new test patterns or mock requirements when adding tests
- Update command sections if new development commands are introduced
- always make sure code is compiling successfully before reporting completeness.
- Sometimes, it is acceptable for some tests to be in a broken state. But for tests that are expected to be passing, ensure they are still passing.

## Conventions
- When I ask you to look at a markdown file, if I say "do" or "execute" an item on a list, I mean do the programming task it describes.
- If I mention a markdown file without giving a location, look first in context/ and then in the root of this project.

## Common Development Commands

### Building
```bash
forge build
```
Note that builds can take quite long. Set a timeout of about 10 minutes.

### Running Tests

Tests are organized into unit tests and integration tests that can be run independently:

#### Unit Tests
```bash
# Run unit tests only (excludes integration tests)
./scripts/test-unit.sh

# Or directly with forge:
forge test --no-match-path "test-integration/**"
```

#### Integration Tests
```bash
# First, allow direnv to load environment variables
direnv allow

# Run integration tests (uses RPC URL from .envrc)
./scripts/test-integration.sh

# Or directly with forge:
forge test --profile integration -f $RPC_URL -vvv
```

**Note**: 
- Integration tests use a separate profile defined in `foundry.toml` with the `test-integration` directory and require an Arbitrum fork
- The project uses `direnv` to manage environment variables. Always run `direnv allow` before running integration tests to load the RPC_URL from `.envrc`

#### All Tests
```bash
# Run all tests (both unit and integration)
forge test

# Run specific test file
forge test --match-path test/Vault.t.sol

# Run specific test function
forge test --match-test testDeposit

# Run tests with verbosity
forge test -vvv

# Run tests with gas reporting
forge test --gas-report
```

### Linting/Type Checking
No specific linting commands found. Solidity compilation errors will be caught by `forge build`.

## Architecture Overview

ReFlax is a yield optimization protocol that allows users to deposit tokens into yield sources (like Convex/Curve) and earn Flax token rewards. The system consists of:

### Core Components

1. **Vault** (`src/vault/Vault.sol`): User-facing abstract contract managing deposits, withdrawals, and rewards
   - Each vault supports one input token (e.g., USDC) set at deployment
   - Tracks user deposits (`originalDeposits`) and total deposits (`totalDeposits`)
   - Stores surplus input tokens (`surplusInputToken`) to offset withdrawal shortfalls
   - Supports burning sFlaxToken to boost rewards based on `flaxPerSFlax` ratio
   - Allows migration to a new YieldSource
   - Placeholder `canWithdraw` for future governance rules (e.g., auctions, crowdfunds)
   - Includes emergency withdrawal functionality with an emergency state toggle that prevents new deposits, claims, and migrations when active

2. **YieldSource** (`src/yieldSource/`): Abstract base with concrete implementations
   - Converts input token to pool tokens, deposits into yield optimizers, and processes rewards
   - Updates TWAP oracles during deposit, withdraw, and claim reward operations to ensure accurate price data
   - **CVX_CRV_YieldSource**:
     - Swaps input token for pool tokens (e.g., USDC/USDT) via Uniswap V3
     - Adds liquidity to Curve and deposits LP tokens into Convex
     - Claims rewards (e.g., CRV, CVX), sells for ETH, and calculates Flax value via PriceTilter
     - Withdraws by removing liquidity from Curve and converting to input token
   - Uses TWAPOracle for slippage protection and PriceTilter for Flax/ETH operations
   - Includes emergency withdrawal functionality to recover assets in case of failures or security concerns

3. **PriceTilter** (`src/priceTilting/PriceTilterTWAP.sol`): Manages Flax/ETH pricing
   - Calculates Flax value of ETH using TWAPOracle for the Flax/ETH Uniswap V2 pair
   - Tilts Flax price by adding liquidity with less Flax than the oracle-derived value (controlled by `priceTiltRatio`), increasing Flax's price in ETH
   - Supports registering the Flax/ETH pair for TWAP updates and uses `addLiquidityETH` to handle ETH deposits
   - Ensures all available ETH balance is used for liquidity provision, including any leftover from previous operations
   - Includes emergency withdrawal functionality for the owner to recover assets

4. **TWAPOracle** (`src/priceTilting/TWAPOracle.sol`): Provides time-weighted average prices
   - 1-hour TWAP period for price calculations
   - Requires owner updates, with a bot potentially updating every 6 hours if no activity occurs
   - Automatically updated during YieldSource deposit, withdraw, and claim operations

### Key Flows

- **Deposit Flow** (single transaction):
  1. Swap input token for pool tokens (e.g., USDC/USDT) on Uniswap V3
  2. Pool tokens into Curve LP token
  3. Deposit LP token into Convex
  4. Update TWAP oracles to maintain accurate price data
  
  **Note**: After deposit, input tokens are immediately transferred to the YieldSource and not retained in the Vault

- **Reward Claim Flow** (single transaction):
  1. Claim rewards from Convex (e.g., CRV, CVX)
  2. Sell rewards for ETH on Uniswap V3
  3. Use PriceTilter to calculate Flax value and tilt Flax/ETH pool liquidity by adding less Flax than the TWAP-derived amount
  4. Transfer Flax to user (Vault has sufficient Flax balance)
  5. Update TWAP oracles to maintain accurate price data

- **Withdrawal Flow** (single transaction):
  1. Withdraw LP tokens from Convex
  2. Remove liquidity from Curve, converting to input token
  3. Return original deposit amount, using surplus tokens for shortfalls or storing excess
  4. Revert if shortfall exceeds surplus and `protectLoss` is true
  5. Update TWAP oracles to maintain accurate price data

### Emergency Functionality
- Both Vault and YieldSource contracts have emergency withdrawal functions restricted to the owner
- The Vault can be put into an emergency state, preventing new deposits, claims, and migrations
- Emergency withdrawals from YieldSource first attempt to recover funds from external protocols

### sFlaxToken
- ERC20 token earned from staking Flax in another project (similar to veCRV but tradable/transferable)
- Burnable to boost Flax rewards during claims or withdrawals
- **Implementation Note**: Must implement a `burn(uint256)` function that can be called by the Vault

### Surplus/Loss Management
- Surplus tokens offset shortfalls; users bear impermanent loss/fees during migrations or withdrawals
- Migration losses are mitigated by campaigns encouraging pre-migration withdrawals

### Architecture Notes
- Each Vault supports one input token and one YieldSource (migratable)
- Contracts use `Ownable` for configuration (e.g., setting `flaxPerSFlax`, registering pairs)
- Assume Vault has sufficient Flax balance (no minting logic in scope)
- Only the Flax/ETH Uniswap V2 pair is used for price tilting
- ETH sent to PriceTilter should be used immediately for liquidity addition (no retention)

### Testing Philosophy

Tests are written using Foundry with minimal mocks (`test/mocks/Mocks.sol`) that implement only required functionality:
- Each contract has its own test file (e.g., `Vault.t.sol`, `YieldSource.t.sol`, `PriceTilterTWAP.t.sol`)
- Mocks are designed to be minimal, implementing only functions and state necessary for test cases
- Focus on isolated unit testing of each component's functionality
- New tests should follow this approach, creating or extending test files with mocks tailored to contract requirements 

#### Test Structure
- Test files are named after the contract they test (e.g., `TWAPOracle.t.sol` for `TWAPOracle.sol`)
- Mocks simulate only behavior required by corresponding test file (e.g., `MockYieldSource` only mocks `deposit`, `withdraw`, and `claimRewards`)
- Shared mocks are added to `Mocks.sol`, while test-specific mocks remain in the test file

#### Mock Requirements
- `MockERC20` must implement a `burn(uint256)` function for tokens used as sFlaxToken
- When working with Uniswap V2 pairs, ensure proper initialization of price cumulatives and reserves for TWAP calculations
- For Curve pool interactions, remember to properly approve LP tokens before attempting to remove liquidity

#### Recent Test Improvements
- Fixed `testWithdraw` in `YieldSource.t.sol` by adding proper LP token approval for the Curve pool
- Implemented a simple `MockOracle` for tests that don't need full TWAP oracle functionality
- Ensured proper setup of price cumulative values in `MockUniswapV2Pair` for TWAP oracle tests
- Implemented comprehensive slippage protection tests in `SlippageProtection.t.sol` including:
  - `testDepositWithMaximumTolerableSlippage()`: Tests deposits when swap incurs exactly the maximum tolerable slippage
  - `testRevertOnExcessiveSlippage()`: Tests that deposits revert when slippage exceeds tolerance
  - Enhanced `MockUniswapV3Router` with `setSpecificReturnAmount()` for precise control over individual swap returns
  - Fixed mock ETH handling for reward token sales and ETH-to-token swaps
  - Addressed a source code issue where `_sellEthForInputToken` doesn't send ETH with the Uniswap call

### Important Notes

- The `sFlaxToken` must implement a `burn(uint256)` function callable by the Vault
- Input tokens are immediately transferred to YieldSource after deposit (not retained in Vault)
- Emergency functionality exists in both Vault and YieldSource for security
- TWAP oracles are updated at the beginning of deposit, withdraw, and claim operations
- `testDeposit` verifies that tokens are correctly sent to the YieldSource and not retained in the Vault

