#!/bin/bash

# Simple test script to verify the enhanced deployment
echo "Testing Enhanced Deployment Script..."

# Start anvil in the background
echo "Starting Anvil..."
anvil --host 0.0.0.0 --port 8545 > /dev/null 2>&1 &
ANVIL_PID=$!

# Wait for anvil to start
sleep 3

# Set environment variables
export PRIVATE_KEY="0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
export FOUNDRY_DISABLE_NIGHTLY_WARNING=true

echo "Running enhanced deployment..."

# Run the enhanced deployment
if forge script scripts/DeployLocalComplete.s.sol:CompleteLocalDeploymentScript --rpc-url http://localhost:8545 --broadcast --ffi; then
    echo "✅ Enhanced deployment successful!"
    
    # Check if addresses file was created
    if [ -f "scripts/deployedAddresses.json" ]; then
        echo "✅ Addresses file created"
        
        # Check for enhanced features
        if grep -q "enhancedFeatures" scripts/deployedAddresses.json; then
            echo "✅ Enhanced features confirmed in addresses file"
        else
            echo "⚠️  Enhanced features not found in addresses file"
        fi
        
        # Show some key addresses
        echo ""
        echo "Key Contract Addresses:"
        echo "Vault: $(jq -r '.reflaxContracts.vault' scripts/deployedAddresses.json 2>/dev/null || echo 'Not found')"
        echo "sFlax: $(jq -r '.tokens.sFlax' scripts/deployedAddresses.json 2>/dev/null || echo 'Not found')"
        echo ""
        
    else
        echo "❌ Addresses file not created"
    fi
    
else
    echo "❌ Enhanced deployment failed"
fi

# Cleanup
echo "Cleaning up..."
kill $ANVIL_PID 2>/dev/null
wait $ANVIL_PID 2>/dev/null

echo "Test complete!"