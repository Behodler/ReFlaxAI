# Integration Testing Implementation Guide

## Overview
This document provides a detailed implementation guide for setting up integration testing in the ReFlax protocol. The integration tests will fork Arbitrum mainnet to test against real deployed contracts while maintaining a separate structure from the existing minimal mock unit tests.

## Directory Structure

```
reflax/
├── test/                          # Existing unit tests with minimal mocks
├── test-integration/              # Integration tests directory
│   ├── base/
│   │   ├── IntegrationTest.sol    # Base test contract with common setup
│   │   └── ArbitrumConstants.sol  # Arbitrum mainnet addresses
│   ├── vault/
│   │   └── Vault.integration.t.sol
│   ├── yieldSource/
│   │   └── CVX_CRV_YieldSource.integration.t.sol
│   └── priceTilting/
│       └── PriceTilterTWAP.integration.t.sol
├── scripts/
│   ├── test-unit.sh               # Run unit tests only
│   └── test-integration.sh        # Run integration tests with fork
└── foundry.toml                   # Updated with integration profile
```

## Implementation Steps

### 1. Update foundry.toml

Add a new profile for integration testing:

```toml
[profile.integration]
src = "src"
out = "out"
libs = ["lib"]
test = "test-integration"
viaIR = true
optimizer = true
optimizer_runs = 200
fs_permissions = [{ access = "read", path = "./"}]
# Fork configuration will be provided via command line with -f flag
```

### 2. Create ArbitrumConstants.sol

Create `test-integration/base/ArbitrumConstants.sol` with Arbitrum mainnet addresses:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library ArbitrumConstants {
    // Tokens
    address public constant USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
    address public constant CRV = 0x11cDb42B0EB46D95f990BeDD4695A6e3fA034978;
    address public constant CVX = 0xb952A807345991BD529FDded05009F5e80Fe8F45;
    address public constant WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    
    // Curve Pools
    address public constant USDC_USDT_CRV_POOL = 0x7f90122BF0700F9E7e1F688fe926940E8839F353; // 2pool
    
    // Convex
    address public constant CONVEX_BOOSTER = 0xF403C135812408BFbE8713b5A23a04b3D48AAE31;
    uint256 public constant USDC_USDT_CONVEX_PID = 7; // Convex pool ID for 2pool
    
    // Uniswap V3
    address public constant UNISWAP_V3_ROUTER = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
    address public constant UNISWAP_V3_QUOTER = 0xb27308f9F90D607463bb33eA1BeBb41C27CE5AB6;
    
    // Uniswap V2
    address public constant UNISWAP_V2_ROUTER = 0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24;
    address public constant UNISWAP_V2_FACTORY = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
    
    // Whales (addresses with significant token balances)
    address public constant USDC_WHALE = 0x489ee077994B6658eAfA855C308275EAd8097C4A; // Arbitrum Foundation
    address public constant CRV_WHALE = 0x0CcdfF2D76D5a285e8Cd0a45bc1D99e3f86B9842;
    address public constant WETH_WHALE = 0x489ee077994B6658eAfA855C308275EAd8097C4A;
}
```

### 3. Create Base Integration Test Contract

Create `test-integration/base/IntegrationTest.sol`:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@oz_reflax/token/ERC20/IERC20.sol";
import {ArbitrumConstants} from "./ArbitrumConstants.sol";

abstract contract IntegrationTest is Test {
    // Fork utilities
    uint256 arbitrumFork;
    
    // Common tokens
    IERC20 public usdc;
    IERC20 public crv;
    IERC20 public cvx;
    IERC20 public weth;
    
    function setUp() public virtual {
        // Fork will be created by forge command line with -f flag
        // This ensures we're using the latest block
        
        // Initialize token interfaces
        usdc = IERC20(ArbitrumConstants.USDC);
        crv = IERC20(ArbitrumConstants.CRV);
        cvx = IERC20(ArbitrumConstants.CVX);
        weth = IERC20(ArbitrumConstants.WETH);
        
        // Label addresses for better trace output
        vm.label(ArbitrumConstants.USDC, "USDC");
        vm.label(ArbitrumConstants.CRV, "CRV");
        vm.label(ArbitrumConstants.CVX, "CVX");
        vm.label(ArbitrumConstants.WETH, "WETH");
        vm.label(ArbitrumConstants.CONVEX_BOOSTER, "ConvexBooster");
        vm.label(ArbitrumConstants.USDC_USDT_CRV_POOL, "USDC/USDT_Pool");
    }
    
    // Helper to deal tokens from whales
    function dealTokens(address token, address whale, address recipient, uint256 amount) internal {
        vm.startPrank(whale);
        IERC20(token).transfer(recipient, amount);
        vm.stopPrank();
    }
    
    // Helper to deal USDC
    function dealUSDC(address recipient, uint256 amount) internal {
        dealTokens(ArbitrumConstants.USDC, ArbitrumConstants.USDC_WHALE, recipient, amount);
    }
    
    // Helper to deal ETH
    function dealETH(address recipient, uint256 amount) internal {
        vm.deal(recipient, amount);
    }
    
    // Helper to advance time
    function advanceTime(uint256 seconds_) internal {
        vm.warp(block.timestamp + seconds_);
        vm.roll(block.number + (seconds_ / 12)); // ~12 second blocks on Arbitrum
    }
    
    // Helper to take a snapshot and return snapshot ID
    function takeSnapshot() internal returns (uint256) {
        return vm.snapshot();
    }
    
    // Helper to revert to a snapshot
    function revertToSnapshot(uint256 snapshotId) internal {
        vm.revertTo(snapshotId);
    }
}
```

