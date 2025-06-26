# Unit Test CLAUDE.md

This file provides guidance to Claude Code when working with unit tests in the ReFlax protocol.

## Overview

Unit tests in this project follow a minimal mocking philosophy - we only mock what's absolutely necessary for each test to run. This keeps tests focused and maintainable.

## Key Files in This Directory

- `UnitTestGuidelines.md` - Testing philosophy, structure, and mock requirements
- `UnitTestCommands.md` - Commands for running unit tests

## Quick Start

When writing or modifying unit tests:
1. Check `UnitTestGuidelines.md` for the testing approach and mock requirements
2. Use `UnitTestCommands.md` for the correct commands to run tests
3. Follow the existing pattern of minimal mocks in `test/mocks/Mocks.sol`

## Important Reminders

- Unit tests are in the `test/` directory (not `test-integration/`)
- Each contract should have its own test file
- Mocks should be minimal - only implement what the test needs
- Always check that unit tests are passing before marking a task complete
- Set timeout to 15 minutes for builds/tests due to Solidity compilation times