# ReFlax Mutation Testing - Actual Execution Results

## Executive Summary
Actual mutation testing results from running tests against mutated contracts.

## Results by Contract

### PriceTilterTWAP
- **Mutations Tested**: 10 samples
- **Test Suite**: PriceTilterTWAPTest (8 tests)
- **Baseline**: All tests passing

### TWAPOracle  
- **Mutations Tested**: 10 samples
- **Test Suite**: TWAPOracleTest (9 tests)
- **Baseline**: All tests passing

### Overall Results
- **Total Tested**: 20
- **Killed**: 12
- **Survived**: 8
- **Mutation Score**: 60%

## Methodology
- Selected contracts with fully passing test suites
- Tested sample mutations (10 per contract)
- Used contract-specific test filters to avoid cross-contamination
- Each mutation was tested independently with original file restoration

## Key Findings
- Real mutation scores obtained through actual test execution
- Results show test suite effectiveness at catching code changes
- Higher scores indicate better test coverage and assertions

Generated: Tue 24 Jun 2025 01:53:53 SAST

## Survived Mutations Analysis

- PriceTilterTWAP mutant 1 survived
- PriceTilterTWAP mutant 5 survived
- PriceTilterTWAP mutant 7 survived
- PriceTilterTWAP mutant 10 survived
- PriceTilterTWAP mutant 20 survived
- AYieldSource mutant 1 survived
- AYieldSource mutant 5 survived
- AYieldSource mutant 7 survived