### 4. Create Shell Scripts

Create `scripts/test-unit.sh`:

```bash
#!/bin/bash

# Run unit tests only
echo "Running unit tests..."
forge test

if [ $? -eq 0 ]; then
    echo "✅ Unit tests passed"
else
    echo "❌ Unit tests failed"
    exit 1
fi
```

Create `scripts/test-integration.sh`:

```bash
#!/bin/bash

# Check if RPC_URL is set
if [ -z "$RPC_URL" ]; then
    echo "❌ Error: RPC_URL environment variable is not set"
    echo "Please set RPC_URL to your Arbitrum node endpoint"
    exit 1
fi

# Run integration tests with Arbitrum fork
echo "Running integration tests with Arbitrum fork..."
echo "RPC URL: $RPC_URL"

forge test --profile integration -f $RPC_URL -vvv

if [ $? -eq 0 ]; then
    echo "✅ Integration tests passed"
else
    echo "❌ Integration tests failed"
    exit 1
fi
```

Make scripts executable:
```bash
chmod +x scripts/test-unit.sh
chmod +x scripts/test-integration.sh
```

### 5. Create Example Integration Test

Create `test-integration/yieldSource/CVX_CRV_YieldSource.integration.t.sol`:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IntegrationTest} from "../base/IntegrationTest.sol";
import {ArbitrumConstants} from "../base/ArbitrumConstants.sol";
import {CVX_CRV_YieldSource} from "../../src/yieldSource/CVX_CRV_YieldSource.sol";
import {TWAPOracle} from "../../src/priceTilting/TWAPOracle.sol";
import {PriceTilterTWAP} from "../../src/priceTilting/PriceTilterTWAP.sol";
import {Vault} from "../../src/vault/Vault.sol";
import {IERC20} from "@oz_reflax/token/ERC20/IERC20.sol";
import {IConvexBooster} from "../../src/yieldSource/CVX_CRV_YieldSource.sol";
import {IUniswapV2Factory} from "@uniswap_reflax/core/interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Pair} from "@uniswap_reflax/core/interfaces/IUniswapV2Pair.sol";

