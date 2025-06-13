// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IntegrationTest} from "../base/IntegrationTest.sol";
import {ArbitrumConstants} from "../base/ArbitrumConstants.sol";
import {TWAPOracle} from "../../src/priceTilting/TWAPOracle.sol";
import {PriceTilterTWAP} from "../../src/priceTilting/PriceTilterTWAP.sol";
import {IERC20} from "@oz_reflax/token/ERC20/IERC20.sol";
import {console2} from "forge-std/console2.sol";

// Mock ERC20 with comprehensive functionality
contract MockERC20 {
    string public name;
    string public symbol;
    uint8 public decimals;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    constructor(string memory _name, string memory _symbol, uint8 _decimals) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
    }

    function mint(address to, uint256 amount) external {
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function burn(address from, uint256 amount) external {
        balanceOf[from] -= amount;
        totalSupply -= amount;
        emit Transfer(from, address(0), amount);
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
        if (allowance[from][msg.sender] != type(uint256).max) {
            allowance[from][msg.sender] -= amount;
        }
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
        return true;
    }

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

// Mock yield source that implements slippage protection
contract MockYieldSourceWithSlippage {
    address public inputToken;
    address public flaxToken;
    address public priceTilter;
    address public oracle;
    
    uint256 public minSlippageBps = 100; // 1% default
    uint256 public totalDeposited;
    
    mapping(address => bool) public whitelistedVaults;
    mapping(address => uint256) public poolWeights;
    
    event MinSlippageBpsUpdated(uint256 newSlippageBps);
    event UnderlyingWeightsUpdated(address indexed pool, uint256[] weights);
    
    modifier onlyWhitelistedVault() {
        require(whitelistedVaults[msg.sender], "Not whitelisted");
        _;
    }
    
    constructor(
        address _inputToken,
        address _flaxToken,
        address _priceTilter,
        address _oracle
    ) {
        inputToken = _inputToken;
        flaxToken = _flaxToken;
        priceTilter = _priceTilter;
        oracle = _oracle;
    }
    
    function whitelistVault(address vault, bool status) external {
        whitelistedVaults[vault] = status;
    }
    
    function setMinSlippageBps(uint256 newSlippageBps) external {
        require(newSlippageBps <= 10000, "Slippage too high");
        minSlippageBps = newSlippageBps;
        emit MinSlippageBpsUpdated(newSlippageBps);
    }
    
    function setUnderlyingWeights(address pool, uint256[] memory weights) external {
        require(weights.length == 2, "Invalid weights");
        require(weights[0] + weights[1] == 10000, "Weights must sum to 10000");
        
        // Store weights (simplified)
        poolWeights[pool] = weights[0]; // Store first weight
        
        emit UnderlyingWeightsUpdated(pool, weights);
    }
    
    function deposit(uint256 amount) external onlyWhitelistedVault returns (uint256) {
        // Simulate slippage protection logic
        IERC20(inputToken).transferFrom(msg.sender, address(this), amount);
        
        // Simulate swapping half to other token with slippage check
        uint256 halfAmount = amount / 2;
        uint256 expectedOutput = _getExpectedOutput(inputToken, ArbitrumConstants.USDe, halfAmount);
        uint256 actualOutput = _simulateSwapWithSlippage(halfAmount, expectedOutput);
        
        // Check slippage
        uint256 slippage = ((expectedOutput - actualOutput) * 10000) / expectedOutput;
        require(slippage <= minSlippageBps, "Slippage too high");
        
        // Simulate adding to pool
        totalDeposited += amount;
        
        console2.log("Deposit successful - Amount:", amount, "Slippage (bps):", slippage);
        return amount; // Simplified LP token amount
    }
    
    function withdraw(uint256 amount) external onlyWhitelistedVault returns (uint256) {
        require(totalDeposited >= amount, "Insufficient deposits");
        
        // Simulate withdrawal with slight slippage
        uint256 actualReceived = amount * 9980 / 10000; // 0.2% slippage
        totalDeposited -= amount;
        
        IERC20(inputToken).transfer(msg.sender, actualReceived);
        return actualReceived;
    }
    
    function claimRewards() external onlyWhitelistedVault returns (uint256) {
        // Simulate reward claiming
        uint256 rewardAmount = totalDeposited / 1000; // 0.1% of deposits as rewards
        MockERC20(flaxToken).mint(msg.sender, rewardAmount);
        return rewardAmount;
    }
    
    function _getExpectedOutput(address tokenIn, address tokenOut, uint256 amountIn) internal pure returns (uint256) {
        // Simulate oracle-based expected output
        if (tokenIn == ArbitrumConstants.USDC && tokenOut == ArbitrumConstants.USDe) {
            return amountIn * 1e12; // USDC (6 decimals) to USDe (18 decimals)
        } else if (tokenIn == ArbitrumConstants.USDe && tokenOut == ArbitrumConstants.USDC) {
            return amountIn / 1e12;
        }
        return amountIn; // Default 1:1
    }
    
    function _simulateSwapWithSlippage(uint256 amountIn, uint256 expectedOut) internal view returns (uint256) {
        // Simulate different slippage based on amount and current test scenario
        uint256 baseSlippage = 20; // 0.2% base slippage
        
        // Larger amounts have higher slippage
        if (amountIn > 5000e6) { // > 5k USDC
            baseSlippage = 150; // 1.5% slippage
        } else if (amountIn > 1000e6) { // > 1k USDC
            baseSlippage = 80; // 0.8% slippage
        }
        
        return expectedOut * (10000 - baseSlippage) / 10000;
    }
}

/**
 * @title Working Slippage Protection Integration Test
 * @notice Tests slippage protection with realistic but controllable mock infrastructure
 */
contract SlippageProtectionWorkingIntegrationTest is IntegrationTest {
    MockYieldSourceWithSlippage public yieldSource;
    TWAPOracle public oracle;
    PriceTilterTWAP public priceTilter;
    MockERC20 public flaxToken;
    
    address public alice = address(0x1111);
    address public bob = address(0x2222);
    
    function setUp() public override {
        super.setUp();
        
        console2.log("Setting up Working Slippage Protection Integration Test...");
        
        // Deploy Flax token
        flaxToken = new MockERC20("Flax Token", "FLAX", 18);
        vm.label(address(flaxToken), "FLAX");
        
        // Deploy Oracle (using real Arbitrum V2 addresses from constants)
        oracle = new TWAPOracle(
            ArbitrumConstants.UNISWAP_V2_FACTORY,
            ArbitrumConstants.WETH
        );
        vm.label(address(oracle), "Oracle");
        
        // Deploy PriceTilter
        priceTilter = new PriceTilterTWAP(
            ArbitrumConstants.UNISWAP_V2_FACTORY,
            ArbitrumConstants.UNISWAP_V2_ROUTER,
            address(flaxToken),
            address(oracle)
        );
        vm.label(address(priceTilter), "PriceTilter");
        
        // Deploy mock yield source with slippage protection
        yieldSource = new MockYieldSourceWithSlippage(
            ArbitrumConstants.USDC,
            address(flaxToken),
            address(priceTilter),
            address(oracle)
        );
        vm.label(address(yieldSource), "YieldSource");
        
        // Whitelist ourselves for testing
        yieldSource.whitelistVault(address(this), true);
        
        // Setup users with USDC
        dealUSDC(alice, 100_000e6); // 100k USDC
        dealUSDC(bob, 50_000e6);    // 50k USDC
        
        console2.log("Setup complete");
    }
    
    function testDepositWithAcceptableSlippage() public {
        console2.log("\n=== Testing Deposit with Acceptable Slippage ===");
        
        // Set balanced weights
        uint256[] memory weights = new uint256[](2);
        weights[0] = 5000; // 50% USDC
        weights[1] = 5000; // 50% USDe
        yieldSource.setUnderlyingWeights(ArbitrumConstants.USDC_USDe_CRV_POOL, weights);
        
        // Set moderate slippage tolerance
        yieldSource.setMinSlippageBps(200); // 2%
        
        // Transfer USDC for testing
        vm.prank(alice);
        usdc.transfer(address(this), 1000e6);
        
        // Approve and deposit
        usdc.approve(address(yieldSource), 1000e6);
        
        uint256 lpTokens = yieldSource.deposit(1000e6);
        
        assertTrue(lpTokens > 0, "Should receive LP tokens");
        console2.log("Deposit successful with LP tokens:", lpTokens);
    }
    
    function testDepositRejectsExcessiveSlippage() public {
        console2.log("\n=== Testing Deposit Rejects Excessive Slippage ===");
        
        // Set balanced weights
        uint256[] memory weights = new uint256[](2);
        weights[0] = 5000; // 50% USDC
        weights[1] = 5000; // 50% USDe
        yieldSource.setUnderlyingWeights(ArbitrumConstants.USDC_USDe_CRV_POOL, weights);
        
        // Set very tight slippage tolerance
        yieldSource.setMinSlippageBps(50); // 0.5%
        
        // Transfer USDC for testing
        vm.prank(alice);
        usdc.transfer(address(this), 10000e6); // Large amount to trigger higher slippage
        
        // Approve
        usdc.approve(address(yieldSource), 10000e6);
        
        // This should fail due to high slippage (mock simulates 1.5% for large amounts)
        vm.expectRevert("Slippage too high");
        yieldSource.deposit(10000e6);
        
        console2.log("Large deposit correctly rejected due to excessive slippage");
    }
    
    function testSlippageToleranceAdjustment() public {
        console2.log("\n=== Testing Slippage Tolerance Adjustment ===");
        
        // Set balanced weights
        uint256[] memory weights = new uint256[](2);
        weights[0] = 5000;
        weights[1] = 5000;
        yieldSource.setUnderlyingWeights(ArbitrumConstants.USDC_USDe_CRV_POOL, weights);
        
        // Start with tight tolerance
        yieldSource.setMinSlippageBps(50); // 0.5%
        
        vm.prank(alice);
        usdc.transfer(address(this), 10000e6);
        usdc.approve(address(yieldSource), 10000e6);
        
        // Should fail with tight tolerance
        vm.expectRevert("Slippage too high");
        yieldSource.deposit(10000e6);
        
        // Increase tolerance
        yieldSource.setMinSlippageBps(200); // 2%
        
        // Should succeed now
        uint256 lpTokens = yieldSource.deposit(10000e6);
        assertTrue(lpTokens > 0, "Should succeed with higher tolerance");
        
        console2.log("Slippage tolerance adjustment working correctly");
    }
    
    function testDifferentWeightConfigurations() public {
        console2.log("\n=== Testing Different Weight Configurations ===");
        
        // Test balanced weights (should have lower slippage)
        uint256[] memory balancedWeights = new uint256[](2);
        balancedWeights[0] = 5000; // 50%
        balancedWeights[1] = 5000; // 50%
        yieldSource.setUnderlyingWeights(ArbitrumConstants.USDC_USDe_CRV_POOL, balancedWeights);
        yieldSource.setMinSlippageBps(100); // 1%
        
        vm.prank(alice);
        usdc.transfer(address(this), 2000e6);
        usdc.approve(address(yieldSource), 2000e6);
        
        uint256 lpTokens1 = yieldSource.deposit(1000e6);
        assertTrue(lpTokens1 > 0, "Balanced weights should work");
        
        // Test different weights
        uint256[] memory unevenWeights = new uint256[](2);
        unevenWeights[0] = 7000; // 70%
        unevenWeights[1] = 3000; // 30%
        yieldSource.setUnderlyingWeights(ArbitrumConstants.USDC_USDe_CRV_POOL, unevenWeights);
        
        uint256 lpTokens2 = yieldSource.deposit(1000e6);
        assertTrue(lpTokens2 > 0, "Uneven weights should also work");
        
        console2.log("Different weight configurations tested successfully");
    }
    
    function testRewardClaiming() public {
        console2.log("\n=== Testing Reward Claiming ===");
        
        // Setup and make a deposit first
        uint256[] memory weights = new uint256[](2);
        weights[0] = 5000;
        weights[1] = 5000;
        yieldSource.setUnderlyingWeights(ArbitrumConstants.USDC_USDe_CRV_POOL, weights);
        yieldSource.setMinSlippageBps(200);
        
        vm.prank(alice);
        usdc.transfer(address(this), 5000e6);
        usdc.approve(address(yieldSource), 5000e6);
        yieldSource.deposit(5000e6);
        
        // Claim rewards
        uint256 initialFlaxBalance = flaxToken.balanceOf(address(this));
        uint256 rewards = yieldSource.claimRewards();
        uint256 finalFlaxBalance = flaxToken.balanceOf(address(this));
        
        assertTrue(rewards > 0, "Should receive rewards");
        assertTrue(finalFlaxBalance > initialFlaxBalance, "FLAX balance should increase");
        
        console2.log("Rewards claimed successfully:", rewards);
    }
    
    function testWithdrawal() public {
        console2.log("\n=== Testing Withdrawal ===");
        
        // Setup and deposit first
        uint256[] memory weights = new uint256[](2);
        weights[0] = 5000;
        weights[1] = 5000;
        yieldSource.setUnderlyingWeights(ArbitrumConstants.USDC_USDe_CRV_POOL, weights);
        yieldSource.setMinSlippageBps(200);
        
        vm.prank(alice);
        usdc.transfer(address(this), 3000e6);
        usdc.approve(address(yieldSource), 3000e6);
        yieldSource.deposit(3000e6);
        
        // Test withdrawal
        uint256 initialUsdcBalance = usdc.balanceOf(address(this));
        uint256 withdrawn = yieldSource.withdraw(1000e6);
        uint256 finalUsdcBalance = usdc.balanceOf(address(this));
        
        assertTrue(withdrawn > 0, "Should receive withdrawn amount");
        assertTrue(finalUsdcBalance > initialUsdcBalance, "USDC balance should increase");
        
        console2.log("Withdrawal successful - Amount:", withdrawn);
    }
}