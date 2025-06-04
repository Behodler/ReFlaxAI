// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/priceTilting/TWAPOracle.sol";
import "./mocks/Mocks.sol";

contract TWAPOracleTest is Test {
    TWAPOracle oracle;
    MockERC20 tokenA;
    MockERC20 tokenB;
    MockERC20 weth;
    MockUniswapV2Factory factory;
    MockUniswapV2Pair pair;
    address user;
    
    function setUp() public {
        // Create mock tokens
        tokenA = new MockERC20();
        tokenB = new MockERC20();
        weth = new MockERC20();
        
        // Create mock factory
        factory = new MockUniswapV2Factory();
        
        // Create mock pair
        pair = new MockUniswapV2Pair(address(tokenA), address(tokenB));
        factory.setPair(address(tokenA), address(tokenB), address(pair));
        
        // Create WETH pair
        MockUniswapV2Pair wethPair = new MockUniswapV2Pair(address(tokenA), address(weth));
        factory.setPair(address(tokenA), address(weth), address(wethPair));
        
        // Deploy TWAPOracle
        oracle = new TWAPOracle(address(factory), address(weth));
        
        // Set up initial reserves and timestamp
        uint112 reserve0 = 100 ether;
        uint112 reserve1 = 200 ether;
        uint32 timestamp = uint32(block.timestamp);
        pair.updateReserves(reserve0, reserve1, timestamp);
        
        // Set initial price cumulatives for price averaging
        uint256 price0Cumulative = 5000 * 1e18; // price0 = reserve1/reserve0 = 2
        uint256 price1Cumulative = 2500 * 1e18; // price1 = reserve0/reserve1 = 0.5
        pair.setPriceCumulativeLast(price0Cumulative, price1Cumulative);
        
        // Set up test user
        user = address(0xBEEF);
    }
    
    function testUpdateInitializesPair() public {
        // First update should just initialize
        oracle.update(address(tokenA), address(tokenB));
        
        // Try to consult right after initialization should revert
        vm.expectRevert("Pair not initialized");
        oracle.consult(address(tokenA), address(tokenB), 1 ether);
        
        // Move time forward
        vm.warp(block.timestamp + 1 hours);
        
        // Update reserves with new timestamp
        uint112 reserve0 = 110 ether;
        uint112 reserve1 = 230 ether;
        uint32 timestamp = uint32(block.timestamp);
        pair.updateReserves(reserve0, reserve1, timestamp);
        
        // Update price cumulatives
        uint256 price0Cumulative = 7200 * 1e18; // avg price0 = 2.2 over 1 hour
        uint256 price1Cumulative = 3590 * 1e18; // avg price1 = 0.455 over 1 hour
        pair.setPriceCumulativeLast(price0Cumulative, price1Cumulative);
        
        // Second update should record prices
        oracle.update(address(tokenA), address(tokenB));
        
        // Now consult should work
        uint256 amountOut = oracle.consult(address(tokenA), address(tokenB), 1 ether);
        
        // Price should be around 2.2
        assertApproxEqAbs(amountOut, 2.2 ether, 0.01 ether, "Price should be approximately 2.2");
    }
    
    function testConsultAfterUpdate() public {
        // Initialize pair
        oracle.update(address(tokenA), address(tokenB));
        
        // Move time forward
        vm.warp(block.timestamp + 1 hours);
        
        // Update reserves with new timestamp
        uint112 reserve0 = 120 ether;
        uint112 reserve1 = 300 ether;
        uint32 timestamp = uint32(block.timestamp);
        pair.updateReserves(reserve0, reserve1, timestamp);
        
        // Update price cumulatives - price ratio is 2.5
        uint256 price0Cumulative = 9000 * 1e18; // avg price0 = 2.5 over 1 hour
        uint256 price1Cumulative = 3600 * 1e18; // avg price1 = 0.4 over 1 hour
        pair.setPriceCumulativeLast(price0Cumulative, price1Cumulative);
        
        // Update oracle
        oracle.update(address(tokenA), address(tokenB));
        
        // Consult token0 -> token1 price
        uint256 amountOut1 = oracle.consult(address(tokenA), address(tokenB), 1 ether);
        
        // Consult token1 -> token0 price
        uint256 amountOut2 = oracle.consult(address(tokenB), address(tokenA), 1 ether);
        
        // Verify prices
        assertApproxEqAbs(amountOut1, 2.5 ether, 0.01 ether, "Token0 -> Token1 price should be approximately 2.5");
        assertApproxEqAbs(amountOut2, 0.4 ether, 0.01 ether, "Token1 -> Token0 price should be approximately 0.4");
    }
    
    function testMultipleUpdates() public {
        // Initialize pair
        oracle.update(address(tokenA), address(tokenB));
        
        for (uint256 i = 0; i < 3; i++) {
            // Move time forward
            vm.warp(block.timestamp + 1 hours);
            
            // Update reserves with new timestamp and increasing price
            uint112 reserve0 = 100 ether;
            uint112 reserve1 = 200 ether + uint112(i * 50 ether);
            uint32 timestamp = uint32(block.timestamp);
            pair.updateReserves(reserve0, reserve1, timestamp);
            
            // Update price cumulatives
            uint256 price0Cumulative = 5000 * 1e18 + (i + 1) * 2000 * 1e18;
            uint256 price1Cumulative = 2500 * 1e18 - (i + 1) * 200 * 1e18;
            pair.setPriceCumulativeLast(price0Cumulative, price1Cumulative);
            
            // Update oracle
            oracle.update(address(tokenA), address(tokenB));
            
            // Consult token0 -> token1 price
            uint256 amountOut = oracle.consult(address(tokenA), address(tokenB), 1 ether);
            
            // Verify price increases with each update
            uint256 expectedPrice = 2 ether + (i + 1) * 0.5 ether;
            assertApproxEqAbs(amountOut, expectedPrice, 0.01 ether, "Price should increase with each update");
        }
    }
    
    function testWETHPricing() public {
        // Create WETH pair and setup
        MockUniswapV2Pair wethPair = new MockUniswapV2Pair(address(tokenA), address(weth));
        factory.setPair(address(tokenA), address(weth), address(wethPair));
        
        // Set up initial reserves and timestamp
        uint112 reserve0 = 100 ether;
        uint112 reserve1 = 50 ether; // 0.5 ETH per tokenA
        uint32 timestamp = uint32(block.timestamp);
        wethPair.updateReserves(reserve0, reserve1, timestamp);
        
        // Set initial price cumulatives for price averaging
        uint256 price0Cumulative = 2500 * 1e18; // price0 = reserve1/reserve0 = 0.5
        uint256 price1Cumulative = 5000 * 1e18; // price1 = reserve0/reserve1 = 2
        wethPair.setPriceCumulativeLast(price0Cumulative, price1Cumulative);
        
        // Initialize pair
        oracle.update(address(tokenA), address(weth));
        
        // Move time forward
        vm.warp(block.timestamp + 1 hours);
        
        // Update reserves with new timestamp
        reserve0 = 100 ether;
        reserve1 = 60 ether; // 0.6 ETH per tokenA
        timestamp = uint32(block.timestamp);
        wethPair.updateReserves(reserve0, reserve1, timestamp);
        
        // Update price cumulatives
        price0Cumulative = 3300 * 1e18; // avg price0 = 0.55 over 1 hour
        price1Cumulative = 5900 * 1e18; // avg price1 = 1.8 over 1 hour
        wethPair.setPriceCumulativeLast(price0Cumulative, price1Cumulative);
        
        // Update oracle
        oracle.update(address(tokenA), address(weth));
        
        // Consult token -> ETH price
        uint256 ethOut = oracle.consult(address(tokenA), address(0), 1 ether);
        
        // Verify ETH price
        assertApproxEqAbs(ethOut, 0.55 ether, 0.01 ether, "Token -> ETH price should be approximately 0.55 ETH");
    }
    
    function testUpdateRequiresPair() public {
        // Try to update a non-existent pair
        vm.expectRevert("Invalid pair");
        oracle.update(address(tokenA), address(0xDEAD));
    }
    
    function testConsultRequiresPair() public {
        // Try to consult a non-existent pair
        vm.expectRevert("Invalid pair");
        oracle.consult(address(tokenA), address(0xDEAD), 1 ether);
    }
    
    function testConsultRequiresInitialization() public {
        // Create new pair
        MockERC20 tokenC = new MockERC20();
        MockUniswapV2Pair newPair = new MockUniswapV2Pair(address(tokenA), address(tokenC));
        factory.setPair(address(tokenA), address(tokenC), address(newPair));
        
        // Try to consult without initializing
        vm.expectRevert("Pair not initialized");
        oracle.consult(address(tokenA), address(tokenC), 1 ether);
    }
    
    function testConsultRequiresNonZeroOutput() public {
        // Initialize pair
        oracle.update(address(tokenA), address(tokenB));
        
        // Move time forward
        vm.warp(block.timestamp + 1 hours);
        
        // Update reserves with new timestamp
        uint112 reserve0 = 0; // Zero reserve will cause issues
        uint112 reserve1 = 200 ether;
        uint32 timestamp = uint32(block.timestamp);
        pair.updateReserves(reserve0, reserve1, timestamp);
        
        // Update price cumulatives (invalid values due to division by zero)
        uint256 price0Cumulative = 0;
        uint256 price1Cumulative = 0;
        pair.setPriceCumulativeLast(price0Cumulative, price1Cumulative);
        
        // Update oracle
        oracle.update(address(tokenA), address(tokenB));
        
        // Try to consult with invalid price data
        vm.expectRevert("Zero output");
        oracle.consult(address(tokenB), address(tokenA), 1 ether);
    }
} 