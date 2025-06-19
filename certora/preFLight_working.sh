#!/bin/bash

# Working pre-flight script that actually catches syntax errors
# This script runs the exact same command as run_verification.sh but with --check_syntax flag

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "Running REAL Certora syntax check..."
echo "=========================================="

# Activate virtual environment
source certora-env/bin/activate

# Navigate to project root
cd ..

echo -e "${YELLOW}Checking Vault.spec syntax...${NC}"

# Run the exact certoraRun command with syntax check only
output=$(certoraRun src/vault/Vault.sol \
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
    --disable_local_typechecking \
    --packages @oz_reflax=lib/oz_reflax \
    --packages @uniswap_reflax/core=lib/UniswapReFlax/core \
    --packages @uniswap_reflax/periphery=lib/UniswapReFlax/periphery \
    --packages forge-std=lib/forge-std/src \
    --packages interfaces=src/interfaces \
    --compilation_steps_only 2>&1)

echo "Full output:"
echo "$output"

# Check for any errors
if echo "$output" | grep -q -i "error"; then
    echo -e "\n${RED}✗ ERRORS FOUND - DO NOT SUBMIT TO CERTORA${NC}"
    echo "$output" | grep -i "error"
    exit 1
else
    echo -e "\n${GREEN}✓ No syntax errors found - Safe to submit${NC}"
    exit 0
fi