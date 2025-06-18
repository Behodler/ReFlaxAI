# Formal Verification CLAUDE.md

This file provides guidance to Claude Code when working with formal verification in the ReFlax protocol.

## Overview

Formal verification for the ReFlax protocol will be implemented using Certora Prover, a tool that mathematically proves the correctness of smart contracts against specified properties.

## Workflow Rules

**CRITICAL**: Before running any formal verification, you MUST follow the workflow rules defined in `WorkflowRules.md`. Most importantly:

1. **Always run `./preFlight.sh` before submitting specs to the server**
2. Fix all syntax errors before running full verification
3. Never skip the pre-flight check - it saves time and cloud resources
4. **IMPORTANT**: When the user asks to "run formal verification", "submit verification", or "run Certora", this ALWAYS means:
   - First run `./preFlight.sh`
   - Fix any errors found
   - Only then run `./run_verification.sh`

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