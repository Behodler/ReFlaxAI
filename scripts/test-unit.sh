#!/bin/bash

# Run unit tests only (exclude integration tests)
echo "Running unit tests..."
forge test --no-match-path "test/integration/**"

if [ $? -eq 0 ]; then
    echo "✅ Unit tests passed"
else
    echo "❌ Unit tests failed"
    exit 1
fi