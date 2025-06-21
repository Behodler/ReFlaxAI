#!/bin/bash

# REAL pre-flight script that actually catches syntax errors
# Tests each spec individually with proper error detection

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "Running REAL Certora syntax checks..."
echo "=========================================="

# Activate virtual environment
source certora-env/bin/activate

# Navigate to project root  
cd ..

ERRORS=0

# Function to check a spec
check_spec() {
    local spec_name=$1
    local contracts=$2
    local verify_target=$3
    
    echo -e "\n${YELLOW}Checking $spec_name...${NC}"
    
    output=$(certoraRun $contracts \
        --verify $verify_target \
        --solc ~/.solc-select/artifacts/solc-0.8.20/solc-0.8.20 \
        --solc_via_ir \
        --solc_optimize 200 \
        --packages @oz_reflax=lib/oz_reflax \
        --packages @uniswap_reflax/core=lib/UniswapReFlax/core \
        --packages @uniswap_reflax/periphery=lib/UniswapReFlax/periphery \
        --packages forge-std=lib/forge-std/src \
        --packages interfaces=src/interfaces \
        --compilation_steps_only 2>&1)
    
    echo "Output for $spec_name:"
    echo "$output"
    echo "---"
    
    # Check for errors - be very explicit about what constitutes an error
    if echo "$output" | grep -q -E "(Error|error:|ERROR|failed|Failed|FAILED|syntax|Syntax|unexpected|Unexpected)"; then
        echo -e "${RED}✗ ERRORS FOUND in $spec_name${NC}"
        echo "$output" | grep -E "(Error|error:|ERROR|failed|Failed|FAILED|syntax|Syntax|unexpected|Unexpected)"
        ((ERRORS++))
    else
        echo -e "${GREEN}✓ $spec_name passed${NC}"
    fi
}

# Check Vault.spec
if [ -f "certora/specs/Vault.spec" ]; then
    check_spec "Vault.spec" "src/vault/Vault.sol src/yieldSource/CVX_CRV_YieldSource.sol test/mocks/Mocks.sol:MockERC20" "Vault:certora/specs/Vault.spec"
fi

# Check TWAPOracleSimple.spec (using simplified version)
if [ -f "certora/specs/TWAPOracleSimple.spec" ]; then
    check_spec "TWAPOracleSimple.spec" "src/priceTilting/TWAPOracle.sol test/mocks/Mocks.sol:MockUniswapV2Pair test/mocks/Mocks.sol:MockUniswapV2Factory" "TWAPOracle:certora/specs/TWAPOracleSimple.spec"
fi

echo -e "\n=========================================="
if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}All specs passed! Safe to submit to Certora.${NC}"
    exit 0
else
    echo -e "${RED}Found $ERRORS spec(s) with errors. DO NOT SUBMIT until fixed.${NC}"
    exit 1
fi