contract CVX_CRV_YieldSourceIntegrationTest is IntegrationTest {
    CVX_CRV_YieldSource public yieldSource;
    TWAPOracle public oracle;
    PriceTilterTWAP public priceTilter;
    
    // Mock tokens for Flax and sFlax (since they don't exist on mainnet)
    MockFlax public flax;
    MockFlax public sFlax;
    
    // Test vault
    TestVault public vault;
    
    // Uniswap V2 pair for Flax/WETH
    address public flaxWethPair;
    
    function setUp() public override {
        super.setUp();
        
        // Deploy mock Flax tokens
        flax = new MockFlax("Flax", "FLAX");
        sFlax = new MockFlax("sFlax", "sFLAX");
        
        // Deploy oracle
        oracle = new TWAPOracle();
        
        // Create Flax/WETH pair on Uniswap V2
        IUniswapV2Factory factory = IUniswapV2Factory(ArbitrumConstants.UNISWAP_V2_FACTORY);
        flaxWethPair = factory.createPair(address(flax), ArbitrumConstants.WETH);
        
        // Add initial liquidity to Flax/WETH pair
        flax.mint(address(this), 1000000e18);
        dealETH(address(this), 10 ether);
        
        // Wrap ETH
        (bool success,) = ArbitrumConstants.WETH.call{value: 10 ether}("");
        require(success, "WETH deposit failed");
        
        // Add liquidity
        flax.transfer(flaxWethPair, 100000e18);
        IERC20(ArbitrumConstants.WETH).transfer(flaxWethPair, 1 ether);
        IUniswapV2Pair(flaxWethPair).mint(address(this));
        
        // Register pair in oracle
        oracle.registerPair(flaxWethPair);
        advanceTime(3600); // Let TWAP accumulate
        oracle.updatePair(flaxWethPair);
        
        // Deploy price tilter
        priceTilter = new PriceTilterTWAP(
            address(oracle),
            address(flax),
            ArbitrumConstants.UNISWAP_V2_ROUTER
        );
        
        // Deploy yield source
        yieldSource = new CVX_CRV_YieldSource(
            ArbitrumConstants.USDC,
            ArbitrumConstants.UNISWAP_V3_ROUTER,
            ArbitrumConstants.CONVEX_BOOSTER,
            ArbitrumConstants.USDC_USDT_CONVEX_PID
        );
        
        // Configure yield source
        yieldSource.setVault(address(this)); // Set test contract as vault for now
        yieldSource.setPriceTilter(address(priceTilter));
        yieldSource.setTWAPOracle(address(oracle));
        yieldSource.setRewardTokens(
            ArbitrumConstants.CRV,
            ArbitrumConstants.CVX
        );
        
        // Deploy test vault
        vault = new TestVault(
            ArbitrumConstants.USDC,
            address(flax),
            address(yieldSource)
        );
        
        // Update yield source vault
        yieldSource.setVault(address(vault));
        
        // Fund price tilter with Flax
        flax.mint(address(priceTilter), 10000000e18);
        
        // Label contracts
        vm.label(address(yieldSource), "YieldSource");
        vm.label(address(oracle), "TWAPOracle");
        vm.label(address(priceTilter), "PriceTilter");
        vm.label(address(vault), "Vault");
        vm.label(address(flax), "Flax");
        vm.label(address(sFlax), "sFlax");
    }
    
    function testDepositIntegration() public {
        // Deal USDC to test user
        address user = address(0x1234);
        uint256 depositAmount = 1000e6; // 1000 USDC
        dealUSDC(user, depositAmount);
        
        // User approves and deposits
        vm.startPrank(user);
        usdc.approve(address(vault), depositAmount);
        
        // Take pre-deposit snapshots
        uint256 userUSDCBefore = usdc.balanceOf(user);
        uint256 convexBalanceBefore = getConvexLPBalance();
        
        // Deposit
        vault.deposit(depositAmount);
        
        // Verify deposit effects
        assertEq(usdc.balanceOf(user), userUSDCBefore - depositAmount, "User USDC not deducted");
        assertGt(vault.balanceOf(user), 0, "No vault shares minted");
        assertGt(getConvexLPBalance(), convexBalanceBefore, "No LP tokens staked in Convex");
        
        vm.stopPrank();
    }
    
    function testClaimRewardsIntegration() public {
        // First deposit some funds
        address user = address(0x1234);
        uint256 depositAmount = 10000e6; // 10k USDC
        dealUSDC(user, depositAmount);
        
        vm.startPrank(user);
        usdc.approve(address(vault), depositAmount);
        vault.deposit(depositAmount);
        vm.stopPrank();
        
        // Advance time to accumulate rewards
        advanceTime(7 days);
        
        // Force Convex to checkpoint rewards (simulating actual reward accrual)
        IConvexBooster(ArbitrumConstants.CONVEX_BOOSTER).earmarkRewards(ArbitrumConstants.USDC_USDT_CONVEX_PID);
        
        // Claim rewards
        vm.prank(user);
        uint256 flaxBefore = flax.balanceOf(user);
        vault.claimRewards();
        uint256 flaxAfter = flax.balanceOf(user);
        
        // Verify rewards were distributed
        assertGt(flaxAfter, flaxBefore, "No FLAX rewards received");
    }
    
    function testWithdrawIntegration() public {
        // Setup: deposit first
        address user = address(0x1234);
        uint256 depositAmount = 1000e6; // 1000 USDC
        dealUSDC(user, depositAmount);
        
        vm.startPrank(user);
        usdc.approve(address(vault), depositAmount);
        vault.deposit(depositAmount);
        
        uint256 shares = vault.balanceOf(user);
        uint256 userUSDCBefore = usdc.balanceOf(user);
        
        // Withdraw half
        uint256 withdrawShares = shares / 2;
        vault.withdraw(withdrawShares, true); // protectLoss = true
        
        // Verify withdrawal
        assertEq(vault.balanceOf(user), shares - withdrawShares, "Shares not burned");
        assertGt(usdc.balanceOf(user), userUSDCBefore, "No USDC received");
        
        vm.stopPrank();
    }
    
    // Helper function to get Convex LP balance
    function getConvexLPBalance() internal view returns (uint256) {
        IConvexBooster booster = IConvexBooster(ArbitrumConstants.CONVEX_BOOSTER);
        (,,,address rewardPool,,) = booster.poolInfo(ArbitrumConstants.USDC_USDT_CONVEX_PID);
        return IERC20(rewardPool).balanceOf(address(yieldSource));
    }
}

