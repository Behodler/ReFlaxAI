# Formal Verification CLAUDE.md

This file provides guidance to Claude Code when working with formal verification in the ReFlax protocol.

## Overview

Formal verification for the ReFlax protocol is implemented using Certora Prover, which mathematically proves the correctness of smart contracts against specified properties. We use both local and cloud verification, with local being the primary workflow.

## Workflow Rules

**CRITICAL**: Before running any formal verification, you MUST follow the workflow rules defined in `WorkflowRules.md`. Most importantly:

1. **Always run `./preFlight.sh` before running any verification**
2. Fix all syntax errors before running full verification
3. Never skip the pre-flight check - it saves time and resources
4. **IMPORTANT**: When the user asks to "run formal verification", "submit verification", or "run Certora", this ALWAYS means:
   - First run `./preFlight.sh`
   - Fix any errors found
   - Then run local verification (see below)
   - Only submit to cloud if explicitly requested

## Local Verification Workflow

### Setup (Required for Each Session)
```bash
# Navigate to project root
cd /home/justin/code/BehodlerReborn/Grok/reflax

# Set up Certora local environment
source /home/justin/code/CertoraProverLocal/.venv/bin/activate
export CERTORA="$HOME/certora-build"
export PATH="$CERTORA:$PATH"
```

### Running Local Verification
```bash
# After setup, run verification with output to certora/reports
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
    --msg "Local verification run"
```

### Report Management
1. **Output Directory**: All reports are generated in `certora/reports/` (gitignored)
2. **Report Structure**: Each run creates a directory like `emv-X-certora-YY-MMM--HH-MM/`
3. **Key Files**:
   - `FinalResults.html` - Main results summary
   - `Results.txt` - Text version of results
   - Individual rule reports in the Reports subdirectory

### Maintenance Rules
Before running new verification:
```bash
# Navigate to reports directory
cd certora/reports

# Keep only the 3 most recent reports
ls -dt emv-* | tail -n +4 | xargs rm -rf 2>/dev/null || true

# Or clean all old reports if starting fresh
rm -rf emv-* 2>/dev/null || true
```

## Complete Workflow Example

```bash
# 1. Navigate to certora directory for preflight
cd certora
./preFlight.sh

# 2. Fix any syntax errors identified

# 3. Run local verification using the provided script
./run_local_verification.sh

# 4. Review results
# Reports will be in reports/emv-*/Reports/FinalResults.html
```

## Alternative Manual Approach

If you prefer to run verification manually:

```bash
# 1. Set up environment (from project root)
source /home/justin/code/CertoraProverLocal/.venv/bin/activate
export CERTORA="$HOME/certora-build"
export PATH="$CERTORA:$PATH"

# 2. Clean old reports (optional)
cd certora && rm -rf reports/emv-* 2>/dev/null || true && cd ..

# 3. Run verification with full command
python $CERTORA/certoraRun.py [... full command as above ...]
```

## When to Use Cloud Verification

Only submit to Certora cloud when:
1. User explicitly requests cloud verification
2. Need to share results with external parties
3. Local verification shows unexpected behavior
4. Final verification before deployment

For cloud submission, use the existing workflow:
```bash
cd certora
export CERTORAKEY=<key> && ./run_verification.sh
```

See `WorkflowRules.md` for complete workflow requirements.

## Planned Approach

We will use Certora Prover to:
- Verify critical invariants in the protocol
- Prove that user funds cannot be lost
- Ensure mathematical correctness of reward calculations
- Validate state transitions in the Vault and YieldSource contracts

## Status

Formal verification setup is in progress. The Certora CLI has been installed and a pre-flight syntax checking script has been created.

## Project Structure

Following Certora's conventions, formal verification files will be organized in the project root:
- `certora/` - Main directory for Certora Prover files
  - `specs/` - Specification files (`.spec`) defining properties to verify
  - `harness/` - Harness contracts if needed for verification
  - `conf/` - Configuration files for Certora Prover runs
  - `scripts/` - Scripts for running verification

This context directory (`context/formal-verification/`) will contain:
- Documentation of verification approach and strategy
- Summaries of verified properties and their implications
- Notes on assumptions and limitations
- Results and reports from verification runs

## Getting Started (Future)

When ready to begin formal verification:
1. Create the `certora/` directory structure in the project root
2. Install Certora Prover CLI tools
3. Write specification files in `certora/specs/`
4. Configure verification runs in `certora/conf/`
5. Document approach and results in this context directory

## Resources

- Certora Prover documentation: https://docs.certora.com/
- Best practices: https://docs.certora.com/en/latest/docs/user-guide/best-practices.html
- Example projects: https://github.com/Certora/Examples