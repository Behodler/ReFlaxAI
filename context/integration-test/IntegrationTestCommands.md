# Integration Test Commands

## Running Integration Tests

```bash
# First, allow direnv to load environment variables
direnv allow

# Run integration tests (uses RPC URL from .envrc)
./scripts/test-integration.sh

# Or directly with forge:
forge test --profile integration -f $RPC_URL -vvv
```

## Important Notes

- Integration tests use a separate profile defined in `foundry.toml` with the `test-integration` directory and require an Arbitrum fork
- The project uses `direnv` to manage environment variables. Always run `direnv allow` before running integration tests to load the RPC_URL from `.envrc`
- Integration tests may take longer due to RPC calls to forked Arbitrum mainnet
- Use `-vvv` flag for detailed output when debugging integration tests

## Build Times

Set timeout to 15 minutes when running integration tests due to both compilation and RPC interaction times.