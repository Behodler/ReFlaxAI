#!/bin/bash

# Pre-flight syntax check for Certora specifications
# This script checks for syntax errors before sending verification jobs to the server

# Ensure we're in the certora directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "Running Certora pre-flight syntax checks..."
echo "=========================================="

# Activate virtual environment if it exists
if [ -f "./certora-env/bin/activate" ]; then
    source ./certora-env/bin/activate
else
    echo -e "${RED}Error: Virtual environment not found!${NC}"
    echo "Please run: python3 -m venv certora-env && source certora-env/bin/activate && pip install certora-cli"
    exit 1
fi

# Check if certoraRun is available
if ! command -v certoraRun &> /dev/null; then
    echo -e "${RED}Error: certoraRun command not found!${NC}"
    echo "Please ensure certora-cli is installed in the virtual environment"
    exit 1
fi

# Initialize error counter
ERRORS=0

# Function to check a spec file
check_spec() {
    local contract=$1
    local spec=$2
    
    echo -e "\n${YELLOW}Checking $contract with $spec...${NC}"
    
    # Run certoraRun from project root with proper paths
    cd ..
    output=$(certoraRun "$contract" \
        test/mocks/Mocks.sol:MockERC20 \
        --verify "$(basename $contract .sol):certora/$spec" \
        --solc ~/.solc-select/artifacts/solc-0.8.20/solc-0.8.20 \
        --packages @oz_reflax=lib/oz_reflax \
        --packages @uniswap_reflax/core=lib/UniswapReFlax/core \
        --packages @uniswap_reflax/periphery=lib/UniswapReFlax/periphery \
        --packages forge-std=lib/forge-std/src \
        --packages interfaces=src/interfaces \
        --compilation_steps_only 2>&1)
    cd certora
    
    # Check if the output contains any errors
    if echo "$output" | grep -q -E "(Error|error|failed|Failed)"; then
        echo -e "${RED}✗ Errors found in $(basename $spec):${NC}"
        echo "$output"
        ((ERRORS++))
        
        # Also save detailed errors for debugging
        echo "$output" > "debugging/$(basename $spec .spec)_errors.log"
    else
        echo -e "${GREEN}✓ Syntax check passed for $(basename $spec)${NC}"
    fi
}

# Check all available specs
if [ -f "specs/Vault.spec" ]; then
    check_spec "../src/vault/Vault.sol" "specs/Vault.spec"
fi

if [ -f "specs/YieldSource.spec" ]; then
    check_spec "../src/yieldSource/YieldSource.sol" "specs/YieldSource.spec"
fi

if [ -f "specs/PriceTilter.spec" ]; then
    check_spec "../src/priceTilting/PriceTilterTWAP.sol" "specs/PriceTilter.spec"
fi

if [ -f "specs/TWAPOracle.spec" ]; then
    check_spec "../src/priceTilting/TWAPOracle.sol" "specs/TWAPOracle.spec"
fi

# Clean up any remaining temp files
rm -f temp_*.sol

# Summary
echo -e "\n=========================================="
if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}All syntax checks passed! Safe to run verification.${NC}"
    exit 0
else
    echo -e "${RED}Found $ERRORS spec(s) with syntax errors. Please fix before running verification.${NC}"
    exit 1
fi