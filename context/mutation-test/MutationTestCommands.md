# Mutation Testing Commands Reference

## Installation

### Prerequisites
- Python 3.8+ installed
- Solidity 0.8.13 (required by Gambit)
- Foundry installed and configured

### Install Gambit
```bash
# Install via pip
pip install gambit-tools

# Verify installation
gambit --version

# Install specific version (recommended for consistency)
pip install gambit-tools==0.4.0
```

## Basic Commands

### Generate Mutations
```bash
# Mutate a single contract
gambit mutate --contract src/vault/Vault.sol

# Mutate multiple contracts
gambit mutate --contract src/vault/Vault.sol --contract src/yieldSource/CVX_CRV_YieldSource.sol

# Mutate with specific operators
gambit mutate --contract src/vault/Vault.sol --operators arithmetic,require

# Generate mutations without testing (preview mode)
gambit mutate --contract src/vault/Vault.sol --dry-run
```

### Run Mutation Testing
```bash
# Basic mutation testing
gambit test

# With specific test framework
gambit test --test-command "forge test"

# With timeout per test
gambit test --timeout 120

# Parallel execution
gambit test --threads 4

# Continue after failures
gambit test --continue-on-failure
```

### Analyze Results
```bash
# View summary
gambit summary

# Generate HTML report
gambit report --format html --output mutation-report.html

# Export results as JSON
gambit report --format json --output results.json

# Show only survived mutations
gambit summary --show-survived
```

## Advanced Usage

### Configuration File
Create `.gambit.yml` in project root:
```yaml
# Gambit configuration
contracts:
  - src/vault/Vault.sol
  - src/yieldSource/CVX_CRV_YieldSource.sol
  - src/priceTilting/PriceTilterTWAP.sol
  - src/priceTilting/TWAPOracle.sol

operators:
  - arithmetic
  - comparison
  - require
  - assignment
  - return

test_command: "forge test"
timeout: 180
threads: 4

exclude_functions:
  - ".*_view$"
  - "^get.*"

exclude_files:
  - "test/**"
  - "script/**"
```

### Contract-Specific Testing
```bash
# Test only Vault mutations
gambit test --filter "Vault.sol"

# Test specific function mutations
gambit test --filter "Vault.sol:deposit"

# Exclude certain mutations
gambit test --exclude-filter "test_"
```

### Performance Optimization
```bash
# Use snapshot testing for faster runs
forge snapshot
gambit test --use-snapshot

# Skip compilation
gambit test --skip-compile

# Run only high-impact mutations
gambit mutate --impact high
gambit test
```

## Integration with Foundry

### Setup Test Script
Create `scripts/mutation-test.sh`:
```bash
#!/bin/bash
set -e

echo "Running mutation tests for ReFlax..."

# Clean previous results
rm -rf .gambit/
rm -f gambit_results.json

# Generate mutations
echo "Generating mutations..."
gambit mutate --config .gambit.yml

# Run tests
echo "Running mutation tests..."
gambit test --test-command "forge test" --threads 4 --timeout 180

# Generate report
echo "Generating report..."
gambit report --format html --output reports/mutation-report.html

echo "Mutation testing complete. Report: reports/mutation-report.html"
```

### Forge-Specific Commands
```bash
# Run with specific forge profile
gambit test --test-command "forge test --profile default"

# With gas reporting
gambit test --test-command "forge test --gas-report"

# Match specific tests
gambit test --test-command "forge test --match-contract VaultTest"
```

## Debugging

### View Mutation Details
```bash
# List all mutations
gambit list-mutations

# Show specific mutation
gambit show-mutation --id 42

# View mutated source
gambit show-mutant --id 42
```

### Test Single Mutation
```bash
# Apply specific mutation and test
gambit apply-mutation --id 42
forge test
gambit revert-mutation --id 42
```

### Logs and Artifacts
```bash
# View test logs
cat .gambit/test.log

# Check mutation application log
cat .gambit/mutations.log

# Archive results
tar -czf mutation-results-$(date +%Y%m%d).tar.gz .gambit/ gambit_results.json
```

## Common Issues and Solutions

### Issue: Tests timeout
```bash
# Increase timeout
gambit test --timeout 300

# Or reduce test scope
gambit test --test-command "forge test --match-contract VaultTest"
```

### Issue: Out of memory
```bash
# Reduce parallel threads
gambit test --threads 2

# Or test contracts separately
gambit mutate --contract src/vault/Vault.sol
gambit test
```

### Issue: Compilation errors with mutations
```bash
# Skip problematic operators
gambit mutate --skip-operators delete-statement

# Or exclude specific functions
gambit mutate --exclude-function "receive|fallback"
```

## Continuous Integration

### GitHub Actions Example
```yaml
- name: Run Mutation Tests
  run: |
    pip install gambit-tools==0.4.0
    gambit mutate --contract src/vault/Vault.sol
    gambit test --test-command "forge test" --timeout 180
    gambit summary --fail-on-survived --threshold 80
```

### Pre-commit Hook
```bash
#!/bin/bash
# .git/hooks/pre-commit

# Run mutation tests on changed contracts
changed_contracts=$(git diff --cached --name-only | grep "^src/.*\.sol$")

if [ ! -z "$changed_contracts" ]; then
  echo "Running mutation tests on changed contracts..."
  for contract in $changed_contracts; do
    gambit mutate --contract $contract
    gambit test --filter $(basename $contract)
  done
fi
```

## Quick Reference

| Command | Purpose |
|---------|---------|
| `gambit mutate` | Generate mutations |
| `gambit test` | Run mutation testing |
| `gambit summary` | View results summary |
| `gambit report` | Generate detailed report |
| `gambit list-mutations` | List all mutations |
| `gambit show-mutation --id N` | Show specific mutation |
| `gambit clean` | Clean mutation artifacts |