# Formal Verification Workflow Rules

## Pre-Verification Requirements

### 1. Environment Setup (MANDATORY)
Before running any formal verification commands:

1. **Navigate to correct directory**:
   ```bash
   cd certora  # All verification commands must be run from here
   ```

2. **Ensure CERTORAKEY is available**:
   ```bash
   # Option 1: If .envrc exists in parent directory
   source ../.envrc
   
   # Option 2: Export directly
   export CERTORAKEY=<your_certora_key>
   
   # Option 3: Inline with verification command
   export CERTORAKEY=<key> && ./run_verification.sh
   ```

### 2. Syntax Validation (MANDATORY)
Before submitting any specification to the Certora cloud server, you MUST:

1. **Run the pre-flight syntax check**:
   ```bash
   ./preFlight.sh  # Must be run from certora/ directory
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

1. **Navigate to certora directory**: `cd certora`
2. **Ensure CERTORAKEY is set** (see Environment Setup above)
3. **Write or modify specification** in `specs/`
4. **Run pre-flight check**: `./preFlight.sh`
5. **Fix any syntax errors** identified
6. **Re-run pre-flight** until all specs pass
7. **Only then** run full verification with `export CERTORAKEY=<key> && ./run_verification.sh`

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