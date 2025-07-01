# ReFlax Local Deployment for UI Development

A comprehensive Anvil-based local deployment system providing realistic mock environments for ReFlax protocol UI development and testing.

## Quick Start

### Prerequisites

1. **Foundry** installed and configured
2. **Anvil** blockchain simulator
3. **Node.js** (for JSON processing utilities)

### One-Command Deployment

```bash
# Start Anvil (in separate terminal)
anvil --host 0.0.0.0 --port 8545

# Install dependencies (first time only)
npm install

# Deploy ReFlax protocol and start address server
./scripts/deployWithServer.sh
```

This will:
1. Deploy all contracts to local Anvil
2. Save addresses to `scripts/deployedAddresses.json`
3. Start Express server on port 3011
4. Serve addresses at `http://localhost:3011/api/contract-addresses`

**Note**: Keep the terminal open to maintain the server (press Ctrl+C to stop)

### Using Deployment Utilities

```bash
# Use the utility script for enhanced features
./scripts/localUtils.sh deploy-fresh

# Or deploy specific scenarios
./scripts/localUtils.sh deploy-scenario active
./scripts/localUtils.sh deploy-scenario stressed
```

## Features

### 🚀 **Fast Deployment**
- Sub-30 second deployment time
- No external RPC dependencies
- Consistent, reproducible state

### 💰 **Realistic Economics**
- Accurate token prices (USDC: $1.00, ETH: $2000, Flax: $0.50)
- Realistic yield rates (8-13% APY)
- Proper slippage simulation (0.1-5%)
- Price impact for large trades

### 🎯 **Multiple Scenarios**
- **Fresh**: Clean deployment for initial development
- **Active**: Established protocol with transaction history
- **Stressed**: High slippage and low liquidity conditions
- **Migration**: YieldSource migration testing
- **Development**: Optimized for rapid iteration

### 🛠 **Developer Tools**
- State snapshots and restoration
- Time manipulation (fast-forward)
- Health monitoring
- Comprehensive logging

## Architecture

### Mock Contracts

The deployment uses sophisticated mock contracts that simulate real DeFi protocols:

#### MockUniswapV3Router
- Realistic slippage calculation (0.1-0.5% base)
- Price impact based on trade size vs liquidity
- Configurable token prices and liquidity depth
- Multi-hop routing support

#### MockCurvePool
- StableSwap invariant calculations
- Balanced LP token mechanics
- Configurable fees (0.04-0.3%)
- Multi-token pool support (2-4 tokens)

#### MockConvexBooster & Rewards
- Time-based reward accumulation
- Realistic APY calculations (7-day reward periods)
- Boost mechanics based on sFlax holdings
- Multiple reward tokens (CRV, CVX)

#### MockUniswapV2Factory & Pairs
- Full UniswapV2 compatibility
- TWAP price accumulation
- Liquidity provision mechanics
- Proper reserve management

### Token Configuration

All tokens deployed with realistic parameters:

| Token | Price | Decimals | Initial Supply | Use Case |
|-------|-------|----------|----------------|----------|
| USDC | $1.00 | 6 | 1B | Primary deposit token |
| USDT | $1.00 | 6 | 1B | Pool pairing |
| WETH | $2000 | 18 | 1M | ETH wrapper |
| CRV | $0.30 | 18 | 3B | Curve rewards |
| CVX | $2.50 | 18 | 100M | Convex rewards |
| Flax | $0.50 | 18 | 100M | Protocol token |
| sFlax | - | 18 | 0 | Staked Flax (burnable) |

## Usage Examples

### Basic Development Workflow

```bash
# 1. Start fresh environment
./scripts/localUtils.sh deploy-fresh

# 2. Create baseline snapshot
./scripts/localUtils.sh create-snapshot baseline

# 3. Develop and test features
# ... UI development ...

# 4. Reset to baseline for next test
./scripts/localUtils.sh restore-snapshot baseline

# 5. Test edge cases
./scripts/localUtils.sh deploy-scenario stressed
```

### Testing User Journeys

```bash
# Deploy active protocol with existing users
./scripts/localUtils.sh deploy-scenario active

# Test accounts are pre-funded:
# Account 1: $10K (Large depositor)
# Account 2: $1K (Medium depositor)  
# Account 3: $100 (Small depositor)
# Account 4: $0 (New user)
```

### Time-Based Testing

```bash
# Fast forward 1 day to accumulate rewards
./scripts/localUtils.sh fast-forward 86400

# Fast forward 1 week
./scripts/localUtils.sh fast-forward 604800

# Check that TWAP prices update properly
```

### Health Monitoring

```bash
# Check system health
./scripts/localUtils.sh health-check

# Monitor real-time activity
./scripts/localUtils.sh monitor-logs 60
```

## Configuration

### Deployment Parameters

Edit `context/local-deployment/DeploymentConfig.json` to customize:

```json
{
  "tokenPrices": {
    "flax": 750000  // Change Flax price to $0.75
  },
  "liquidityConfig": {
    "curvePool": {
      "usdc": "50000000000"  // Reduce to $50K liquidity
    }
  },
  "yieldConfig": {
    "curveLP": {
      "baseApyBps": 1200  // Increase to 12% APY
    }
  }
}
```

### Scenario Customization

Create custom scenarios by extending the configuration:

```bash
# Set environment variable for custom config
export CUSTOM_SCENARIO=high_yield
forge script scripts/DeployLocal.s.sol:LocalDeploymentScript --rpc-url http://localhost:8545 --broadcast
```

## Frontend Integration

### Address Server API

The deployment includes an Express server that provides contract addresses via HTTP:

