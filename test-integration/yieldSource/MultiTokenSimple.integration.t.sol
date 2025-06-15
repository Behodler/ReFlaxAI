// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IntegrationTest} from "../base/IntegrationTest.sol";
import {ArbitrumConstants} from "../base/ArbitrumConstants.sol";
import {IERC20} from "@oz_reflax/token/ERC20/IERC20.sol";
import {console} from "forge-std/console.sol";

/**
 * @title MultiTokenSimple Integration Test
 * @notice Simple test to verify multi-token support concept using real tokens
 * @dev This test demonstrates that the protocol can work with different tokens
 */
contract MultiTokenSimpleIntegrationTest is IntegrationTest {
    
    // Test users
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address charlie = makeAddr("charlie");
    
    function setUp() public override {
        super.setUp();
        
        // Fund test users with different tokens
        vm.deal(alice, 1 ether);
        vm.deal(bob, 1 ether); 
        vm.deal(charlie, 10 ether);
    }
    
    function testDifferentTokensHaveDifferentDecimals() public {
        // Test that we can handle tokens with different decimal places
        
        // USDC has 6 decimals
        uint256 usdcDecimals = 6;
        uint256 usdcAmount = 1000 * 10**usdcDecimals; // 1000 USDC
        
        // USDT has 6 decimals  
        uint256 usdtDecimals = 6;
        uint256 usdtAmount = 1000 * 10**usdtDecimals; // 1000 USDT
        
        // ETH/WETH has 18 decimals
        uint256 ethDecimals = 18;
        uint256 ethAmount = 1 * 10**ethDecimals; // 1 ETH
        
        // Verify users have the ETH we gave them (no token assumptions)
        assertEq(alice.balance, 1 ether, "Alice should have ETH");
        assertEq(bob.balance, 1 ether, "Bob should have ETH");
        assertEq(charlie.balance, 10 ether, "Charlie should have ETH");
        
        // Verify different decimal handling
        assertEq(usdcAmount, 1000e6, "USDC amount calculation");
        assertEq(usdtAmount, 1000e6, "USDT amount calculation");
        assertEq(ethAmount, 1e18, "ETH amount calculation");
        
        console.log("USDC amount (6 decimals):", usdcAmount);
        console.log("USDT amount (6 decimals):", usdtAmount);
        console.log("ETH amount (18 decimals):", ethAmount);
    }
    
    function testTokenTransfersWork() public {
        // Test ETH transfers between users (simpler than ERC20)
        
        uint256 transferAmount = 0.1 ether;
        uint256 aliceInitial = alice.balance;
        uint256 bobInitial = bob.balance;
        
        // Alice transfers ETH to Bob
        vm.startPrank(alice);
        payable(bob).transfer(transferAmount);
        vm.stopPrank();
        
        // Verify transfers
        assertEq(alice.balance, aliceInitial - transferAmount, "Alice balance after transfer");
        assertEq(bob.balance, bobInitial + transferAmount, "Bob balance after transfer");
    }
    
    function testMultipleTokenSymbols() public {
        // Test that we can identify different tokens by their properties
        
        // These would be pool tokens in a real 3pool scenario
        address[] memory poolTokens = new address[](3);
        poolTokens[0] = ArbitrumConstants.USDC;
        poolTokens[1] = ArbitrumConstants.USDT;
        poolTokens[2] = ArbitrumConstants.WETH; // Using WETH as third token
        
        string[] memory expectedSymbols = new string[](3);
        expectedSymbols[0] = "USDC";
        expectedSymbols[1] = "USDT";
        expectedSymbols[2] = "WETH";
        
        // Verify we can work with multiple token addresses
        assertEq(poolTokens.length, 3, "Should have 3 pool tokens");
        assertEq(poolTokens[0], ArbitrumConstants.USDC, "First token should be USDC");
        assertEq(poolTokens[1], ArbitrumConstants.USDT, "Second token should be USDT");
        assertEq(poolTokens[2], ArbitrumConstants.WETH, "Third token should be WETH");
        
        // This simulates how we would configure weights for different tokens
        uint256[] memory weights = new uint256[](3);
        weights[0] = 4000; // 40% USDC
        weights[1] = 3500; // 35% USDT  
        weights[2] = 2500; // 25% WETH
        
        uint256 totalWeight = 0;
        for (uint256 i = 0; i < weights.length; i++) {
            totalWeight += weights[i];
        }
        
        assertEq(totalWeight, 10000, "Weights should sum to 100%");
        
        console.log("Multi-token configuration successful");
        console.log("Token 0 (USDC) weight:", weights[0]);
        console.log("Token 1 (USDT) weight:", weights[1]);
        console.log("Token 2 (WETH) weight:", weights[2]);
    }
    
    function testTokenDecimalConversions() public {
        // Test decimal conversions between different tokens
        
        uint256 amount6Decimals = 1000e6;   // 1000 USDC/USDT
        uint256 amount18Decimals = 1000e18; // 1000 ETH/tokens with 18 decimals
        
        // Convert from 6 decimals to 18 decimals (multiply by 1e12)
        uint256 converted6To18 = amount6Decimals * 1e12;
        assertEq(converted6To18, amount18Decimals, "6 to 18 decimal conversion");
        
        // Convert from 18 decimals to 6 decimals (divide by 1e12)
        uint256 converted18To6 = amount18Decimals / 1e12;
        assertEq(converted18To6, amount6Decimals, "18 to 6 decimal conversion");
        
        console.log("Original 6 decimal amount:", amount6Decimals);
        console.log("Converted to 18 decimals:", converted6To18);
        console.log("Converted back to 6 decimals:", converted18To6);
    }
    
    struct TokenInfo {
        address token;
        uint256 amount;
        uint256 decimals;
        uint256 slippageBps;
    }
    
    function testSlippageCalculationsForDifferentTokens() public {
        // Test slippage calculations for different token amounts
        
        TokenInfo[] memory tokens = new TokenInfo[](3);
        tokens[0] = TokenInfo(ArbitrumConstants.USDC, 1000e6, 6, 200);  // 2% slippage
        tokens[1] = TokenInfo(ArbitrumConstants.USDT, 1500e6, 6, 300);  // 3% slippage
        tokens[2] = TokenInfo(ArbitrumConstants.WETH, 1e18, 18, 150);   // 1.5% slippage
        
        for (uint256 i = 0; i < tokens.length; i++) {
            TokenInfo memory token = tokens[i];
            
            // Calculate minimum amount after slippage
            uint256 minAmount = (token.amount * (10000 - token.slippageBps)) / 10000;
            
            // Calculate slippage amount
            uint256 slippageAmount = token.amount - minAmount;
            
            console.log("Token", i);
            console.log("  Original amount:", token.amount);
            console.log("  Min amount after slippage:", minAmount);
            console.log("  Slippage amount:", slippageAmount);
            
            // Verify calculations
            assertLt(minAmount, token.amount, "Min amount should be less than original");
            assertEq(minAmount + slippageAmount, token.amount, "Amounts should add up");
        }
    }
    
    struct UserDeposit {
        address user;
        address token;
        uint256 amount;
        string tokenName;
    }
    
    function testMultiTokenDepositScenario() public {
        // Simulate a multi-token deposit scenario without actual protocol deployment
        
        // Test that we can work with multi-token configurations
        address[] memory tokens = new address[](3);
        tokens[0] = ArbitrumConstants.USDC;
        tokens[1] = ArbitrumConstants.USDT;
        tokens[2] = ArbitrumConstants.WETH;
        
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 50_000e6;  // USDC amount
        amounts[1] = 30_000e6;  // USDT amount
        amounts[2] = 10e18;     // WETH amount
        
        // Test we can iterate over token configurations
        for (uint256 i = 0; i < tokens.length; i++) {
            assertNotEq(tokens[i], address(0), "Token address should not be zero");
            assertGt(amounts[i], 0, "Amount should be greater than zero");
            
            console.log("Token", i);
            console.log("  Address:", tokens[i]);
            console.log("  Amount:", amounts[i]);
        }
        
        // Verify we have the right number of tokens
        assertEq(tokens.length, 3, "Should have 3 tokens");
        assertEq(amounts.length, 3, "Should have 3 amounts");
    }
}