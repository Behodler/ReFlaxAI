// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IntegrationTest} from "../base/IntegrationTest.sol";
import {ArbitrumConstants} from "../base/ArbitrumConstants.sol";
import {IERC20} from "@oz_reflax/token/ERC20/IERC20.sol";
import {ICurvePool} from "../../src/yieldSource/CVX_CRV_YieldSource.sol";
import {IConvexBooster} from "../../src/yieldSource/CVX_CRV_YieldSource.sol";

// Interface for 2-token Curve pools
interface ICurvePool2 {
    function add_liquidity(uint256[2] memory amounts, uint256 min_mint_amount) external payable returns (uint256);
    function remove_liquidity_one_coin(uint256 token_amount, int128 i, uint256 min_amount) external returns (uint256);
    function coins(uint256 i) external view returns (address);
    function get_virtual_price() external view returns (uint256);
}

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
    function testCurvePoolExists() public view {
        // Verify the Curve pool exists and we can call it
        ICurvePool2 pool = ICurvePool2(ArbitrumConstants.USDC_USDe_CRV_POOL);
        
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
    function testConvexBoosterExists() public view {
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
     * @notice Test pool virtual price getter
     */
    function testPoolVirtualPrice() public view {
        ICurvePool2 pool = ICurvePool2(ArbitrumConstants.USDC_USDe_CRV_POOL);
        uint256 virtualPrice = pool.get_virtual_price();
        assertGt(virtualPrice, 0, "Virtual price should be greater than 0");
    }

    /**
     * @notice Test pool interaction demonstrating the interface mismatch
     * @dev This test shows that the USDC/USDe pool is a 2-token pool, not 4-token
     * The CVX_CRV_YieldSource would need to be updated to support 2-token pools
     */
    function testCurvePoolInterface() public {
        // The pool exists and we can interact with it using the correct 2-token interface
        ICurvePool2 pool = ICurvePool2(ArbitrumConstants.USDC_USDe_CRV_POOL);
        
        // Verify it's a 2-token pool by checking coins
        address coin0 = pool.coins(0);
        address coin1 = pool.coins(1);
        assertEq(coin0, ArbitrumConstants.USDC, "First coin should be USDC");
        assertEq(coin1, ArbitrumConstants.USDe, "Second coin should be USDe");
        
        // Try to access coin index 2 (should revert for 2-token pool)
        vm.expectRevert();
        pool.coins(2);
        
        // Show that we can get the virtual price
        uint256 virtualPrice = pool.get_virtual_price();
        assertGt(virtualPrice, 0, "Virtual price should be greater than 0");
        
        // Note: The CVX_CRV_YieldSource uses a hardcoded uint256[4] interface
        // which is incompatible with this 2-token pool
    }
    
    /**
     * @notice Test that whale addresses have sufficient balance
     */
    function testWhaleBalances() public view {
        // Check USDC whale has balance
        uint256 usdcWhaleBalance = usdc.balanceOf(ArbitrumConstants.USDC_WHALE);
        assertGt(usdcWhaleBalance, 1000000e6, "USDC whale should have at least 1M USDC");
        
        // Check USDe whale has balance
        uint256 usdeWhaleBalance = usde.balanceOf(ArbitrumConstants.USDe_WHALE);
        assertGt(usdeWhaleBalance, 1000e18, "USDe whale should have at least 1K USDe");
    }
}