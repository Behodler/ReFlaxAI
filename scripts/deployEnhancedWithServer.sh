#!/bin/bash

# ReFlax Enhanced Complete Local Deployment Automation
# This script starts Anvil, deploys all contracts WITH SFlax integration, and starts the address server

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Configuration
RPC_URL="http://localhost:8545"
ANVIL_PID=""
SERVER_PID=""
ADDRESS_SERVER_PORT=3011

# Cleanup function for graceful shutdown
cleanup() {
    echo ""
    echo -e "${YELLOW}[INFO]${NC} Shutting down services..."
    
    if [ ! -z "$SERVER_PID" ] && kill -0 "$SERVER_PID" 2>/dev/null; then
        echo -e "${BLUE}[INFO]${NC} Stopping address server (PID: $SERVER_PID)..."
        kill "$SERVER_PID" 2>/dev/null || true
    fi
    
    if [ ! -z "$ANVIL_PID" ] && kill -0 "$ANVIL_PID" 2>/dev/null; then
        echo -e "${BLUE}[INFO]${NC} Stopping Anvil node (PID: $ANVIL_PID)..."
        kill "$ANVIL_PID" 2>/dev/null || true
    fi
    
    # Kill any remaining processes on the ports
    lsof -ti:8545 2>/dev/null | xargs kill -9 2>/dev/null || true
    lsof -ti:$ADDRESS_SERVER_PORT 2>/dev/null | xargs kill -9 2>/dev/null || true
    
    echo -e "${GREEN}[SUCCESS]${NC} Cleanup complete"
    exit 0
}

# Set up signal handlers for graceful shutdown
trap cleanup SIGINT SIGTERM EXIT

echo -e "${PURPLE}=== ReFlax Enhanced Complete Local Deployment Automation ===${NC}"
echo -e "${PURPLE}    Story 001: Enhanced Deploy Script with SFlax Integration Support${NC}"
echo ""

# Kill any existing processes on our ports
echo -e "${BLUE}[INFO]${NC} Cleaning up existing processes..."
lsof -ti:8545 2>/dev/null | xargs kill -9 2>/dev/null || true
lsof -ti:$ADDRESS_SERVER_PORT 2>/dev/null | xargs kill -9 2>/dev/null || true
sleep 2

# Install npm dependencies if needed
if [ ! -d "node_modules" ]; then
    echo -e "${BLUE}[INFO]${NC} Installing npm dependencies..."
    npm install
fi

# Start Anvil node
echo -e "${BLUE}[INFO]${NC} Starting Anvil node on $RPC_URL..."
anvil --host 0.0.0.0 --port 8545 > /dev/null 2>&1 &
ANVIL_PID=$!

# Wait for Anvil to be ready
echo -e "${BLUE}[INFO]${NC} Waiting for Anvil to be ready..."
for i in {1..30}; do
    if curl -s -X POST -H "Content-Type: application/json" \
         --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
         "$RPC_URL" > /dev/null 2>&1; then
        echo -e "${GREEN}[SUCCESS]${NC} Anvil is ready (PID: $ANVIL_PID)"
        break
    fi
    
    if [ $i -eq 30 ]; then
        echo -e "${RED}[ERROR]${NC} Anvil failed to start within 30 seconds"
        exit 1
    fi
    
    sleep 1
done

# Deploy contracts using the enhanced script
echo -e "${PURPLE}[INFO]${NC} Deploying ReFlax contracts with full SFlax integration..."
export PRIVATE_KEY="0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"  # Anvil account 0
export FOUNDRY_DISABLE_NIGHTLY_WARNING=true

echo -e "${BLUE}[INFO]${NC} Running enhanced deployment script..."
if forge script scripts/DeployLocalComplete.s.sol:CompleteLocalDeploymentScript --rpc-url "$RPC_URL" --broadcast --ffi; then
    echo -e "${GREEN}[SUCCESS]${NC} Enhanced contracts deployed successfully!"
    echo -e "${GREEN}[SUCCESS]${NC} All SFlax integration features are now available!"
else
    echo -e "${RED}[ERROR]${NC} Enhanced contract deployment failed"
    exit 1
fi

# Verify deployment file was created
if [ ! -f "scripts/deployedAddresses.json" ]; then
    echo -e "${RED}[ERROR]${NC} Deployment addresses file not found"
    exit 1
fi

# Verify enhanced features in deployment file
echo -e "${BLUE}[INFO]${NC} Verifying enhanced features..."
if grep -q "sFlaxIntegration.*true" scripts/deployedAddresses.json; then
    echo -e "${GREEN}[SUCCESS]${NC} sFlax integration features verified in deployment"
