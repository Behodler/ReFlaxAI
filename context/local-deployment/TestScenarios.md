# ReFlax Local Deployment Test Scenarios

This document defines predefined test scenarios for the local ReFlax deployment, each designed to test specific aspects of the protocol and UI.

## Scenario 1: Fresh Deployment

**Purpose**: Clean slate deployment for initial testing and development.

**Configuration**:
- All contracts deployed with default parameters
- Pools funded with initial liquidity
- Test accounts funded but no prior activity
- No transaction history

**Use Cases**:
- Initial UI development and integration
- Testing basic user flows (deposit, withdraw, claim)
- Verifying contract interactions
- Component development and styling

**Commands**:
```bash
# Deploy fresh environment
forge script scripts/deployLocal.js --rpc-url http://localhost:8545 --broadcast

# Or with specific scenario
SCENARIO=fresh forge script scripts/deployLocal.js --rpc-url http://localhost:8545 --broadcast
```

## Scenario 2: Active Protocol

**Purpose**: Simulate an established protocol with ongoing activity.

**Configuration**:
- Pre-populated transaction history
- Multiple users with existing deposits
- Accumulated rewards ready for claiming
- Realistic TWAP price history

**Simulated Activity**:
- Large depositor: $5K deposit 30 days ago
- Medium depositor: $500 deposit 15 days ago  
- Small depositor: $50 deposit 7 days ago
- Multiple reward claims and withdrawals
- Price movements and TWAP updates

**Use Cases**:
- Testing UI with real data
- Performance testing with populated state
- User journey testing with existing balances
- Dashboard and analytics development

**Commands**:
```bash
SCENARIO=active forge script scripts/deployLocal.js --rpc-url http://localhost:8545 --broadcast
```

## Scenario 3: Stressed Market Conditions

**Purpose**: Test protocol behavior under adverse market conditions.

**Configuration**:
- Increased slippage (3x normal rates)
- Reduced pool liquidity (30% of normal)
- Volatile price movements
- High gas prices simulation

**Market Conditions**:
- High slippage on all swaps (1.5-5% instead of 0.1-0.5%)
- Low liquidity causing price impact
- Frequent price updates
- Some pools approaching minimum liquidity

**Use Cases**:
- Testing slippage protection mechanisms
- UI error handling and warnings
- Edge case behavior validation
- Stress testing transaction flows

**Commands**:
```bash
SCENARIO=stressed forge script scripts/deployLocal.js --rpc-url http://localhost:8545 --broadcast
```

## Scenario 4: Migration Ready

**Purpose**: Test YieldSource migration functionality.

**Configuration**:
- Old YieldSource with existing deposits
- New YieldSource ready for migration
- Migration incentives configured
- Some users ready to migrate, others not

**Migration Setup**:
- Old YieldSource: $10K total deposits across 3 users
- New YieldSource: Better yield rates (12% vs 8%)
- Early withdrawal bonus: 5% for pre-migration withdrawals
- Migration window: 7 days

**Use Cases**:
- Testing migration UI flows
- User notification systems
- Incentive mechanisms
- Data migration and history preservation

**Commands**:
```bash
SCENARIO=migration forge script scripts/deployLocal.js --rpc-url http://localhost:8545 --broadcast
```

## Scenario 5: Development Testing

**Purpose**: Optimized for rapid development and testing cycles.

**Configuration**:
- Fast block times (1 second)
- Simplified token amounts (round numbers)
- Enhanced logging and events
- Snapshot capabilities

**Developer Features**:
- Auto-mining enabled
- Detailed event logging
- State snapshots every 1000 blocks
- Health checks every 5 minutes
- Fast-forward time utilities

**Use Cases**:
- Rapid prototyping
- Automated testing
- Integration testing
- CI/CD pipeline testing

**Commands**:
```bash
SCENARIO=development forge script scripts/deployLocal.js --rpc-url http://localhost:8545 --broadcast
```

## Scenario Management

### Switching Scenarios

You can switch between scenarios without redeploying by using utility scripts:

```bash
# Switch to stressed conditions
./scripts/setStressedConditions.sh

# Reset to fresh state
./scripts/resetToFresh.sh

# Fast forward time (useful for yield testing)
./scripts/fastForward.sh 86400  # 1 day

# Create state snapshot
./scripts/createSnapshot.sh scenario_name

# Restore state snapshot
./scripts/restoreSnapshot.sh scenario_name
```

