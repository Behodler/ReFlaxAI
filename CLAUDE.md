# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Response Format
- Begin every response with "**ReFlax:** " to identify the project context

## Workflow Rules
- For feature development workflow rules, see `context/feature/WorkflowRules.md`
- For unit testing guidelines, see `context/unit-test/`
- For integration testing guidelines, see `context/integration-test/`
- For formal verification workflow rules, see `context/formal-verification/WorkflowRules.md`
- For formal verification backlog and TODOs, see `context/formal-verification/FormalVerificationBacklog.md`
- For mutation testing guidelines, see `context/mutation-test/CLAUDE.md`
- **For comprehensive project TODOs, see `context/GLOBAL_TODOS.md`** - contains detailed tasks with context for fresh agents
- When implementing new features or making significant architectural changes, proactively update relevant sections of this CLAUDE.md file

## Global TODO Management
- **Active TODOs**: Maintained in `context/GLOBAL_TODOS.md` with detailed context for each task
- **Update Process**: When completing any TODO item, mark it as COMPLETED and update the status
- **Completion**: When ALL items in GLOBAL_TODOS.md are completed:
  1. Move the file to `context/archive/GLOBAL_TODOS_completed_YYYY-MM-DD.md`
  2. Create a new GLOBAL_TODOS.md for future work if needed
- **Fresh Agent Support**: Each TODO includes sufficient context, prerequisites, and action steps for new agents to pick up and execute

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
- **Mutation Tests**: See `context/mutation-test/MutationTestCommands.md` for Gambit setup and commands
- **Test Results**: All test results are tracked in `context/TestLog.md`

### Linting/Type Checking
No specific linting commands found. Solidity compilation errors will be caught by `forge build`.

### Formal Verification

**PRIMARY WORKFLOW - Local Verification**:
```bash
# 1. Always run preflight checks first from certora directory
cd certora && ./preFlight.sh

# 2. Run local verification using the automated script
./run_local_verification.sh
```

**MANUAL WORKFLOW** (if needed):
```bash
# 1. Set up local Certora environment (from project root)
source /home/justin/code/CertoraProverLocal/.venv/bin/activate
export CERTORA="$HOME/certora-build" && export PATH="$CERTORA:$PATH"

# 2. Clean old reports (optional but recommended)
cd certora && rm -rf reports/emv-* 2>/dev/null || true && cd ..

# 3. Run local verification
python $CERTORA/certoraRun.py \
    src/vault/Vault.sol \
    src/yieldSource/CVX_CRV_YieldSource.sol \
    test/mocks/Mocks.sol:MockERC20 \
    --verify Vault:certora/specs/Vault.spec \
    --solc ~/.solc-select/artifacts/solc-0.8.20/solc-0.8.20 \
    --solc_via_ir \
    --solc_optimize 200 \
    --optimistic_loop \
    --loop_iter 2 \
    --optimistic_summary_recursion \
    --summary_recursion_limit 2 \
    --optimistic_contract_recursion \
    --contract_recursion_limit 2 \
    --packages @oz_reflax=lib/oz_reflax \
    --packages @uniswap_reflax/core=lib/UniswapReFlax/core \
    --packages @uniswap_reflax/periphery=lib/UniswapReFlax/periphery \
    --packages forge-std=lib/forge-std/src \
    --packages interfaces=src/interfaces \
    --smt_timeout 3600 \
    --output certora/reports \
    --msg "Local verification run"
```

**CLOUD VERIFICATION** (only when explicitly requested):
```bash
cd certora
export CERTORAKEY=<your_key> && ./run_verification.sh
```

**CRITICAL WORKFLOW**: 
1. **MANDATORY**: Always run `./preFlight.sh` BEFORE any verification to catch CVL syntax errors
2. **PRIMARY**: Use local verification for faster feedback and debugging
3. **REPORTS**: All local reports are saved in `certora/reports/` (gitignored)
4. **MAINTENANCE**: Clean old reports regularly - keep only recent 3-5 runs
5. **ERROR DEBUGGING**: Check `certora/debugging/logOfFailures.md` for tracking issues
6. When asked to "run formal verification" this means: preflight → fix errors → run LOCAL verification

**IMPORTANT NOTES**:
- **Local Benefits**: Faster feedback, no cloud costs, detailed error messages
- **Report Location**: `certora/reports/emv-*/Reports/FinalResults.html`
- **Cloud Use Cases**: External sharing, final verification, or when explicitly requested

