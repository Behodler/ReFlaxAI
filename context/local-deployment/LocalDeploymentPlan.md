# Local ReFlax Deployment Plan for UI Development

## Overview
This plan outlines the creation of a local ReFlax deployment on Anvil using realistic fake data instead of forking Arbitrum. This will provide a stable, fast development environment for UI testing without RPC dependencies.

## Architecture Components to Deploy

### 1. Core Protocol Contracts
- **Vault.sol** - User-facing vault contract
- **CVX_CRV_YieldSource.sol** - Yield source implementation
- **PriceTilterTWAP.sol** - Price tilting mechanism
- **TWAPOracle.sol** - Time-weighted average price oracle

### 2. Mock External Dependencies
- **MockERC20** tokens (USDC, USDT, CRV, CVX, WETH, Flax, sFlax)
- **MockUniswapV3Router** - For token swaps
- **MockUniswapV2Factory/Pair** - For Flax/ETH pair
- **MockCurvePool** - For LP token operations
- **MockConvexBooster** - For yield farming
- **MockConvexRewards** - For reward distribution

## Implementation Plan

### Phase 1: Mock Contract Development
1. **Create comprehensive mocks** in `test/mocks/LocalDeployment/`
   - Realistic token balances and prices
   - Functional swap mechanisms with configurable slippage
   - Yield generation simulation
   - Reward distribution mechanics

2. **Mock Data Configuration**
   - USDC/USDT: $1.00 each
   - ETH: $2000
   - Flax: $0.50 (configurable via PriceTilter)
   - CRV: $0.30
   - CVX: $2.50
   - Realistic APY rates (5-15%)

### Phase 2: Deployment Script Architecture
1. **Main Deployment Script**: `scripts/deployLocal.js`
   - Deploy all mock contracts
   - Configure realistic initial state
   - Set up token balances for test accounts
   - Initialize price oracles with historical-like data

2. **Configuration Management**
   - JSON config file for easy parameter adjustment
   - Environment-specific settings
   - Test account setup with pre-funded balances

### Phase 3: Realistic Data Simulation
1. **Price Movement Simulation**
   - Gradual price changes over time
   - Realistic volatility patterns
   - Configurable market scenarios (bull/bear/stable)

2. **Yield Generation**
   - Time-based reward accumulation
   - Realistic APY calculations
   - Compound interest simulation

3. **User Journey Simulation**
   - Pre-populated deposits from multiple accounts
   - Historical transaction data
   - Realistic balance distributions

## File Structure

```
context/local-deployment/
├── LocalDeploymentPlan.md (this file)
├── MockContracts.md (detailed mock specifications)
├── DeploymentConfig.json (configuration parameters)
└── TestScenarios.md (predefined test scenarios)

scripts/
├── deployLocal.js (main deployment script)
├── configureLocal.js (post-deployment configuration)
└── seedData.js (populate with realistic data)

test/mocks/LocalDeployment/
├── MockUniswapV3Router.sol
├── MockUniswapV2Factory.sol
├── MockCurvePool.sol
├── MockConvexBooster.sol
├── MockConvexRewards.sol
└── MockPriceFeeds.sol
```

## Deployment Script Features

### 1. One-Command Setup
```bash
# Single command to deploy entire local environment
forge script scripts/deployLocal.js --rpc-url http://localhost:8545 --broadcast
```

### 2. Configuration Options
- **Scenario Selection**: Choose from predefined market scenarios
- **Time Acceleration**: Fast-forward through time for testing
- **Balance Presets**: Different user portfolio configurations
- **Yield Rates**: Adjustable APY rates for different strategies

### 3. Development Utilities
- **Reset Function**: Clean slate deployment
- **State Snapshots**: Save/restore specific states
- **Event Logging**: Detailed transaction history
- **Health Checks**: Verify deployment integrity

## Mock Contract Specifications

### MockUniswapV3Router
- Realistic slippage calculation (0.1-0.5%)
- Configurable liquidity depth
- Price impact simulation
- Multi-hop routing support

### MockCurvePool
- Balanced pool mechanics
- Realistic LP token pricing
- Configurable fees (0.04-0.3%)
- Impermanent loss simulation

### MockConvexBooster
- Reward multiplier mechanics
- Staking/unstaking with realistic delays
- Boost calculation based on sFlax holdings

### MockConvexRewards
- Time-based reward accumulation
- Multiple reward tokens (CRV, CVX)
- Realistic distribution schedules

## Test Data Scenarios

### 1. Fresh Deployment
- Clean slate with initial token distributions
- Basic liquidity in all pools
- No user deposits

### 2. Active Protocol
- Multiple users with varying deposit sizes
- Ongoing reward accumulation
- Recent price movements

### 3. Stressed Conditions
- High slippage scenarios
- Low liquidity conditions
- Extreme price volatility

### 4. Migration Scenario
- Old YieldSource with deposits
- New YieldSource ready for migration
- Realistic migration costs

## Configuration Parameters

### Token Prices (USD)
- USDC: 1.00
- USDT: 1.00
- ETH: 2000.00
- Flax: 0.50
- CRV: 0.30
- CVX: 2.50

### Yield Rates (APY)
- Curve LP: 5-8%
- Convex Boost: 3-5%
- Total Expected: 8-13%

### User Accounts
- Account 1: $10,000 (large depositor)
- Account 2: $1,000 (medium depositor)
- Account 3: $100 (small depositor)
- Account 4: $0 (new user)

## Success Metrics

### 1. Deployment Speed
- Full deployment in under 30 seconds
- No external RPC dependencies
- Consistent reproducible state

### 2. Realism
- Realistic price movements
- Accurate yield calculations
- Proper slippage simulation

### 3. UI Development Support
- All user flows testable
- Edge cases reproducible
- Performance characteristics realistic

## Next Steps

1. **Review and Approve Plan**: Ensure alignment with UI development needs
2. **Implement Mock Contracts**: Start with core mocks (ERC20s, Uniswap, Curve)
3. **Create Deployment Script**: Build the main deployment automation
4. **Test and Iterate**: Verify realistic behavior and adjust parameters
5. **Documentation**: Create usage guide for UI developers

## Technical Considerations

### Anvil Configuration
- Block time: 1 second (for realistic time-based testing)
- Gas limit: High enough for complex transactions
- Pre-funded accounts with sufficient ETH

### State Management
- Deterministic deployment addresses
- Predictable initial state
- Easy reset capabilities

### Integration Points
- JSON-RPC API for UI connection
- WebSocket support for real-time updates
- Standard Ethereum wallet integration

This plan provides a comprehensive foundation for local ReFlax development without external dependencies while maintaining realistic protocol behavior for effective UI testing.