# ReFlax Local Deployment Automation

This directory contains a complete local deployment automation system for the ReFlax protocol that eliminates manual setup steps for developers.

## Quick Start

### Single Command Deployment

```bash
npm start
```

This single command will:
1. 🚀 Start a local Anvil node (localhost:8545)
2. 📦 Deploy all ReFlax contracts with realistic configuration
3. 🌐 Start an address server (localhost:3011) for UI integration
4. ✅ Verify all services are working
5. 📊 Display connection information

### Stopping Services

```bash
npm run stop
```

This will cleanly shut down all services and processes.

## Available Commands

| Command | Description |
|---------|-------------|
| `npm start` | Complete deployment automation (recommended) |
| `npm run deploy` | Same as `npm start` |
| `npm run stop` | Stop all services and clean up |
| `npm run health` | Check address server health |
| `npm run addresses` | Get all deployed contract addresses |
| `npm run start-anvil` | Start only Anvil node |
| `npm run start-server` | Start only address server |
| `npm run deploy-contracts` | Deploy contracts only (requires Anvil running) |

## Architecture

### Components

1. **Anvil Node** (`localhost:8545`)
   - Local Ethereum node with 10 pre-funded accounts
   - Chain ID: 31337
   - 10,000 ETH per account

2. **Contract Deployment** (`scripts/DeployLocal.s.sol`)
   - Core ReFlax contracts (Vault, YieldSource, PriceTilter, TWAPOracle)
   - Mock external contracts (Uniswap, Curve, Convex)
   - Mock tokens (USDC, USDT, WETH, CRV, CVX, Flax, sFlax)
   - Pre-funded test accounts

3. **Address Server** (`localhost:3011`)
   - REST API serving deployed contract addresses
   - CORS enabled for frontend integration
   - JSON response format optimized for UI consumption

### File Structure

```
scripts/
├── DeployLocal.s.sol          # Main deployment script
├── addressServer.js           # Express server for addresses
├── deployWithServer.sh        # Complete automation script
├── cleanup.sh                 # Service cleanup script
└── localUtils.sh              # Development utilities
```

## Integration Guide

### Frontend Integration

#### Getting Contract Addresses

```javascript
// Fetch all deployed addresses
const response = await fetch('http://localhost:3011/api/contract-addresses');
const addresses = await response.json();

console.log('Vault:', addresses.reflaxContracts.vault);
console.log('USDC:', addresses.tokens.usdc);
console.log('Test Accounts:', addresses.testAccounts);
```

#### Web3 Configuration

```javascript
import { ethers } from 'ethers';

// Connect to local Anvil node
const provider = new ethers.JsonRpcProvider('http://localhost:8545');

// Use test account (already funded with ETH and tokens)
const signer = new ethers.Wallet(
  '0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d', // Test account 1
  provider
);

// Get contract addresses
const addresses = await fetch('http://localhost:3011/api/contract-addresses').then(r => r.json());

// Connect to deployed contracts
const vault = new ethers.Contract(addresses.reflaxContracts.vault, vaultABI, signer);
const usdc = new ethers.Contract(addresses.tokens.usdc, erc20ABI, signer);
```

### Available Test Accounts

| Account | Private Key | Funding |
|---------|-------------|---------|
| Account 1 (Large) | `0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d` | $10K USDC + ETH + Flax |
| Account 2 (Medium) | `0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a` | $1K USDC + ETH + Flax |
| Account 3 (Small) | `0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6` | $100 USDC + ETH + Flax |
| Account 4 (New) | `0x47e179ec197488593b187f80a00eb0da91f1b9d0b13f8733639f19c30a34926a` | ETH only |

## API Reference

### Address Server Endpoints

#### GET `/api/contract-addresses`

Returns all deployed contract addresses in JSON format.

