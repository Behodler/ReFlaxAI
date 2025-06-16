#!/bin/bash

# Load environment variables
source ../.envrc

# Activate virtual environment  
source .venv/bin/activate

# Navigate to project root
cd ..

# Run Certora verification with correct Solidity compiler and all required contracts
certoraRun src/vault/Vault.sol \
    src/yieldSource/CVX_CRV_YieldSource.sol \
    test/mocks/Mocks.sol:MockERC20 \
    --verify Vault:certora/specs/Vault.spec \
    --solc ~/.solc-select/artifacts/solc-0.8.20/solc-0.8.20 \
    --solc_via_ir \
    --solc_optimize 200 \
    --disable_local_typechecking \
    --optimistic_loop \
    --loop_iter 3 \
    --packages @oz_reflax=lib/oz_reflax \
    --packages @uniswap_reflax/core=lib/UniswapReFlax/core \
    --packages @uniswap_reflax/periphery=lib/UniswapReFlax/periphery \
    --packages forge-std=lib/forge-std/src \
    --packages interfaces=src/interfaces \
    --msg "Vault formal verification run"