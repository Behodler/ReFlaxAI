#!/bin/bash

# Test Vault.spec only - for quick verification before submission

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "Testing Vault.spec syntax only..."
echo "==============================="

# Activate virtual environment
source certora-env/bin/activate

# Navigate to project root
cd ..

echo -e "${YELLOW}Checking Vault.spec...${NC}"

output=$(certoraRun src/vault/Vault.sol \
    src/yieldSource/CVX_CRV_YieldSource.sol \
    test/mocks/Mocks.sol:MockERC20 \
    --verify Vault:certora/specs/Vault.spec \
    --solc ~/.solc-select/artifacts/solc-0.8.20/solc-0.8.20 \
    --solc_via_ir \
    --solc_optimize 200 \
    --packages @oz_reflax=lib/oz_reflax \
    --packages @uniswap_reflax/core=lib/UniswapReFlax/core \
    --packages @uniswap_reflax/periphery=lib/UniswapReFlax/periphery \
    --packages forge-std=lib/forge-std/src \
    --packages interfaces=src/interfaces \
    --compilation_steps_only 2>&1)

echo "Output:"
echo "$output"
echo "---"

# Check for errors
if echo "$output" | grep -q -E "(Error|error:|ERROR|failed|Failed|FAILED|syntax|Syntax|unexpected|Unexpected)"; then
    echo -e "${RED}✗ VAULT.SPEC HAS ERRORS - DO NOT SUBMIT${NC}"
    exit 1
else
    echo -e "${GREEN}✓ VAULT.SPEC READY FOR SUBMISSION${NC}"
    exit 0
fi