// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "./mocks/Mocks.sol";

contract CurvePoolSlippageTest is Test {
    MockCurvePool curvePool;
    MockERC20 lpToken;
    MockERC20 token1;
    MockERC20 token2;
    
    function setUp() public {
        lpToken = new MockERC20();
        curvePool = new MockCurvePool(address(lpToken));
        
        token1 = new MockERC20();
        token2 = new MockERC20();
        
        // Set up 2-token pool
        address[] memory poolTokens = new address[](2);
        poolTokens[0] = address(token1);
        poolTokens[1] = address(token2);
        curvePool.setPoolTokens(poolTokens);
        
        // Mint tokens to test user
        token1.mint(address(this), 1000e18);
        token2.mint(address(this), 1000e18);
        
        // Approve curve pool
        token1.approve(address(curvePool), type(uint256).max);
        token2.approve(address(curvePool), type(uint256).max);
    }
    
    function testNoSlippageByDefault() public {
        uint256[2] memory amounts = [uint256(100e18), uint256(200e18)];
        
        // Calculate expected LP tokens
        uint256 expectedLP = curvePool.calc_token_amount(amounts, true);
        assertEq(expectedLP, 300e18, "Expected LP should be sum without slippage");
        
        // Add liquidity
        uint256 lpReceived = curvePool.add_liquidity(amounts, 0);
        assertEq(lpReceived, 300e18, "Should receive full amount with no slippage");
        assertEq(lpToken.balanceOf(address(this)), 300e18, "LP balance should match");
    }
    
    function testSlippageAppliedToAddLiquidity() public {
        // Set 5% slippage (500 basis points)
        curvePool.setSlippage(500);
        
        uint256[2] memory amounts = [uint256(100e18), uint256(200e18)];
        
        // Calculate expected LP tokens
        uint256 expectedLP = curvePool.calc_token_amount(amounts, true);
        assertEq(expectedLP, 285e18, "Expected LP should be 95% of sum (5% slippage)");
        
        // Add liquidity
        uint256 lpReceived = curvePool.add_liquidity(amounts, 0);
        assertEq(lpReceived, 285e18, "Should receive 95% of full amount");
        assertEq(lpToken.balanceOf(address(this)), 285e18, "LP balance should match");
    }
    
    function testSlippageAppliedToRemoveLiquidity() public {
        // First add liquidity
        uint256[2] memory amounts = [uint256(100e18), uint256(100e18)];
        curvePool.add_liquidity(amounts, 0);
        
        // Set 10% slippage (1000 basis points)
        curvePool.setSlippage(1000);
        
        // Remove liquidity
        uint256 lpBalance = lpToken.balanceOf(address(this));
        lpToken.approve(address(curvePool), lpBalance);
        
        uint256 token1Before = token1.balanceOf(address(this));
        uint256 returnedAmount = curvePool.remove_liquidity_one_coin(lpBalance, 0, 0);
        uint256 token1After = token1.balanceOf(address(this));
        
        assertEq(returnedAmount, 180e18, "Should receive 90% of LP amount");
        assertEq(token1After - token1Before, 180e18, "Token balance should increase by 90% of LP");
    }
    
    function testCalcTokenAmountWithSlippage() public {
        // Test with different slippage values
        uint256[2] memory amounts = [uint256(1000e18), uint256(1000e18)];
        
        // 0% slippage
        curvePool.setSlippage(0);
        assertEq(curvePool.calc_token_amount(amounts, true), 2000e18, "0% slippage");
        
        // 1% slippage
        curvePool.setSlippage(100);
        assertEq(curvePool.calc_token_amount(amounts, true), 1980e18, "1% slippage");
        
        // 25% slippage
        curvePool.setSlippage(2500);
        assertEq(curvePool.calc_token_amount(amounts, true), 1500e18, "25% slippage");
        
        // 50% slippage
        curvePool.setSlippage(5000);
        assertEq(curvePool.calc_token_amount(amounts, true), 1000e18, "50% slippage");
    }
    
    function testCannotSetSlippageAbove100Percent() public {
        vm.expectRevert("Slippage cannot exceed 100%");
        curvePool.setSlippage(10001);
    }
    
    function testSlippageWith3TokenPool() public {
        // Set up 3-token pool
        MockERC20 token3 = new MockERC20();
        token3.mint(address(this), 1000e18);
        token3.approve(address(curvePool), type(uint256).max);
        
        address[] memory poolTokens = new address[](3);
        poolTokens[0] = address(token1);
        poolTokens[1] = address(token2);
        poolTokens[2] = address(token3);
        curvePool.setPoolTokens(poolTokens);
        
        // Set 20% slippage
        curvePool.setSlippage(2000);
        
        uint256[3] memory amounts = [uint256(100e18), uint256(200e18), uint256(300e18)];
        
        // Calculate expected LP tokens
        uint256 expectedLP = curvePool.calc_token_amount(amounts, true);
        assertEq(expectedLP, 480e18, "Expected LP should be 80% of sum (20% slippage)");
        
        // Add liquidity
        uint256 lpReceived = curvePool.add_liquidity(amounts, 0);
        assertEq(lpReceived, 480e18, "Should receive 80% of full amount");
    }
}