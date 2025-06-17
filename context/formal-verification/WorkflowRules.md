# Formal Verification Workflow Rules

## Pre-Verification Requirements

### 1. Syntax Validation (MANDATORY)
Before submitting any specification to the Certora cloud server, you MUST:

1. **Run the pre-flight syntax check**:
   ```bash
   cd certora
   ./preFlight.sh
   ```

2. **Ensure all specs pass**:
   - The script will check all available spec files for syntax errors
   - ALL specs must pass before proceeding
   - If any errors are found, fix them and re-run preFlight.sh

3. **Never skip this step**:
   - Running verification without syntax checking wastes cloud resources
   - Syntax errors will cause immediate job failure on the server
   - The pre-flight check is fast and saves time in the long run

## Workflow Steps

1. **Write or modify specification** in `certora/specs/`
2. **Run pre-flight check**: `./preFlight.sh`
3. **Fix any syntax errors** identified
4. **Re-run pre-flight** until all specs pass
5. **Only then** run full verification with `./run_verification.sh`

## Adding New Specifications

When adding a new spec file:
1. Create the spec in `certora/specs/`
2. Update `preFlight.sh` to include the new spec check
3. Update `run_verification.sh` to include the new verification job
4. Test with pre-flight before committing

## Best Practices

- Always run `preFlight.sh` after any spec changes
- Keep specifications focused and modular
- Document complex invariants and rules
- Use meaningful rule names that describe what is being verified