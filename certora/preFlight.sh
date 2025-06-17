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
    local temp_contract="temp_$(basename $contract)"
    
    echo -e "\n${YELLOW}Checking $contract with $spec...${NC}"
    
    # Flatten the contract and save to temp file
    cd ..
    forge flatten "$contract" | sed 's/pragma solidity [^;]*/pragma solidity ^0.8.13/' > "certora/$temp_contract" 2>/dev/null
    cd certora
    
    output=$(certoraRun "$temp_contract:$(basename $contract .sol)" --verify "$(basename $contract .sol):$spec" --compilation_steps_only 2>&1)
    
    # Check if the output contains actual CVL syntax errors (not just contract reference errors)
    if echo "$output" | grep -q -E "(Syntax error|CVL syntax.*failed|Error in spec file.*unexpected token|methods block entries must|invariants must end|using.*statements must end)"; then
        echo -e "${RED}✗ CVL syntax errors found in $(basename $spec)${NC}"
        echo "$output"
        ((ERRORS++))
    elif echo "$output" | grep -q -E "(does not exist|Tried to register.*but.*does not exist)"; then
        echo -e "${YELLOW}⚠ Contract reference issues in $(basename $spec) (expected for syntax-only check)${NC}"
        echo -e "${GREEN}✓ CVL syntax check passed for $(basename $spec)${NC}"
    else
        echo -e "${GREEN}✓ Syntax check passed for $(basename $spec)${NC}"
    fi
    
    # Clean up temp file
    rm -f "$temp_contract"
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