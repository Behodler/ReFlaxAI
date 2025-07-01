#!/bin/bash

# ReFlax Local Deployment with Address Server
# This script deploys contracts and starts the Express server

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== ReFlax Local Deployment with Address Server ===${NC}"
echo ""

# Check if Anvil is running
if ! curl -s -X POST -H "Content-Type: application/json" \
     --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
     "http://localhost:8545" > /dev/null 2>&1; then
    echo -e "${YELLOW}[WARNING]${NC} Anvil not running on localhost:8545"
    echo "Please start Anvil in another terminal: anvil --host 0.0.0.0 --port 8545"
    exit 1
fi

# Install npm dependencies if needed
if [ ! -d "node_modules" ]; then
    echo -e "${BLUE}[INFO]${NC} Installing npm dependencies..."
    npm install
fi

# Deploy contracts
echo -e "${BLUE}[INFO]${NC} Deploying contracts to local Anvil..."
export PRIVATE_KEY="0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"  # Anvil account 0
forge script scripts/DeployLocal.s.sol:LocalDeploymentScript --rpc-url http://localhost:8545 --broadcast --ffi

# Check if deployment was successful
if [ -f "scripts/deployedAddresses.json" ]; then
    echo -e "${GREEN}[SUCCESS]${NC} Contracts deployed successfully!"
    echo ""
    echo -e "${BLUE}[INFO]${NC} Starting address server..."
    echo ""
    # Start the Express server
    node scripts/addressServer.js
else
    echo -e "${YELLOW}[ERROR]${NC} Deployment failed - no address file created"
    exit 1
fi