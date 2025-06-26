# Integration Test CLAUDE.md

This file provides guidance to Claude Code when working with integration tests in the ReFlax protocol.

## Overview

Integration tests use Arbitrum mainnet forks to test against real deployed contracts, providing confidence that the code works with actual DeFi protocols like Convex, Curve, and Uniswap.

## Key Files in This Directory

- `Integration.md` - Complete implementation guide for setting up integration testing
- `IntegrationCoverage.md` - Tracks status of all integration tests (11 suites, 92 tests all passing)
- `IntegrationTestCommands.md` - Commands for running integration tests

## Quick Start

When working with integration tests:
1. Review `Integration.md` for the setup and architecture
2. Check `IntegrationCoverage.md` to see what's already tested
3. Use `IntegrationTestCommands.md` for running tests
4. Always run `direnv allow` before running integration tests

## Important Reminders

- Integration tests are in the `test-integration/` directory
- Tests require an Arbitrum RPC URL (set via `.envrc`)
- Use real contract addresses from `ArbitrumConstants.sol`
- Deploy mock Flax/sFlax tokens since they don't exist on mainnet
- Integration tests interact with real protocols, so gas costs and execution time are higher

## Test Pattern

All integration tests should:
1. Extend `IntegrationTest` base contract
2. Use helper functions for dealing tokens and advancing time
3. Label contracts for better trace output
4. Take snapshots before complex operations for debugging