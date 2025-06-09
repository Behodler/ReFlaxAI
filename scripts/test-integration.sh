#!/bin/bash

# Check if RPC_URL is set
if [ -z "$RPC_URL" ]; then
    echo "❌ Error: RPC_URL environment variable is not set"
    echo "Please set RPC_URL to your Arbitrum node endpoint"
    exit 1
fi

# Run integration tests with Arbitrum fork
echo "Running integration tests with Arbitrum fork..."
echo "RPC URL: $RPC_URL"

forge test --profile integration -f $RPC_URL -vvv

if [ $? -eq 0 ]; then
    echo "✅ Integration tests passed"
else
    echo "❌ Integration tests failed"
    exit 1
fi