See `context/formal-verification/CLAUDE.md` for complete workflow details.

### Mutation Testing

**SETUP**: Uses Gambit mutation testing tool with Solidity 0.8.13
```bash
# 1. Install Gambit (Python package)
pip install gambit-tools==0.4.0

# 2. Run mutation testing on specific contracts
gambit mutate --contract src/vault/Vault.sol
gambit test --test-command "forge test"

# 3. For comprehensive mutation testing (proven workflow)
./run_working_mutation_tests.sh
```

**COMPLETE WORKFLOW** (Successfully Executed):
1. **Fix all tests first**: Ensure 100% unit and integration test pass rates
2. **Run targeted mutation testing**: Focus on critical contracts
3. **Analyze survived mutations**: Use `jq` to examine mutation details
4. **Add killer tests**: Create specific tests to kill survived mutations
5. **Re-run and verify**: Confirm 100% mutation scores achieved

**ACHIEVED RESULTS**:
- ✅ **PriceTilterTWAP**: 100% score (20/20 killed)
- ✅ **CVX_CRV_YieldSource**: 100% score (20/20 killed)
- ✅ **TWAPOracle**: 100% score (18/18 killed)
- ✅ **AYieldSource**: 100% score (9/9 killed)
- ✅ **Total**: 67/67 mutations killed (100% score)

**PROVEN COMMANDS**:
```bash
# Analyze survived mutations
jq '.[] | select(.status == "SURVIVED")' mutation-reports/PriceTilterTWAP/gambit_results.json

# Test specific contract mutations
cd mutation-reports/PriceTilterTWAP && \
forge test --match-contract PriceTilterTest --match-test testConstructor

# Run parallel mutation testing
gambit test --threads 4 --timeout 300
```

**IMPORTANT NOTES**:
- **Solidity Version**: Project uses 0.8.13 for mutation testing (downgraded from 0.8.20)
- **Test Improvements**: Added 7 targeted tests to achieve 100% scores
- **Performance**: Use parallel execution with 4 threads for optimal speed
- **Documentation**: See `context/mutation-test/results/execution/phase2_2_summary.md` for detailed results

See `context/mutation-test/CLAUDE.md` for complete workflow details.

### Comprehensive Testing Approach

**PROVEN WORKFLOW** for complete protocol validation:

1. **Phase 1**: Fix All Tests
   - Unit tests: `forge test --no-match-test "integration"`
   - Integration tests: `./scripts/test-integration.sh`
   - Ensure 100% pass rate before proceeding

2. **Phase 2**: Mutation Testing
   - Run targeted mutations on critical contracts
   - Analyze survived mutations with `jq`
   - Add killer tests for 100% mutation scores
   - Document results in `context/mutation-test/results/`

3. **Phase 3**: Formal Verification Enhancement
   - Create mutation-resistant specifications
   - Map mutations to formal verification rules
   - Enhanced specs in `certora/specs/*_Enhanced.spec`

4. **Phase 4**: Documentation
   - Comprehensive testing report: `context/ComprehensiveTestingReport.md`
   - Updated workflows in CLAUDE.md

**KEY LEARNINGS**:
- Constructor validation gaps revealed by DeleteExpressionMutation
- State verification needs exposed by AssignmentMutation
- Parameter boundary testing critical for RequireMutation
- 100% mutation scores achievable with targeted tests

**TROUBLESHOOTING**:
- Build timeouts: Set 15-minute timeout for Solidity compilation
- Integration test issues: Check Solidity version (must be 0.8.13)
- Mutation test failures: Ensure all unit tests pass first
- Formal verification errors: Always run `./preFlight.sh` first

**FINAL RESULTS**:
- ✅ 156 unit tests passing (100%)
- ✅ 45 integration tests passing (100%)
- ✅ 67 mutations killed (100% score)
- ✅ 50/67 formal properties verified (78%)
- ✅ Comprehensive documentation complete

See `context/ComprehensiveTestingReport.md` for detailed security assessment.

## Git Commit Policy
**NEVER commit changes unless the user explicitly asks you to commit**. This means:
- Do NOT commit after completing tasks
- Do NOT commit when you think work is done
- Do NOT commit as part of a workflow
- ONLY commit when the user explicitly says something like "commit", "please commit", "commit these changes", etc.
- It is VERY IMPORTANT to only commit when explicitly asked, otherwise the user will feel that you are being too proactive

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