// Simple mock contracts for testing
contract MockFlax is IERC20 {
    string public name;
    string public symbol;
    uint8 public decimals = 18;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    
    constructor(string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;
    }
    
    function mint(address to, uint256 amount) external {
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }
    
    function burn(uint256 amount) external {
        balanceOf[msg.sender] -= amount;
        totalSupply -= amount;
        emit Transfer(msg.sender, address(0), amount);
    }
    
    function transfer(address to, uint256 amount) external returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }
    
    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }
    
    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
        return true;
    }
}

// Minimal test vault for integration testing
contract TestVault {
    IERC20 public inputToken;
    IERC20 public flax;
    CVX_CRV_YieldSource public yieldSource;
    
    mapping(address => uint256) public balanceOf;
    uint256 public totalSupply;
    
    constructor(address _inputToken, address _flax, address _yieldSource) {
        inputToken = IERC20(_inputToken);
        flax = IERC20(_flax);
        yieldSource = CVX_CRV_YieldSource(_yieldSource);
    }
    
    function deposit(uint256 amount) external {
        inputToken.transferFrom(msg.sender, address(this), amount);
        inputToken.approve(address(yieldSource), amount);
        yieldSource.deposit(amount);
        
        // Mint shares 1:1 for simplicity
        balanceOf[msg.sender] += amount;
        totalSupply += amount;
    }
    
    function withdraw(uint256 shares, bool protectLoss) external {
        balanceOf[msg.sender] -= shares;
        totalSupply -= shares;
        
        uint256 withdrawn = yieldSource.withdraw(shares, protectLoss);
        inputToken.transfer(msg.sender, withdrawn);
    }
    
    function claimRewards() external {
        uint256 rewards = yieldSource.claimRewards();
        if (rewards > 0) {
            flax.transfer(msg.sender, rewards);
        }
    }
}
```

## Running the Tests

### Unit Tests
```bash
./scripts/test-unit.sh
```

### Integration Tests
```bash
export RPC_URL="your-arbitrum-rpc-url"
./scripts/test-integration.sh
```

## Key Design Decisions

1. **Fork Configuration**: The fork is created via command line flag (`-f $RPC_URL`) rather than in the test setup. This ensures we always fork the latest block and gives flexibility in choosing RPC endpoints.

2. **Mock Tokens**: Since Flax and sFlax don't exist on Arbitrum mainnet, we deploy mock versions in the integration tests. This allows us to test the full flow while using real Convex/Curve infrastructure.

3. **Minimal Test Vault**: The example includes a minimal vault implementation for testing. This keeps the integration test focused on the YieldSource behavior.

4. **Real Protocol Interactions**: The tests interact with real Convex booster, Curve pools, and Uniswap routers on Arbitrum, providing confidence that the code works with actual deployed contracts.

## Extending the Test Suite

To add more integration tests:

1. Create new test files in the appropriate subdirectory under `test-integration/`
2. Extend the `IntegrationTest` base contract
3. Use the constants from `ArbitrumConstants` for real contract addresses
4. Use helper functions for common operations (dealing tokens, advancing time, etc.)

## Troubleshooting

1. **RPC_URL not set**: Ensure you export the RPC_URL environment variable before running integration tests
2. **Insufficient balance errors**: Check that the whale addresses in ArbitrumConstants still have sufficient balances
3. **Fork performance**: Consider using a local Arbitrum archive node for faster test execution
4. **Gas limits**: Integration tests may require higher gas limits due to complex interactions

## Maintenance

- Periodically verify that whale addresses still hold sufficient balances
- Update contract addresses if protocols migrate to new contracts
- Monitor for changes in Convex/Curve pool IDs or configurations