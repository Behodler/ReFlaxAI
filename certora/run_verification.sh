#!/bin/bash

# Ensure we're in the certora directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

# Activate virtual environment  
source certora-env/bin/activate

# Navigate to project root for the verification
cd ..

# Run Certora verification with the necessary contracts
certoraRun src/vault/Vault.sol \
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
    --smt_timeout 3600 \
    --msg "Vault formal verification with optimized recursion settings"