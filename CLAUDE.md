# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Workflow Rules
- For feature development workflow rules, see `context/feature/WorkflowRules.md`
- For unit testing guidelines, see `context/unit-test/`
- For integration testing guidelines, see `context/integration-test/`
- For formal verification workflow rules, see `context/formal-verification/WorkflowRules.md`
- When implementing new features or making significant architectural changes, proactively update relevant sections of this CLAUDE.md file

## Conventions
- When asked to look at a markdown file, if someone says "do" or "execute" an item on a list, it means do the programming task it describes
- If a markdown file is mentioned without giving a location, look first in the appropriate subdirectory under context/ based on the task type, then in the root context/, then in the root of this project

## Calibrations
This section is for variables to keep in mind at all times and will be presented as a list.
1. Build times. Whenever compiling, set the timeout to 15 minutes. This is for tests, builds, compiles and anything else that invokes solc.

## Common Development Commands

### Building
```bash
forge build
```
Note that builds can take quite long. Set a timeout of about 10 minutes.

### Running Tests

Tests are organized into unit tests and integration tests that can be run independently:

#### Testing

- **Unit Tests**: See `context/unit-test/UnitTestCommands.md` for commands and guidelines
- **Integration Tests**: See `context/integration-test/IntegrationTestCommands.md` for setup and commands
- **Test Results**: All test results are tracked in `context/TestLog.md`

### Linting/Type Checking
No specific linting commands found. Solidity compilation errors will be caught by `forge build`.

### Formal Verification
```bash
cd certora
# ALWAYS run preflight checks first to catch syntax errors
./preFlight.sh
# Only run verification if preflight passes - must export CERTORAKEY if not in environment
export CERTORAKEY=<your_key> && ./run_verification.sh
```
**CRITICAL WORKFLOW**: Always run `./preFlight.sh` before `./run_verification.sh` to catch CVL syntax errors locally. Never skip the preflight check as it saves time and cloud resources.

**IMPORTANT SETUP NOTES**:
- **Directory**: All formal verification commands must be run from the `certora/` directory
- **Environment Variables**: Ensure CERTORAKEY is set. If .envrc exists with the key, use `source ../.envrc` or export directly
- **Common Issues**: 
  - Running from wrong directory will cause "file not found" errors
  - Missing CERTORAKEY will cause "does not contain a Certora key" error
  - Use `export CERTORAKEY=<key> && ./run_verification.sh` if environment variables aren't accessible

Note: Certora CLI requires Python virtual environment setup and a Certora key. See `certora/` directory for setup scripts.

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

### Testing Documentation

- **Unit Testing**: Complete guidelines, philosophy, and mock requirements in `context/unit-test/UnitTestGuidelines.md`
- **Integration Testing**: Implementation guide and test coverage tracking in `context/integration-test/`
- **Formal Verification**: Certora Prover setup and specifications in `context/formal-verification/`

### Important Notes

- The `sFlaxToken` must implement a `burn(uint256)` function callable by the Vault
- Input tokens are immediately transferred to YieldSource after deposit (not retained in Vault)
- Emergency functionality exists in both Vault and YieldSource for security
- TWAP oracles are updated at the beginning of deposit, withdraw, and claim operations
- `testDeposit` verifies that tokens are correctly sent to the YieldSource and not retained in the Vault

