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
    uint256 constant Q112 = 2**112;
    
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
        uint32 initialTimestamp = uint32(block.timestamp);
        pair.updateReserves(reserve0, reserve1, initialTimestamp);
        
        // Set initial price cumulatives for price averaging
        uint256 price0Cumulative = 5000; 
        uint256 price1Cumulative = 2500; 
        pair.setPriceCumulativeLast(price0Cumulative, price1Cumulative);
        
        // Set up test user
        user = address(0xBEEF);
    }
    
    function testUpdateInitializesPair() public {
        uint256 initialP0C = 5000;
        uint256 initialP1C = 2500;
        uint256 deltaTime = 1 hours;

        // First update should just initialize
        oracle.update(address(tokenA), address(tokenB));
        
        // Try to consult right after initialization should revert because averages are not calculated yet, leading to zero output.
        vm.expectRevert("TWAPOracle: ZERO_OUTPUT_AMOUNT");
        oracle.consult(address(tokenA), address(tokenB), 1 ether);
        
        // Move time forward
        vm.warp(block.timestamp + deltaTime);
        
        // Update reserves with new timestamp
        uint112 reserve0 = 110 ether;
        uint112 reserve1 = 230 ether;
        uint32 currentPairTimestamp = uint32(block.timestamp);
        pair.updateReserves(reserve0, reserve1, currentPairTimestamp);
        
        // Update price cumulatives for target average price of 2.2 (11/5) for token0/token1
        // and 1/2.2 (5/11) for token1/token0
        uint256 targetP0C = initialP0C + (11 * Q112 * deltaTime) / 5;
        uint256 targetP1C = initialP1C + (5 * Q112 * deltaTime) / 11;
        pair.setPriceCumulativeLast(targetP0C, targetP1C);
        
        // Second update should record prices
        oracle.update(address(tokenA), address(tokenB));
        
        // Now consult should work
        uint256 amountOut = oracle.consult(address(tokenA), address(tokenB), 1 ether);
        
        // Price should be around 2.2
        assertApproxEqAbs(amountOut, 2.2 ether, 0.01 ether, "Price should be approximately 2.2");
    }
    
    function testConsultAfterUpdate() public {
        uint256 initialP0C = 5000;
        uint256 initialP1C = 2500;
        uint256 deltaTime = 1 hours; // 3600 seconds

        // Initialize pair: oracle stores initialP0C and initialP1C from setUp
        oracle.update(address(tokenA), address(tokenB));
        
        // Move time forward
        vm.warp(block.timestamp + deltaTime);
        
        // Update reserves with new timestamp
        uint112 reserve0 = 120 ether;
        uint112 reserve1 = 300 ether;
        uint32 currentPairTimestamp = uint32(block.timestamp);
        pair.updateReserves(reserve0, reserve1, currentPairTimestamp);
        
        // Calculate target cumulative prices for desired average rates
        // Target P_ratio0 = 2.5 (5/2)
        uint256 targetP0C = initialP0C + (5 * Q112 * deltaTime) / 2;
        // Target P_ratio1 = 0.4 (2/5)
        uint256 targetP1C = initialP1C + (2 * Q112 * deltaTime) / 5;
        pair.setPriceCumulativeLast(targetP0C, targetP1C);
        
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
        uint256 oracleInternalP0C = 5000;
        uint256 oracleInternalP1C = 2500;
        uint256 deltaTime = 1 hours;

        // Initialize pair
        oracle.update(address(tokenA), address(tokenB));
        
        for (uint256 i = 0; i < 3; i++) {
            // Move time forward
            vm.warp(block.timestamp + deltaTime);
            
            // Update reserves with new timestamp and increasing price
            uint112 reserve0 = 100 ether;
            uint112 reserve1 = 200 ether + uint112(i * 50 ether); // Spot price for token0/token1: 2.0, 2.5, 3.0
            uint32 currentPairTimestamp = uint32(block.timestamp);
            pair.updateReserves(reserve0, reserve1, currentPairTimestamp);
            
            // Target average price for token0/token1 over this period is 2.0 + (i+1)*0.5 ether
            // P0_ratio = (4 + (i+1))/2 = (5+i)/2
            uint256 targetP0Numerator = 5 + i;
            uint256 targetP0Denominator = 2;
            uint256 deltaP0C = (targetP0Numerator * Q112 * deltaTime) / targetP0Denominator;
            uint256 currentP0CForPair = oracleInternalP0C + deltaP0C;

            // Target average price for token1/token0 over this period is P1_ratio = 2 / (5+i)
            uint256 targetP1Numerator = 2;
            uint256 targetP1Denominator = 5 + i;
            uint256 deltaP1C = (targetP1Numerator * Q112 * deltaTime) / targetP1Denominator;
            uint256 currentP1CForPair = oracleInternalP1C + deltaP1C;
            
            pair.setPriceCumulativeLast(currentP0CForPair, currentP1CForPair);
            
            // Update oracle
            oracle.update(address(tokenA), address(tokenB));

            // Update internal trackers for next iteration
            oracleInternalP0C = currentP0CForPair;
            oracleInternalP1C = currentP1CForPair;
            
            // Consult token0 -> token1 price
            uint256 amountOut = oracle.consult(address(tokenA), address(tokenB), 1 ether);
            
            // Verify price increases with each update
            uint256 expectedPrice = (targetP0Numerator * 1 ether) / targetP0Denominator;
            assertApproxEqAbs(amountOut, expectedPrice, 0.01 ether, "Price should match target average");
        }
    }
    
    function testWETHPricing() public {
        // Start at a reasonable timestamp
        vm.warp(10 hours);
        
        // Get the WETH pair instance
        MockUniswapV2Pair wethPair = MockUniswapV2Pair(factory.getPair(address(tokenA), address(weth)));
        
        // Step 1: Set up initial state at time T0
        uint256 startTime = block.timestamp;
        uint112 reserve0_initial = 100 ether;  // tokenA
        uint112 reserve1_initial = 50 ether;   // WETH
        // Initial spot price: 1 tokenA = 0.5 WETH
        
        // Set initial cumulative prices (arbitrary starting values)
        uint256 price0Cumulative_initial = 1000;
        uint256 price1Cumulative_initial = 2000;
        
        // Set initial state
        wethPair.updateReserves(reserve0_initial, reserve1_initial, uint32(startTime));
        wethPair.setPriceCumulativeLast(price0Cumulative_initial, price1Cumulative_initial);
        
        // Step 2: Initialize oracle at T0 (first call just records state)
        oracle.update(address(tokenA), address(weth));
        
        // Step 3: Move forward exactly 1 hour (the TWAP period)
        vm.warp(startTime + 1 hours);
        
        // Step 4: Set up new state at time T1 (1 hour later)
        uint112 reserve0_final = 200 ether;  // tokenA
        uint112 reserve1_final = 50 ether;   // WETH
        // Final spot price: 1 tokenA = 0.25 WETH
        
        // Step 5: Calculate what the cumulative prices should be after 1 hour
        // The TWAP oracle expects cumulative prices to increase by: price * time_elapsed
        // Average price over the period: (0.5 + 0.25) / 2 = 0.375 WETH per tokenA
        // Average price reverse: (2 + 4) / 2 = 3 tokenA per WETH
        
        // price0Cumulative increases by: (WETH per tokenA) * time * Q112
        uint256 avgPrice0 = (Q112 * 3) / 8;  // 0.375 in Q112 format
        uint256 price0Cumulative_final = price0Cumulative_initial + (avgPrice0 * 1 hours);
        
        // price1Cumulative increases by: (tokenA per WETH) * time * Q112
        uint256 avgPrice1 = 3 * Q112;  // 3 in Q112 format
        uint256 price1Cumulative_final = price1Cumulative_initial + (avgPrice1 * 1 hours);
        
        // Update pair state at T1
        wethPair.updateReserves(reserve0_final, reserve1_final, uint32(block.timestamp));
        wethPair.setPriceCumulativeLast(price0Cumulative_final, price1Cumulative_final);
        
        // Step 6: Update oracle at T1 - this calculates TWAP over the last hour
        oracle.update(address(tokenA), address(weth));
        
        // Step 7: Test consulting prices
        // How much ETH for 1 tokenA? (uses address(0) for ETH)
        uint256 ethOut = oracle.consult(address(tokenA), address(0), 1 ether);
        
        // Should be approximately 0.375 ETH (the average price over the hour)
        assertApproxEqAbs(ethOut, 0.375 ether, 0.01 ether, "TWAP: 1 tokenA should equal ~0.375 ETH");
        
        // How much tokenA for 1 ETH?
        // Note: Since we only have tokenA/WETH pair, we need to use the same pair
        // The oracle should handle the reverse calculation
        uint256 tokenAOut = oracle.consult(address(weth), address(tokenA), 1 ether);
        
        // Should be approximately 3 tokenA (the reverse average price)
        assertApproxEqAbs(tokenAOut, 3 ether, 0.01 ether, "TWAP: 1 ETH should equal ~3 tokenA");
    }
    
    function testUpdateRequiresPair() public {
        // Try to update a non-existent pair
        vm.expectRevert("TWAPOracle: INVALID_PAIR");
        oracle.update(address(tokenA), address(0xDEAD));
    }
    
    function testConsultRequiresPair() public {
        // Try to consult a non-existent pair
        vm.expectRevert("TWAPOracle: INVALID_PAIR");
        oracle.consult(address(tokenA), address(0xDEAD), 1 ether);
    }
    
    function testConsultRequiresInitialization() public {
        // Create new pair
        MockERC20 tokenC = new MockERC20();
        MockUniswapV2Pair newPair = new MockUniswapV2Pair(address(tokenA), address(tokenC));
        factory.setPair(address(tokenA), address(tokenC), address(newPair));
        
        // Try to consult without initializing (lastUpdateTimestamp will be 0)
        vm.expectRevert("TWAPOracle: PAIR_NOT_INITIALIZED_TIMESTAMP");
        oracle.consult(address(tokenA), address(tokenC), 1 ether);
    }
    
    function testConsultRequiresNonZeroOutput() public {
        // Initial values from setUp for pair (tokenA, tokenB):
        uint256 initialP0C = 5000;
        uint256 initialP1C = 2500;

        // First update: initializes oracle measurement with above cumulative prices and current timestamp.
        oracle.update(address(tokenA), address(tokenB));
        
        // Move time forward
        vm.warp(block.timestamp + 1 hours);
        
        // Update reserves with new timestamp (reserves themselves don't matter for this specific test path)
        uint32 currentPairTimestamp = uint32(block.timestamp);
        pair.updateReserves(100 ether, 200 ether, currentPairTimestamp);
        
        // Set price cumulatives on the mock pair to be SAME as initial ones recorded by oracle.
        // This ensures delta is 0, leading to priceAverage = 0.
        pair.setPriceCumulativeLast(initialP0C, initialP1C); // These are the values oracle stored.
        
        // Second update: oracle calculates averages. Since current cumulative = last cumulative, average price = 0.
        oracle.update(address(tokenA), address(tokenB));
        
        // Try to consult. Since average price is 0, amountOut will be 0.
        vm.expectRevert("TWAPOracle: ZERO_OUTPUT_AMOUNT");
        oracle.consult(address(tokenB), address(tokenA), 1 ether);
    }
} 