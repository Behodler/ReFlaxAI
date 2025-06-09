// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IntegrationTest} from "../base/IntegrationTest.sol";
import {ArbitrumConstants} from "../base/ArbitrumConstants.sol";
import {IERC20} from "@oz_reflax/token/ERC20/IERC20.sol";
import {ICurvePool} from "../../src/yieldSource/CVX_CRV_YieldSource.sol";
import {IConvexBooster} from "../../src/yieldSource/CVX_CRV_YieldSource.sol";

/**
 * @title SimpleDepositIntegrationTest
 * @notice Simple integration test to verify interaction with real Arbitrum contracts
 * @dev Tests basic deposit flow into Curve and Convex
 */
contract SimpleDepositIntegrationTest is IntegrationTest {
    
    // Test user
    address public user = address(0x1234);
    
    // Constants
    uint256 constant DEPOSIT_AMOUNT = 1000e6; // 1000 USDC
    
    function setUp() public override {
        super.setUp();
        
        // Deal USDC to test user
        dealUSDC(user, DEPOSIT_AMOUNT);
        
        // Label test user
        vm.label(user, "TestUser");
    }
    
    /**
     * @notice Test that we can interact with the real Curve pool
     */
    function testCurvePoolExists() public {
        // Verify the Curve pool exists and we can call it
        ICurvePool pool = ICurvePool(ArbitrumConstants.USDC_USDe_CRV_POOL);
        
        // Try to get the first coin (should be USDC)
        address coin0 = pool.coins(0);
        assertEq(coin0, ArbitrumConstants.USDC, "First coin should be USDC");
        
        // Try to get the second coin (should be USDe)
        address coin1 = pool.coins(1);
        assertEq(coin1, ArbitrumConstants.USDe, "Second coin should be USDe");
    }
    
    /**
     * @notice Test that we can interact with the real Convex booster
     */
    function testConvexBoosterExists() public {
        // Verify the Convex booster exists
        IConvexBooster booster = IConvexBooster(ArbitrumConstants.CONVEX_BOOSTER);
        
        // The booster should exist at the expected address
        uint256 size;
        assembly {
            size := extcodesize(booster)
        }
        assertGt(size, 0, "Convex booster should have code");
    }
    
    /**
     * @notice Test a simple deposit flow into Curve
     */
    function testSimpleCurveDeposit() public {
        ICurvePool pool = ICurvePool(ArbitrumConstants.USDC_USDe_CRV_POOL);
        
        vm.startPrank(user);
        
        // Approve Curve pool to spend USDC
        usdc.approve(address(pool), DEPOSIT_AMOUNT);
        
        // Get initial LP token balance (the pool itself is the LP token)
        uint256 lpBalanceBefore = IERC20(address(pool)).balanceOf(user);
        
        // Add liquidity with just USDC (index 0)
        uint256[4] memory amounts;
        amounts[0] = DEPOSIT_AMOUNT;
        // Other amounts remain 0
        
        // Add liquidity
        uint256 lpReceived = pool.add_liquidity(amounts, 0); // 0 min to avoid slippage revert in test
        
        // Verify we received LP tokens
        uint256 lpBalanceAfter = IERC20(address(pool)).balanceOf(user);
        assertGt(lpBalanceAfter, lpBalanceBefore, "Should have received LP tokens");
        assertEq(lpBalanceAfter - lpBalanceBefore, lpReceived, "LP balance change should match returned amount");
        
        vm.stopPrank();
    }
    
    /**
     * @notice Test that whale addresses have sufficient balance
     */
    function testWhaleBalances() public {
        // Check USDC whale has balance
        uint256 usdcWhaleBalance = usdc.balanceOf(ArbitrumConstants.USDC_WHALE);
        assertGt(usdcWhaleBalance, 1000000e6, "USDC whale should have at least 1M USDC");
        
        // Check USDe whale has balance
        uint256 usdeWhaleBalance = usde.balanceOf(ArbitrumConstants.USDe_WHALE);
        assertGt(usdeWhaleBalance, 1000000e18, "USDe whale should have at least 1M USDe");
    }
}