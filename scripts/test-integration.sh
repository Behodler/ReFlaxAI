#!/bin/bash

# Function to show usage
show_usage() {
    echo "Usage: $0 [TEST_PATTERN]"
    echo ""
    echo "Run integration tests with optional pattern filtering"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Run all integration tests"
    echo "  $0 MultiToken                        # Run tests matching 'MultiToken'"
    echo "  $0 --match-contract MultiTokenSimple # Run specific contract tests"
    echo "  $0 --match-path test-integration/yieldSource/MultiTokenSimple.integration.t.sol"
    echo "  $0 --match-test testSlippageCalculations"
    echo ""
    echo "Any forge test arguments are supported (--match-contract, --match-path, --match-test, etc.)"
}

# Check for help flag
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    show_usage
    exit 0
fi

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

# Build forge test command
FORGE_CMD="FOUNDRY_PROFILE=integration forge test -f $RPC_URL -vvv"

# Add test pattern if provided
if [ $# -gt 0 ]; then
    # If first argument doesn't start with --, treat it as a simple pattern match
    if [[ "$1" != --* ]]; then
        FORGE_CMD="$FORGE_CMD --match-test $1"
        TEST_DESC="tests matching '$1'"
    else
        # Pass all arguments directly to forge test
        FORGE_CMD="$FORGE_CMD $@"
        TEST_DESC="tests with pattern: $@"
    fi
else
    TEST_DESC="all integration tests"
fi

# Run integration tests with Arbitrum fork
echo "Running $TEST_DESC..."
echo "RPC URL: $RPC_URL"
echo "Command: $FORGE_CMD"
echo ""

eval $FORGE_CMD

if [ $? -eq 0 ]; then
    echo "✅ Integration tests passed"
else
    echo "❌ Integration tests failed"
    exit 1
fi