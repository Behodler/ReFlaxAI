#!/bin/bash

# Load direnv if .envrc exists
if [ -f ".envrc" ]; then
    # Source direnv hook
    eval "$(direnv export bash 2>/dev/null)"
fi

# Check if RPC_URL is set
if [ -z "$RPC_URL" ]; then
    echo "❌ Error: RPC_URL environment variable is not set"
    echo ""
    echo "Please ensure you have:"
    echo "1. Created a .envrc file with: export RPC_URL=your_arbitrum_rpc_url"
    echo "2. Run: direnv allow"
    echo ""
    exit 1
fi

# Run integration tests with Arbitrum fork
echo "Running integration tests with Arbitrum fork..."
echo "RPC URL: $RPC_URL"

FOUNDRY_PROFILE=integration forge test -f $RPC_URL -vvv

if [ $? -eq 0 ]; then
    echo "✅ Integration tests passed"
else
    echo "❌ Integration tests failed"
    exit 1
fi