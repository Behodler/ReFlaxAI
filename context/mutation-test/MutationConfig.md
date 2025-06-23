# Mutation Testing Configuration

## Gambit Configuration File

Create `.gambit.yml` in the project root:

```yaml
# Gambit configuration for ReFlax Protocol
version: 1.0

# Contracts to mutate (in priority order)
contracts:
  # Critical contracts - highest priority
  - path: src/vault/Vault.sol
    operators: all
    functions:
      exclude:
        - "receive"
        - "constructor"
  
  - path: src/yieldSource/CVX_CRV_YieldSource.sol
    operators: all
    functions:
      exclude:
        - "constructor"
  
  - path: src/priceTilting/PriceTilterTWAP.sol
    operators: all
    functions:
      exclude:
        - "constructor"
  
  # High priority contracts
  - path: src/priceTilting/TWAPOracle.sol
    operators: all
    functions:
      exclude:
        - "constructor"
  
  - path: src/yieldSource/AYieldSource.sol
    operators: all
    functions:
      exclude:
        - "constructor"

# Mutation operators to apply
operators:
  arithmetic:
    enabled: true
    operators:
      - "+" → "-"
      - "-" → "+"
      - "*" → "/"
      - "/" → "*"
      - "%" → "*"
  
  comparison:
    enabled: true
    operators:
      - ">" → ">="
      - ">=" → ">"
      - "<" → "<="
      - "<=" → "<"
      - "==" → "!="
      - "!=" → "=="
  
  assignment:
    enabled: true
    operators:
      - "+=" → "-="
      - "-=" → "+="
      - "*=" → "/="
      - "/=" → "*="
  
  logical:
    enabled: true
    operators:
      - "&&" → "||"
      - "||" → "&&"
      - "!" → ""
  
  require_revert:
    enabled: true
    operators:
      - "require" → "revert"
      - remove "require"
  
  return_values:
    enabled: true
    operators:
      - "true" → "false"
      - "false" → "true"
      - "0" → "1"
      - increment numeric returns
      - decrement numeric returns

# Test execution configuration
test:
  command: "forge test"
  timeout: 180  # seconds per test
  working_directory: "."
  
  # Environment variables for tests
  environment:
    FOUNDRY_PROFILE: "default"
  
  # Continue testing even if some mutations cause compilation errors
  continue_on_error: true

# Performance settings
performance:
  parallel_threads: 4
  max_test_runs: 1000  # Stop after this many test runs
  
  # Smart test selection - only run relevant tests for each mutation
  smart_test_selection:
    enabled: true
    strategy: "function"  # Run tests that call the mutated function
  
  # Caching
  cache:
    enabled: true
    directory: ".gambit_cache"

# Reporting configuration
reporting:
  # Output formats
  formats:
    - html
    - json
    - markdown
  
  # Output directory
  output_directory: "mutation-reports"
  
  # Include source code snippets in reports
  include_source: true
  
  # Group results by
  grouping: "contract"

# Exclusions
exclude:
  # File patterns to exclude
  files:
    - "test/**"
    - "script/**"
    - "lib/**"
    - "*.t.sol"
  
  # Function patterns to exclude
  functions:
    - "test_*"
    - "_test*"
    - "setUp"
    - "receive"
    - "fallback"
    - "constructor"
  
  # Skip pure and view functions by default
  skip_pure_functions: false  # We want to test these too
  skip_view_functions: false  # Important for oracles

# Contract-specific configurations
contract_configs:
  "Vault.sol":
    # Extra attention to financial calculations
    operators:
      arithmetic:
        priority: "high"
    # Specific functions to focus on
    focus_functions:
      - "deposit"
      - "withdraw"
      - "claimRewards"
      - "calculateEffectiveDeposit"
  
  "TWAPOracle.sol":
    # Focus on time-based calculations
    operators:
      comparison:
        priority: "high"
    focus_functions:
      - "getPrice"
      - "updatePriceCumulative"
      - "_calculateTWAP"
  
  "PriceTilterTWAP.sol":
    # Critical for price manipulation
    operators:
      arithmetic:
        priority: "high"
    focus_functions:
      - "calculateFlaxFromETH"
      - "tiltFlaxTowardHigherPrice"

# Mutation testing goals
goals:
  # Minimum mutation score targets
  mutation_score:
    overall: 80
    critical_contracts: 90
    high_priority_contracts: 85
    medium_priority_contracts: 75
  
  # Maximum acceptable survived mutations
  max_survived:
    critical_functions: 0
    financial_calculations: 0
    access_control: 0

# Integration with CI/CD (for future use)
ci:
  # Fail build if mutation score drops below threshold
  fail_on_score_decrease: true
  score_decrease_threshold: 5  # percentage points
  
  # Only run on changed files in PR
  incremental: true
  
  # Store historical results
  history:
    enabled: true
    storage: "mutation-history.json"
```

## Environment-Specific Configurations

### Development Configuration
Create `.gambit.dev.yml`:
```yaml
# Development-specific overrides
extends: .gambit.yml

performance:
  parallel_threads: 2  # Use fewer resources locally
  
test:
  timeout: 300  # More lenient timeout for debugging

reporting:
  formats:
    - markdown  # Quick text output only
```

### Fast Configuration
Create `.gambit.fast.yml`:
```yaml
# Fast configuration for quick checks
extends: .gambit.yml

# Only test critical contracts
contracts:
  - path: src/vault/Vault.sol

# Only use high-impact operators
operators:
  arithmetic:
    enabled: true
  require_revert:
    enabled: true
  # Disable others for speed
  comparison:
    enabled: false
  assignment:
    enabled: false
  logical:
    enabled: false

performance:
  smart_test_selection:
    enabled: true
    strategy: "aggressive"  # Only run most relevant tests
```

## Usage Examples

### Basic Usage
```bash
# Use default configuration
gambit --config .gambit.yml

# Use development configuration
gambit --config .gambit.dev.yml

# Quick check with fast configuration
gambit --config .gambit.fast.yml
```

### Override Configuration
```bash
# Override timeout
gambit --config .gambit.yml --timeout 60

# Override parallel threads
gambit --config .gambit.yml --threads 8

# Test specific contract only
gambit --config .gambit.yml --contract src/vault/Vault.sol
```

## Maintenance

### Weekly Tasks
1. Review survived mutations in critical contracts
2. Update focus_functions based on new features
3. Adjust timeouts based on test performance

### Monthly Tasks
1. Analyze mutation score trends
2. Review and update operator configurations
3. Clean up cache directory

### Per Release
1. Run full mutation testing suite
2. Document any new equivalent mutations
3. Update mutation score baselines
4. Archive mutation reports