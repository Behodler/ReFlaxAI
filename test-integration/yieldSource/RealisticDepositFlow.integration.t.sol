// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IntegrationTest} from "../base/IntegrationTest.sol";
import {ArbitrumConstants} from "../base/ArbitrumConstants.sol";
import {IERC20} from "@oz_reflax/token/ERC20/IERC20.sol";
import {console} from "forge-std/console.sol";

// Interface for newer Curve pools (StableSwapNG)
interface ICurvePoolNG {
    function add_liquidity(uint256[] memory amounts, uint256 min_mint_amount) external payable returns (uint256);
    function remove_liquidity_one_coin(uint256 token_amount, int128 i, uint256 min_amount) external returns (uint256);
    function coins(uint256 i) external view returns (address);
    function get_virtual_price() external view returns (uint256);
    function calc_token_amount(uint256[] memory amounts, bool is_deposit) external view returns (uint256);
    function balances(uint256 i) external view returns (uint256);
}

/**
 * @title RealisticDepositFlowIntegrationTest
 * @notice Tests realistic deposit flow calculations with actual Curve pool
 * @dev This test demonstrates how deposits should be validated with realistic LP token expectations
 */
contract RealisticDepositFlowIntegrationTest is IntegrationTest {
    // Real Curve pool
    ICurvePoolNG public curvePool;
    
    // Test users
    address public alice = address(0x1111);
    address public bob = address(0x2222);
    address public charlie = address(0x3333);
    
    // Constants
    uint256 constant SLIPPAGE_TOLERANCE = 500; // 5% = 500 basis points
    
    function setUp() public override {
        super.setUp();
        
        curvePool = ICurvePoolNG(ArbitrumConstants.USDC_USDe_CRV_POOL);
        
        // Label addresses
        vm.label(alice, "Alice");
        vm.label(bob, "Bob");
        vm.label(charlie, "Charlie");
        vm.label(address(curvePool), "CurvePool");
    }
    
    /**
     * @notice Test realistic LP token calculations from Curve pool
     * @dev This demonstrates the correct way to calculate expected LP tokens
     */
    function testRealisticLPCalculations() public view {
        // Test various deposit amounts
        uint256[4] memory depositAmounts = [
            uint256(100e6),    // 100 USDC
            uint256(1_000e6),  // 1,000 USDC
            uint256(10_000e6), // 10,000 USDC
            uint256(100_000e6) // 100,000 USDC
        ];
        
        for (uint i = 0; i < depositAmounts.length; i++) {
            uint256 depositAmount = depositAmounts[i];
            
            // Calculate expected LP tokens for single-sided deposit
            uint256[] memory amounts = new uint256[](2);
            amounts[0] = depositAmount;
            amounts[1] = 0;
            uint256 expectedLp = curvePool.calc_token_amount(amounts, true);
            
            // Get current pool state
            uint256 virtualPrice = curvePool.get_virtual_price();
            uint256 usdcBalance = curvePool.balances(0);
            uint256 usdeBalance = curvePool.balances(1);
            
            console.log("=== Deposit Amount:", depositAmount / 1e6, "USDC ===");
            console.log("Expected LP tokens:", expectedLp);
            console.log("Virtual Price:", virtualPrice);
            console.log("Pool USDC Balance:", usdcBalance / 1e6);
            console.log("Pool USDe Balance:", usdeBalance / 1e18);
            console.log("---");
        }
    }
    
    /**
     * @notice Test that demonstrates correct bounds for LP token expectations
     * @dev Shows how to properly validate LP tokens with slippage tolerance
     */
    function testLPTokenBounds() public {
        // Setup user with USDC
        uint256 depositAmount = 10_000e6; // 10,000 USDC
        dealUSDC(alice, depositAmount);
        
        // Calculate expected LP tokens
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = depositAmount;
        amounts[1] = 0;
        uint256 expectedLp = curvePool.calc_token_amount(amounts, true);
        
        // Approve and add liquidity
        vm.startPrank(alice);
        usdc.approve(address(curvePool), depositAmount);
        
        // Add liquidity with 0.5% slippage protection
        uint256 minLp = expectedLp * 995 / 1000;
        uint256 actualLp = curvePool.add_liquidity(amounts, minLp);
        vm.stopPrank();
        
        // Verify LP tokens are within expected bounds
        assertGe(actualLp, minLp, "LP tokens below minimum");
        assertLe(actualLp, expectedLp * 1005 / 1000, "LP tokens above maximum expected");
        
        // Calculate actual slippage
        uint256 slippageBps = expectedLp > actualLp 
            ? ((expectedLp - actualLp) * 10000) / expectedLp
            : ((actualLp - expectedLp) * 10000) / expectedLp;
            
        console.log("Expected LP:", expectedLp);
        console.log("Actual LP:", actualLp);
        console.log("Slippage (bps):", slippageBps);
        
        // Assert slippage is within tolerance
        assertLe(slippageBps, SLIPPAGE_TOLERANCE, "Slippage exceeds tolerance");
    }
    
    /**
     * @notice Test pool imbalance effects on LP calculations
     * @dev Shows how pool imbalance affects LP token amounts
     */
    function testPoolImbalanceEffects() public view {
        // Get current pool state
        uint256 usdcBalance = curvePool.balances(0);
        uint256 usdeBalance = curvePool.balances(1);
        uint256 totalValue = usdcBalance + (usdeBalance / 1e12); // Convert USDe to 6 decimals
        
        // Calculate imbalance
        uint256 usdcRatio = (usdcBalance * 10000) / totalValue;
        uint256 usdeRatio = ((usdeBalance / 1e12) * 10000) / totalValue;
        
        console.log("Pool Imbalance Analysis:");
        console.log("USDC Ratio:", usdcRatio / 100, "%");
        console.log("USDe Ratio:", usdeRatio / 100, "%");
        
        // Test LP calculations with different deposit sizes
        uint256[3] memory testAmounts = [
            uint256(1_000e6),
            uint256(10_000e6),
            uint256(100_000e6)
        ];
        
        for (uint i = 0; i < testAmounts.length; i++) {
            uint256 amount = testAmounts[i];
            
            // Single-sided USDC deposit
            uint256[] memory usdcOnly = new uint256[](2);
            usdcOnly[0] = amount;
            usdcOnly[1] = 0;
            uint256 lpFromUsdc = curvePool.calc_token_amount(usdcOnly, true);
            
            // Single-sided USDe deposit (converted to 18 decimals)
            uint256[] memory usdeOnly = new uint256[](2);
            usdeOnly[0] = 0;
            usdeOnly[1] = amount * 1e12;
            uint256 lpFromUsde = curvePool.calc_token_amount(usdeOnly, true);
            
            // Balanced deposit
            uint256[] memory balanced = new uint256[](2);
            balanced[0] = amount / 2;
            balanced[1] = (amount / 2) * 1e12;
            uint256 lpFromBalanced = curvePool.calc_token_amount(balanced, true);
            
            console.log("--- Deposit:", amount / 1e6, "USD equivalent ---");
            console.log("LP from USDC only:", lpFromUsdc);
            console.log("LP from USDe only:", lpFromUsde);
            console.log("LP from balanced:", lpFromBalanced);
            
            // Calculate bonus/penalty for balanced deposits
            uint256 avgSingleSided = (lpFromUsdc + lpFromUsde) / 2;
            if (lpFromBalanced > avgSingleSided) {
                uint256 bonus = ((lpFromBalanced - avgSingleSided) * 10000) / avgSingleSided;
                console.log("Balanced deposit bonus:", bonus, "bps");
            } else {
                uint256 penalty = ((avgSingleSided - lpFromBalanced) * 10000) / avgSingleSided;
                console.log("Balanced deposit penalty:", penalty, "bps");
            }
        }
    }
    
    /**
     * @notice Test multiple sequential deposits
     * @dev Shows how to properly track LP tokens across multiple deposits
     */
    function testMultipleSequentialDeposits() public {
        // Setup users
        dealUSDC(alice, 10_000e6);
        dealUSDC(bob, 20_000e6);
        dealUSDC(charlie, 15_000e6);
        
        uint256 totalExpectedLp = 0;
        uint256 totalActualLp = 0;
        
        // Alice deposits 5,000 USDC
        vm.startPrank(alice);
        usdc.approve(address(curvePool), 5_000e6);
        uint256[] memory aliceAmounts = new uint256[](2);
        aliceAmounts[0] = 5_000e6;
        aliceAmounts[1] = 0;
        uint256 aliceExpected = curvePool.calc_token_amount(aliceAmounts, true);
        uint256 aliceActual = curvePool.add_liquidity(aliceAmounts, aliceExpected * 995 / 1000);
        vm.stopPrank();
        
        totalExpectedLp += aliceExpected;
        totalActualLp += aliceActual;
        
        console.log("Alice deposit - Expected:", aliceExpected, "Actual:", aliceActual);
        
        // Bob deposits 10,000 USDC
        vm.startPrank(bob);
        usdc.approve(address(curvePool), 10_000e6);
        uint256[] memory bobAmounts = new uint256[](2);
        bobAmounts[0] = 10_000e6;
        bobAmounts[1] = 0;
        uint256 bobExpected = curvePool.calc_token_amount(bobAmounts, true);
        uint256 bobActual = curvePool.add_liquidity(bobAmounts, bobExpected * 995 / 1000);
        vm.stopPrank();
        
        totalExpectedLp += bobExpected;
        totalActualLp += bobActual;
        
        console.log("Bob deposit - Expected:", bobExpected, "Actual:", bobActual);
        
        // Charlie deposits 7,500 USDC
        vm.startPrank(charlie);
        usdc.approve(address(curvePool), 7_500e6);
        uint256[] memory charlieAmounts = new uint256[](2);
        charlieAmounts[0] = 7_500e6;
        charlieAmounts[1] = 0;
        uint256 charlieExpected = curvePool.calc_token_amount(charlieAmounts, true);
        uint256 charlieActual = curvePool.add_liquidity(charlieAmounts, charlieExpected * 995 / 1000);
        vm.stopPrank();
        
        totalExpectedLp += charlieExpected;
        totalActualLp += charlieActual;
        
        console.log("Charlie deposit - Expected:", charlieExpected, "Actual:", charlieActual);
        
        // Verify total LP tokens are within expected bounds
        uint256 totalSlippageBps = totalExpectedLp > totalActualLp
            ? ((totalExpectedLp - totalActualLp) * 10000) / totalExpectedLp
            : ((totalActualLp - totalExpectedLp) * 10000) / totalExpectedLp;
            
        console.log("Total Expected LP:", totalExpectedLp);
        console.log("Total Actual LP:", totalActualLp);
        console.log("Total Slippage (bps):", totalSlippageBps);
        
        assertLe(totalSlippageBps, SLIPPAGE_TOLERANCE, "Total slippage exceeds tolerance");
    }
    
    /**
     * @notice Helper function to demonstrate proper LP validation
     * @dev This shows the pattern that should be used in the main deposit flow tests
     */
    function validateLPTokens(
        uint256 expectedLp,
        uint256 actualLp,
        uint256 toleranceBps,
        string memory context
    ) internal pure {
        // Calculate bounds
        uint256 minAcceptable = expectedLp * (10000 - toleranceBps) / 10000;
        uint256 maxAcceptable = expectedLp * (10000 + toleranceBps) / 10000;
        
        // Validate
        require(actualLp >= minAcceptable, string.concat(context, ": LP below minimum"));
        require(actualLp <= maxAcceptable, string.concat(context, ": LP above maximum"));
    }
}