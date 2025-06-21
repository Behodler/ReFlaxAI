#!/bin/bash

# Local Certora Verification Script
# This script runs Certora verification locally with proper setup

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Setting up local Certora environment...${NC}"

# Save current directory
ORIGINAL_DIR=$(pwd)

# Navigate to project root
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR/.."

# Set up Certora environment
source /home/justin/code/CertoraProverLocal/.venv/bin/activate
export CERTORA="$HOME/certora-build"
export PATH="$CERTORA:$PATH"

echo -e "${GREEN}Environment set up successfully${NC}"

# Clean old reports (keep last 3)
echo -e "${YELLOW}Cleaning old reports...${NC}"
cd certora/reports
if ls emv-* 1> /dev/null 2>&1; then
    ls -dt emv-* 2>/dev/null | tail -n +4 | xargs rm -rf 2>/dev/null || true
fi
cd ../..

# Run verification
echo -e "${YELLOW}Running local Certora verification...${NC}"
echo -e "${YELLOW}Reports will be saved in: certora/reports/${NC}"

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
    --msg "Local verification run - $(date '+%Y-%m-%d %H:%M:%S')"

# Find the most recent report directory
LATEST_REPORT=$(ls -dt certora/reports/emv-* 2>/dev/null | head -1)

if [ -n "$LATEST_REPORT" ]; then
    echo -e "${GREEN}Verification complete!${NC}"
    echo -e "${GREEN}Results available at: ${LATEST_REPORT}/Reports/FinalResults.html${NC}"
else
    echo -e "${RED}Warning: Could not find report directory${NC}"
fi

# Return to original directory
cd "$ORIGINAL_DIR"