```javascript
// In your UI application
async function getContractAddresses() {
  if (chainId === 31337) { // Anvil chain ID
    const response = await fetch('http://localhost:3011/api/contract-addresses');
    const addresses = await response.json();
    
    return {
      vault: addresses.reflaxContracts.vault,
      yieldSource: addresses.reflaxContracts.yieldSource,
      usdc: addresses.tokens.usdc,
      flax: addresses.tokens.flax,
      // ... other addresses
    };
  }
}
```

### API Response Format

```json
{
  "chainId": 31337,
  "timestamp": "1234567890",
  "blockNumber": "123",
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
  "testAccounts": ["0x...", "0x...", "0x...", "0x..."]
}
```

### CORS Configuration

The server is configured to allow requests from common frontend ports:
- `http://localhost:3000` (React)
- `http://localhost:3001` (Alternative React)
- `http://localhost:5173` (Vite)

To add more origins, modify `scripts/addressServer.js`.

### Test Accounts

Pre-configured test accounts with known private keys:

```typescript
const testAccounts = [
  {
    address: "0x...",
    privateKey: "0x0000000000000000000000000000000000000000000000000000000000000001",
    label: "Large Depositor",
    initialBalance: "$10,000"
  },
  // ... more accounts
];
```

### Realistic Testing Data

The deployment provides realistic data for comprehensive UI testing:

- **Price History**: TWAP oracles with historical price data
- **Transaction History**: Pre-populated deposits and withdrawals
- **Yield Accumulation**: Time-based reward generation
- **Liquidity Dynamics**: Realistic pool reserves and slippage

## Troubleshooting

### Common Issues

**Deployment Fails**
```bash
# Check Anvil is running
curl -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
  http://localhost:8545

# Restart Anvil if needed
anvil --host 0.0.0.0 --port 8545
```

**Unrealistic Behavior**
```bash
# Verify configuration
cat context/local-deployment/DeploymentConfig.json | jq '.tokenPrices'

# Check deployed contract state
cast call $VAULT_ADDRESS "totalDeposits()(uint256)" --rpc-url http://localhost:8545
```

**State Inconsistency**
```bash
# Reset to known good state
./scripts/localUtils.sh reset-fresh

# Or restore specific snapshot
./scripts/localUtils.sh restore-snapshot baseline
```

### Debug Commands

```bash
# Check token balances
cast call $USDC_ADDRESS "balanceOf(address)(uint256)" $ACCOUNT --rpc-url http://localhost:8545

# Monitor contract events
cast logs --from-block 0 --address $VAULT_ADDRESS --rpc-url http://localhost:8545

# Check pool reserves
cast call $CURVE_POOL "balances(uint256)(uint256)" 0 --rpc-url http://localhost:8545

# Verify TWAP oracle
cast call $TWAP_ORACLE "getPrice()(uint256)" --rpc-url http://localhost:8545
```

## Performance Benchmarks

Expected performance metrics:

| Metric | Target | Typical |
|--------|--------|---------|
| Deployment Time | < 30s | ~25s |
| Gas Usage | < 100M | ~60M |
| Memory Usage | < 200MB | ~120MB |
| Block Time | 1s | 1s |
| RPC Response | < 100ms | ~50ms |

## Advanced Features

### State Snapshots

```bash
# Create named snapshots
./scripts/localUtils.sh create-snapshot before_migration_test

# Restore for reproducible testing
./scripts/localUtils.sh restore-snapshot before_migration_test

# List all snapshots
./scripts/localUtils.sh list-snapshots
```

### Time Manipulation

```bash
# Fast forward for yield testing
./scripts/localUtils.sh fast-forward 86400  # 1 day
./scripts/localUtils.sh fast-forward 604800 # 1 week

# Test time-dependent functionality
# - Reward accumulation
# - TWAP price updates
# - Decay functions
```

### Stress Testing

```bash
# Apply stressed market conditions
./scripts/localUtils.sh deploy-scenario stressed

# This increases:
# - Slippage (3x normal)
# - Price volatility
# - Reduces liquidity (30% of normal)
```

### Migration Testing

```bash
# Deploy migration scenario
./scripts/localUtils.sh deploy-scenario migration

# Test migration flows:
# - User notification systems
# - Migration incentives
# - Data preservation
# - Rollback procedures
```

## Contributing

To extend the local deployment system:

1. **Add New Scenarios**: Extend `DeploymentConfig.json`
2. **Create Mock Contracts**: Add to `test/mocks/LocalDeployment/`
3. **Enhance Utilities**: Update `scripts/localUtils.sh`
4. **Document Changes**: Update relevant `.md` files

### File Structure

```
context/local-deployment/
├── LocalDeploymentPlan.md     # Original plan document
├── DeploymentConfig.json      # Configuration parameters
├── TestScenarios.md          # Scenario definitions
└── README.md                 # This file

scripts/
├── deployLocal.js            # Main deployment script
└── localUtils.sh            # Utility commands

test/mocks/LocalDeployment/
├── MockUniswapV3Router.sol   # DEX simulation
├── MockCurvePool.sol         # Stable pool mechanics
├── MockConvexBooster.sol     # Yield farming
├── MockUniswapV2Factory.sol  # V2 pair management
└── MockTokens.sol           # ERC20 implementations
```

## Security Considerations

⚠️ **Local Development Only**: This system is designed exclusively for local development and testing. Never use in production environments.

- Mock contracts bypass security checks
- Private keys are hardcoded for testing
- No access controls on administrative functions
- Simplified economic models

## Support

For issues or questions:

1. Check the troubleshooting section above
2. Review deployment logs in `./local-deployment-logs/`
3. Verify configuration in `DeploymentConfig.json`
4. Use health check: `./scripts/localUtils.sh health-check`

The local deployment system provides a comprehensive, realistic environment for ReFlax UI development while maintaining fast iteration cycles and reproducible testing conditions.