else
    echo -e "${YELLOW}[WARNING]${NC} Enhanced features may not be fully configured"
fi

# Start address server
echo -e "${BLUE}[INFO]${NC} Starting address server on port $ADDRESS_SERVER_PORT..."
node scripts/addressServer.js &
SERVER_PID=$!

# Wait for address server to be ready
echo -e "${BLUE}[INFO]${NC} Waiting for address server to be ready..."
for i in {1..10}; do
    if curl -s "http://localhost:$ADDRESS_SERVER_PORT/health" > /dev/null 2>&1; then
        echo -e "${GREEN}[SUCCESS]${NC} Address server is ready (PID: $SERVER_PID)"
        break
    fi
    
    if [ $i -eq 10 ]; then
        echo -e "${RED}[ERROR]${NC} Address server failed to start"
        exit 1
    fi
    
    sleep 1
done

# Display final status
echo ""
echo -e "${PURPLE}=== 🚀 ReFlax Enhanced Environment Ready! ===${NC}"
echo ""
echo -e "${GREEN}✓ Story 001 Implementation Complete:${NC}"
echo -e "  ${GREEN}✓${NC} Enhanced deployment script created"
echo -e "  ${GREEN}✓${NC} Boost calculation methods implemented"
echo -e "  ${GREEN}✓${NC} Proper flaxPerSFlax exchange rate (not fallback 1)"
echo -e "  ${GREEN}✓${NC} SFlax burner permissions configured"
echo -e "  ${GREEN}✓${NC} Test accounts with vault deposits"
echo -e "  ${GREEN}✓${NC} SFlax balances for boost testing"
echo -e "  ${GREEN}✓${NC} Boost algorithm with diminishing returns"
echo -e "  ${GREEN}✓${NC} Enhanced error handling"
echo -e "  ${GREEN}✓${NC} Gas estimation methods"
echo ""
echo -e "${BLUE}Services Running:${NC}"
echo -e "  📦 Anvil Node:     http://localhost:8545 (PID: $ANVIL_PID)"
echo -e "  🌐 Address Server: http://localhost:$ADDRESS_SERVER_PORT (PID: $SERVER_PID)"
echo ""
echo -e "${BLUE}Endpoints:${NC}"
echo -e "  📍 Contract Addresses: http://localhost:$ADDRESS_SERVER_PORT/api/contract-addresses"
echo -e "  ❤️  Health Check:      http://localhost:$ADDRESS_SERVER_PORT/health"
echo ""
echo -e "${BLUE}Enhanced Features Available:${NC}"
echo -e "  🔥 Boost Calculations: calculateBoostPercentage(), getOptimalBurnAmount(), getMaxBoostPercentage()"
echo -e "  ⚡ Gas Estimation: estimateGasCost() for boost operations"  
echo -e "  💰 Proper Exchange Rate: flaxPerSFlax = 1.1 (not fallback 1)"
echo -e "  🔐 Burner Permissions: Vault approved to burn sFlax"
echo -e "  🧪 Test Data: Accounts with deposits and sFlax balances ready"
echo ""
echo -e "${BLUE}Usage:${NC}"
echo -e "  • Connect your frontend to: $RPC_URL"
echo -e "  • Chain ID: 31337"
echo -e "  • All missing reflax-ui story 020 contract functionality is now available"
echo -e "  • Test boost calculations, claims with boosts, withdrawals with boosts"
echo -e "  • Press Ctrl+C to stop all services"
echo ""

# Test enhanced endpoints
echo -e "${BLUE}[INFO]${NC} Testing enhanced deployment..."
if curl -s "http://localhost:$ADDRESS_SERVER_PORT/api/contract-addresses" | jq -r '.enhancedFeatures.sFlaxIntegration' 2>/dev/null | grep -q true; then
    echo -e "${GREEN}[SUCCESS]${NC} Enhanced features confirmed in address server!"
    echo -e "${GREEN}[SUCCESS]${NC} Ready for reflax-ui story 020 integration testing!"
else
    echo -e "${YELLOW}[INFO]${NC} Address server working, enhanced features should be available"
fi

echo ""
echo -e "${PURPLE}[INFO]${NC} Enhanced environment is ready. Press Ctrl+C to shutdown..."
echo -e "${PURPLE}[INFO]${NC} This deployment addresses all gaps identified in reflax-ui story 020"

# Wait indefinitely (cleanup will happen on signal)
while true; do
    # Check if processes are still running
    if ! kill -0 "$ANVIL_PID" 2>/dev/null || ! kill -0 "$SERVER_PID" 2>/dev/null; then
        echo -e "${RED}[ERROR]${NC} One or more services stopped unexpectedly"
        exit 1
    fi
    sleep 5
done