### Custom Scenarios

Create custom scenarios by modifying the `DeploymentConfig.json`:

```json
{
  "customScenario": {
    "name": "Custom Test",
    "tokenPrices": {
      "flax": 750000  // $0.75 instead of $0.50
    },
    "liquidityConfig": {
      "curvePool": {
        "usdc": "50000000000"  // $50K instead of $100K
      }
    }
  }
}
```

## Scenario Validation

Each scenario includes validation checks to ensure proper deployment:

### Fresh Deployment Checks
- ✅ All contracts deployed successfully
- ✅ Initial liquidity properly funded
- ✅ Test accounts have expected balances
- ✅ No transaction history exists
- ✅ Oracles initialized with default prices

### Active Protocol Checks
- ✅ Simulated deposits recorded correctly
- ✅ Reward accumulation working
- ✅ TWAP prices have realistic history
- ✅ User balances match expected values
- ✅ Protocol TVL matches simulated activity

### Stressed Conditions Checks
- ✅ Slippage increased across all pools
- ✅ Liquidity reduced to target levels
- ✅ Price volatility simulation active
- ✅ Error conditions trigger properly
- ✅ UI warnings display correctly

### Migration Scenario Checks
- ✅ Old YieldSource has expected deposits
- ✅ New YieldSource configured properly
- ✅ Migration parameters set correctly
- ✅ Incentives calculated accurately
- ✅ User migration eligibility correct

## Performance Benchmarks

Expected performance for each scenario:

| Scenario | Deployment Time | Gas Used | Memory Usage | Block Time |
|----------|----------------|----------|--------------|------------|
| Fresh | < 30s | ~50M | ~100MB | 1s |
| Active | < 45s | ~80M | ~150MB | 1s |
| Stressed | < 35s | ~60M | ~120MB | 2s |
| Migration | < 50s | ~90M | ~180MB | 1s |
| Development | < 25s | ~40M | ~80MB | 0.5s |

## Troubleshooting

### Common Issues

**Deployment Fails**:
- Check Anvil is running on port 8545
- Verify private key is set in environment
- Ensure sufficient ETH in deployer account

**Unrealistic Behavior**:
- Verify token prices in DeploymentConfig.json
- Check pool liquidity levels
- Validate slippage parameters

**Poor Performance**:
- Reduce scenario complexity
- Use development scenario for testing
- Clear Anvil state and restart

**State Inconsistency**:
- Use state snapshots for consistent testing
- Reset to known good state
- Verify contract interactions

### Debug Commands

```bash
# Check deployment status
cast call $VAULT_ADDRESS "totalDeposits()(uint256)" --rpc-url http://localhost:8545

# Verify token balances
cast call $USDC_ADDRESS "balanceOf(address)(uint256)" $TEST_ACCOUNT --rpc-url http://localhost:8545

# Check pool reserves
cast call $CURVE_POOL "balances(uint256)(uint256)" 0 --rpc-url http://localhost:8545

# Monitor events
cast logs --from-block 0 --address $VAULT_ADDRESS --rpc-url http://localhost:8545
```

## Integration with UI Development

### Frontend Configuration

The deployment script outputs a configuration file for frontend integration:

```json
{
  "networkId": 31337,
  "rpcUrl": "http://localhost:8545",
  "contracts": {
    "vault": "0x...",
    "yieldSource": "0x...",
    "priceTilter": "0x...",
    "tokens": {
      "usdc": "0x...",
      "flax": "0x..."
    }
  },
  "testAccounts": ["0x...", "0x...", "0x...", "0x..."]
}
```

### Recommended Development Workflow

1. **Start with Fresh Scenario**: Begin UI development with clean state
2. **Progress to Active Scenario**: Test with realistic data once basic flows work
3. **Test Stressed Conditions**: Validate error handling and edge cases
4. **Validate Migration Flows**: Test complex multi-step processes
5. **Use Development Scenario**: For rapid iteration and automated testing

### State Management

Use snapshots to maintain consistent test states:

```bash
# Create baseline after fresh deployment
./scripts/createSnapshot.sh baseline

# Test feature development
# ... make changes ...

# Restore to baseline for next test
./scripts/restoreSnapshot.sh baseline
```

This approach ensures reproducible testing environments and faster development cycles.