# Formal Verification for ReFlax Protocol

This directory contains formal verification specifications and documentation for the ReFlax protocol.

## Files Overview

### 1. FormalVerificationSpec.md
Comprehensive specification document outlining:
- Critical state variables and invariants for each contract
- Key functions requiring verification
- Mathematical properties and security requirements
- Cross-contract interactions and dependencies
- Priority verification areas

### 2. VaultSpec.spec
Certora specification for the Vault contract covering:
- Core accounting invariants (totalDeposits integrity)
- Access control rules (owner-only functions)
- Deposit/withdrawal correctness
- Surplus handling and loss protection
- Emergency state enforcement
- sFlax reward boosting mechanics

### 3. TWAPOracleSpec.spec
Certora specification for the TWAPOracle contract covering:
- Time-based update requirements (1-hour TWAP period)
- Cumulative price monotonicity
- TWAP calculation correctness
- Price consultation accuracy
- Initialization requirements

## Key Properties Verified

### Security Properties
1. **Fund Safety**: Users cannot lose more than legitimate protocol losses
2. **Access Control**: Only authorized entities can perform privileged operations
3. **Reentrancy Protection**: No reentrancy vulnerabilities in state-changing functions
4. **Integer Safety**: No overflow/underflow in mathematical operations

### Functional Properties
1. **Accounting Integrity**: Sum of user deposits equals total deposits
2. **Token Flow**: Tokens flow correctly between contracts without retention
3. **Reward Distribution**: Flax rewards calculated and distributed correctly
4. **Price Accuracy**: TWAP provides manipulation-resistant price data

### Liveness Properties
1. **Withdrawal Availability**: Users can always withdraw their funds
2. **Oracle Updates**: Price data stays reasonably current
3. **Emergency Recovery**: Emergency functions work when needed

## Verification Methodology

### Tools Used
- **Certora Prover**: Primary formal verification tool
- **SMTChecker**: Built-in Solidity static analysis
- **Echidna**: Property-based fuzzing for edge cases
- **Mythril**: Symbolic execution for vulnerability detection

### Verification Process
1. **Specification Development**: Define properties in Certora specification language
2. **Invariant Identification**: Identify critical invariants that must hold
3. **Rule Definition**: Create rules for specific function behaviors
4. **Verification Execution**: Run Certora prover on specifications
5. **Analysis**: Review verification results and counterexamples
6. **Refinement**: Improve specifications based on findings

## Critical Invariants Summary

### Vault Contract
```solidity
// Core accounting
totalDeposits == sum(originalDeposits[user])

// No token retention
inputToken.balanceOf(vault) == surplusInputToken

// Emergency state consistency
emergencyState => deposits/claims/migrations disabled
```

### TWAPOracle Contract  
```solidity
// Time requirements
price_update_requires: timeElapsed >= PERIOD

// Monotonicity
currentPriceCumulative >= lastPriceCumulative

// Calculation correctness
priceAverage == (cumulative_new - cumulative_old) / timeElapsed
```

### YieldSource Contracts
```solidity
// Access control
onlyWhitelistedVaults(deposit, withdraw, claimRewards)

// Slippage protection
outputAmount >= oraclePrice * (1 - slippageTolerance)

// Weight consistency
sum(underlyingWeights) == 10000
```

## Running Verification

### Prerequisites
- Certora Prover license and CLI
- Solidity compiler
- Node.js for additional tooling

### Commands
```bash
# Verify Vault contract
certoraRun VaultSpec.spec --verify Vault:VaultSpec

# Verify TWAPOracle contract  
certoraRun TWAPOracleSpec.spec --verify TWAPOracle:TWAPOracleSpec

# Run with specific configuration
certoraRun --conf verification.conf
```

### Configuration Files
Create `verification.conf` with:
```
{
  "files": [
    "src/vault/Vault.sol",
    "src/priceTilting/TWAPOracle.sol"
  ],
  "verify": "Vault:VaultSpec",
  "solc": "solc8.20",
  "msg": "Vault verification run"
}
```

## Verification Results

### Expected Outcomes
- All critical invariants should be **proven**
- Access control rules should be **verified**  
- Mathematical properties should be **correct**
- No false positives in security checks

### Common Issues
1. **Timeout**: Complex proofs may require increased timeout
2. **Havoc**: Some external calls may need stub implementations
3. **Precision**: Fixed-point arithmetic may need special handling
4. **Loops**: Bounded loops may need unrolling hints

## Integration with CI/CD

### Automated Verification
```yaml
# GitHub Actions example
- name: Run Formal Verification
  run: |
    certoraRun VaultSpec.spec --verify Vault:VaultSpec
    certoraRun TWAPOracleSpec.spec --verify TWAPOracle:TWAPOracleSpec
```

### Quality Gates
- Verification must pass before deployment
- New properties added for new features
- Regression testing for property changes

## Future Enhancements

### Additional Specifications
1. **PriceTilterTWAP**: Price tilting mechanism verification
2. **CVX_CRV_YieldSource**: Complex DeFi integration verification
3. **Cross-Contract**: Multi-contract interaction properties

### Advanced Properties
1. **Economic Invariants**: MEV resistance, arbitrage bounds
2. **Governance**: Upgrade safety, parameter bounds
3. **Liquidity**: Pool manipulation resistance

## Resources

### Documentation
- [Certora Documentation](https://docs.certora.com/)
- [Solidity SMTChecker](https://docs.soliditylang.org/en/latest/smtchecker.html)
- [Echidna Tutorial](https://github.com/crytic/echidna)

### Best Practices
- Keep specifications simple and focused
- Use ghost variables for complex state tracking
- Separate invariants from behavioral rules
- Test specifications with known violations first

## Contact

For questions about formal verification:
- Review the specification documents
- Check verification logs for errors
- Consult Certora documentation
- Create issues for specification improvements