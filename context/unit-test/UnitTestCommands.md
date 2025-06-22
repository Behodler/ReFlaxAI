# Unit Test Commands

## Running Unit Tests

```bash
# Run unit tests only (excludes integration tests)
./scripts/test-unit.sh

# Or directly with forge:
forge test --no-match-path "test-integration/**"
```

## Running All Tests

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

## Build Times

Note that builds can take quite long. Set a timeout of about 10-15 minutes when running tests that require compilation.