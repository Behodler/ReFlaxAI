#!/bin/bash

# YieldSource Formal Verification Script
# Runs local Certora verification for YieldSource contracts

set -e

echo "Starting YieldSource formal verification..."

# Set up environment (if not already set)
if [ -z "$CERTORA" ]; then
    echo "Setting up Certora environment..."
    source /home/justin/code/CertoraProverLocal/.venv/bin/activate
    export CERTORA="$HOME/certora-build"
    export PATH="$CERTORA:$PATH"
fi

# Navigate to project root
cd /home/justin/code/BehodlerReborn/Grok/reflax

# Clean old reports (keep only 3 most recent)
cd certora/reports
ls -dt emv-* 2>/dev/null | tail -n +4 | xargs rm -rf 2>/dev/null || true
cd ..

echo "Running YieldSource verification..."

# Run verification
python $CERTORA/certoraRun.py \
    src/yieldSource/CVX_CRV_YieldSource.sol \
    test/mocks/Mocks.sol:MockERC20 \
    --verify CVX_CRV_YieldSource:specs/YieldSource.spec \
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
    --output_dir reports \
    --msg "YieldSource verification run"

echo "YieldSource verification completed!"
echo "Results available in certora/reports/"