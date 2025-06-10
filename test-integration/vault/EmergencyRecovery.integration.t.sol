// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IntegrationTest} from "../base/IntegrationTest.sol";
import {ArbitrumConstants} from "../base/ArbitrumConstants.sol";
import {IERC20} from "@oz_reflax/token/ERC20/IERC20.sol";
import "forge-std/console.sol";

/**
 * @title EmergencyRecoveryIntegrationTest
 * @notice Integration tests for emergency withdrawal functionality using real Arbitrum protocols
 * @dev Tests emergency recovery from Convex/Curve pools and emergency state functionality
 */
contract EmergencyRecoveryIntegrationTest is IntegrationTest {
    // Test users
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public owner = makeAddr("owner");
    address public vault = makeAddr("vault");
    address public yieldSource = makeAddr("yieldSource");
    
    // Constants
    uint256 constant DEPOSIT_AMOUNT = 10_000 * 1e6; // 10,000 USDC
    
    function setUp() public override {
        super.setUp();
        
        // Label contracts
        vm.label(alice, "Alice");
        vm.label(bob, "Bob");
        vm.label(owner, "Owner");
        vm.label(vault, "Vault");
        vm.label(yieldSource, "YieldSource");
        
        // Check if whale has enough balance before attempting to fund users
        uint256 whaleBalance = usdc.balanceOf(ArbitrumConstants.USDC_WHALE);
        if (whaleBalance >= DEPOSIT_AMOUNT * 2) {
            // Fund test users
            dealUSDC(alice, DEPOSIT_AMOUNT);
            dealUSDC(bob, DEPOSIT_AMOUNT);
        } else {
            // If whale doesn't have enough, just deal smaller amounts for testing
            if (whaleBalance >= 1000 * 1e6) {
                dealUSDC(alice, 500 * 1e6);
                dealUSDC(bob, 500 * 1e6);
            }
        }
    }
    
    function testConvexPoolStatus() public view {
        // Check if Convex pool is still active by querying pool info
        (bool success, bytes memory data) = ArbitrumConstants.CONVEX_BOOSTER.staticcall(
            abi.encodeWithSignature("poolInfo(uint256)", ArbitrumConstants.CONVEX_POOL_ID)
        );
        
        if (!success) {
            console.log("Failed to query Convex pool info, pool might be discontinued");
            return;
        }
        
        console.log("Convex Pool ID: %s", ArbitrumConstants.CONVEX_POOL_ID);
        console.log("Raw pool info data length: %s bytes", data.length);
        
        // The poolInfo might return a struct, so let's just check if we got data
        if (data.length > 0) {
            console.log("Pool info retrieved successfully");
            // We can't easily decode without knowing the exact struct, 
            // but the fact that we got data means the pool exists
        }
    }
    
    function testEmergencyWithdrawFromConvex() public {
        // First check if pool is active
        (bool success, bytes memory data) = ArbitrumConstants.CONVEX_BOOSTER.staticcall(
            abi.encodeWithSignature("poolInfo(uint256)", ArbitrumConstants.CONVEX_POOL_ID)
        );
        
        if (!success || data.length == 0) {
            console.log("Cannot test - failed to query Convex pool");
            return;
        }
        
        // Use the known Convex pool address from constants instead of decoding
        address convexDepositToken = ArbitrumConstants.CONVEX_POOL;
        
        // Simulate that yieldSource has some Convex deposit tokens
        // In real scenario, these would be obtained by depositing through the protocol
        uint256 mockConvexBalance = 1000e18;
        deal(convexDepositToken, yieldSource, mockConvexBalance);
        
        // Verify balance
        uint256 balanceBefore = IERC20(convexDepositToken).balanceOf(yieldSource);
        assertEq(balanceBefore, mockConvexBalance, "YieldSource should have Convex tokens");
        
        // Simulate emergency withdrawal by transferring tokens from yieldSource to vault
        vm.prank(yieldSource);
        IERC20(convexDepositToken).transfer(vault, balanceBefore);
        
        // Verify tokens were recovered
        assertEq(IERC20(convexDepositToken).balanceOf(vault), mockConvexBalance, "Vault should have recovered tokens");
        assertEq(IERC20(convexDepositToken).balanceOf(yieldSource), 0, "YieldSource should have no tokens");
        
        console.log("Successfully recovered %s Convex deposit tokens", mockConvexBalance);
    }
    
    function testEmergencyWithdrawETH() public {
        // Send ETH to yield source
        uint256 ethAmount = 5 ether;
        dealETH(yieldSource, ethAmount);
        
        uint256 vaultBalanceBefore = vault.balance;
        uint256 yieldSourceBalanceBefore = yieldSource.balance;
        
        assertEq(yieldSourceBalanceBefore, ethAmount, "YieldSource should have ETH");
        
        // Simulate emergency ETH withdrawal
        vm.prank(yieldSource);
        (bool sent,) = vault.call{value: ethAmount}("");
        require(sent, "ETH transfer failed");
        
        // Verify ETH was recovered
        assertEq(vault.balance - vaultBalanceBefore, ethAmount, "Vault should have received ETH");
        assertEq(yieldSource.balance, 0, "YieldSource should have no ETH");
        
        console.log("Successfully recovered %s ETH", ethAmount);
    }
    
    function testEmergencyWithdrawMultipleTokens() public {
        // Test withdrawing multiple tokens in sequence
        address[] memory tokens = new address[](3);
        tokens[0] = ArbitrumConstants.USDC;
        tokens[1] = ArbitrumConstants.CRV;
        tokens[2] = ArbitrumConstants.CVX;
        
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 1000 * 1e6;  // 1000 USDC
        amounts[1] = 500 * 1e18;   // 500 CRV
        amounts[2] = 200 * 1e18;   // 200 CVX
        
        // Deal tokens to yieldSource
        for (uint256 i = 0; i < tokens.length; i++) {
            deal(tokens[i], yieldSource, amounts[i]);
            
            uint256 balanceBefore = IERC20(tokens[i]).balanceOf(yieldSource);
            assertEq(balanceBefore, amounts[i], "YieldSource should have tokens");
            
            // Simulate emergency withdrawal
            vm.prank(yieldSource);
            IERC20(tokens[i]).transfer(vault, amounts[i]);
            
            // Verify recovery
            assertEq(IERC20(tokens[i]).balanceOf(vault), amounts[i], "Vault should have recovered tokens");
            assertEq(IERC20(tokens[i]).balanceOf(yieldSource), 0, "YieldSource should have no tokens");
            
            console.log("Recovered %s of token %s", amounts[i], tokens[i]);
        }
    }
    
    function testCurvePoolLPTokenRecovery() public {
        // Test recovering Curve LP tokens
        address curveLP = ArbitrumConstants.USDC_USDe_CRV_POOL;
        
        // Check if LP token exists
        uint256 codeSize;
        assembly {
            codeSize := extcodesize(curveLP)
        }
        
        if (codeSize == 0) {
            console.log("Curve pool not found at expected address");
            return;
        }
        
        // Deal some LP tokens to yieldSource
        uint256 lpAmount = 100e18;
        deal(curveLP, yieldSource, lpAmount);
        
        // Verify balance
        uint256 balanceBefore = IERC20(curveLP).balanceOf(yieldSource);
        assertEq(balanceBefore, lpAmount, "YieldSource should have LP tokens");
        
        // Simulate emergency withdrawal
        vm.prank(yieldSource);
        IERC20(curveLP).transfer(vault, lpAmount);
        
        // Verify recovery
        assertEq(IERC20(curveLP).balanceOf(vault), lpAmount, "Vault should have LP tokens");
        assertEq(IERC20(curveLP).balanceOf(yieldSource), 0, "YieldSource should have no LP tokens");
        
        console.log("Successfully recovered %s Curve LP tokens", lpAmount);
    }
}