**Response Structure:**
```json
{
  "chainId": 31337,
  "timestamp": "1640995200",
  "blockNumber": "15",
  "tokens": {
    "usdc": "0x...",
    "usdt": "0x...",
    "weth": "0x...",
    "crv": "0x...",
    "cvx": "0x...",
    "flax": "0x...",
    "sFlax": "0x...",
    "curveLP": "0x..."
  },
  "externalContracts": {
    "uniswapV3Router": "0x...",
    "uniswapV2Factory": "0x...",
    "uniswapV2Router": "0x...",
    "curvePool": "0x...",
    "convexBooster": "0x...",
    "flaxEthPair": "0x..."
  },
  "reflaxContracts": {
    "vault": "0x...",
    "yieldSource": "0x...",
    "priceTilter": "0x...",
    "twapOracle": "0x..."
  },
  "testAccounts": [
    "0x...",
    "0x...",
    "0x...",
    "0x..."
  ]
}
```

#### GET `/health`

Returns server health status.

**Response:**
```json
{
  "status": "ok",
  "port": 3011,
  "addressesPath": "/path/to/deployedAddresses.json"
}
```

## Troubleshooting

### Common Issues

#### "Port already in use" errors

```bash
# Clean up any existing processes
npm run stop

# Or manually kill processes
lsof -ti:8545 | xargs kill -9  # Kill Anvil
lsof -ti:3011 | xargs kill -9  # Kill address server
```

#### "No deployed addresses found"

This means the deployment script didn't complete successfully.

1. Check if Anvil is running: `curl -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' http://localhost:8545`
2. Check deployment logs in the terminal
3. Ensure all dependencies are installed: `npm install && forge install`

#### "Connection refused" from frontend

1. Verify services are running: `npm run health`
2. Check CORS configuration in `scripts/addressServer.js`
3. Ensure frontend is connecting to correct URLs:
   - Blockchain: `http://localhost:8545`
   - Address API: `http://localhost:3011/api/contract-addresses`

#### "Transaction failed" or gas errors

1. Check account has sufficient ETH balance
2. Verify contract addresses are correct
3. Ensure you're using the correct chain ID (31337)

### Development Utilities

The `scripts/localUtils.sh` script provides additional development tools:

```bash
# Create blockchain snapshots
./scripts/localUtils.sh create-snapshot "before-test"

# Restore blockchain state
./scripts/localUtils.sh restore-snapshot "before-test"

# Fast forward time
./scripts/localUtils.sh fast-forward 86400  # 1 day

# Monitor blockchain activity
./scripts/localUtils.sh monitor-logs 60  # 60 seconds

# Health check
./scripts/localUtils.sh health-check
```

## Success Criteria Verification

### ✅ Automated Deployment
- Single command starts all services
- No manual configuration required
- Automatic dependency installation

### ✅ Service Integration
- Anvil node runs with proper configuration
- All contracts deploy successfully
- Address server provides real-time contract information

### ✅ Frontend Ready
- CORS-enabled API for seamless integration
- Structured JSON responses
- Pre-funded test accounts for immediate testing

### ✅ Developer Experience
- Clear error messages and status updates
- Graceful shutdown and cleanup
- Comprehensive logging and debugging info

## Additional Features

- **Realistic Configuration**: Contracts deployed with production-like parameters
- **Mock External Services**: Full Uniswap, Curve, and Convex mocks for isolated testing
- **Automated Testing**: Built-in validation ensures all services work correctly
- **Clean Shutdown**: Proper process management with graceful termination
- **State Management**: Snapshot and restore capabilities for test repeatability

## Next Steps

Once your local environment is running:

1. Connect your frontend to `http://localhost:8545`
2. Fetch contract addresses from `http://localhost:3011/api/contract-addresses`
3. Use the pre-funded test accounts for transactions
4. Develop and test your UI components
5. Use `npm run stop` when finished

For advanced scenarios, explore the utility scripts in `scripts/localUtils.sh` for state management and debugging capabilities.