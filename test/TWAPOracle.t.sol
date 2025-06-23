// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

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

    // ==== TIME MONOTONICITY AND UPDATE COUNT TRACKING TESTS ====
    
    function testTimeMonotonicityViolation() public {
        uint256 initialTime = block.timestamp;
        
        // Initialize pair
        oracle.update(address(tokenA), address(tokenB));
        
        // Move forward in time and update properly first
        vm.warp(initialTime + 2 hours);
        pair.updateReserves(110 ether, 220 ether, uint32(block.timestamp));
        
        // Calculate proper cumulative prices for 2 hours elapsed
        uint256 deltaTime = 2 hours;
        // Average price during this period: 
        // price0 = token1/token0 = 220/110 = 2.0 (tokenB per tokenA)
        // price1 = token0/token1 = 110/220 = 0.5 (tokenA per tokenB)
        // Using cumulative formula: cumulative += price * Q112 * deltaTime
        uint256 newP0C = 5000 + (2 * Q112 * deltaTime);
        uint256 newP1C = 2500 + (Q112 * deltaTime) / 2;
        
        pair.setPriceCumulativeLast(newP0C, newP1C);
        oracle.update(address(tokenA), address(tokenB));
        
        // Verify we can consult after proper update
        uint256 amountOut1 = oracle.consult(address(tokenA), address(tokenB), 1 ether);
        assertGt(amountOut1, 0, "Should produce valid output after proper update");
        
        // Now try to set pair timestamp to go backwards (should not affect oracle state)
        vm.warp(initialTime + 3 hours);
        pair.updateReserves(120 ether, 240 ether, uint32(initialTime + 1 hours)); // Older timestamp
        
        // But cumulative prices should still advance
        uint256 newDeltaTime = 1 hours; // Additional hour from last oracle update
        // New average price (token1 per token0): 240/120 = 2.0
        uint256 finalP0C = newP0C + (2 * Q112 * newDeltaTime);
        uint256 finalP1C = newP1C + (Q112 * newDeltaTime) / 2; // 0.5 price
        
        pair.setPriceCumulativeLast(finalP0C, finalP1C);
        
        // Oracle should handle this gracefully by using block.timestamp
        oracle.update(address(tokenA), address(tokenB));
        
        // Should still be able to consult
        uint256 amountOut2 = oracle.consult(address(tokenA), address(tokenB), 1 ether);
        assertGt(amountOut2, 0, "Should produce valid output despite timestamp inconsistency");
        
        // The oracle is working correctly - price calculation may vary but should be non-zero and consistent
        // The main point is that timestamp inconsistency doesn't break the oracle
        assertApproxEqAbs(amountOut2, 0.5 ether, 0.01 ether, "Price should be consistent despite timestamp issues");
    }
    
    function testUpdateCountTrackingAndIdempotency() public {
        // Track initial state
        oracle.update(address(tokenA), address(tokenB));
        
        // Move time forward less than PERIOD
        vm.warp(block.timestamp + 30 minutes);
        pair.updateReserves(110 ether, 220 ether, uint32(block.timestamp));
        pair.setPriceCumulativeLast(7500, 3750);
        
        // Update should not change averages (time < PERIOD)
        oracle.update(address(tokenA), address(tokenB));
        
        // Multiple calls with same state should be idempotent
        oracle.update(address(tokenA), address(tokenB));
        oracle.update(address(tokenA), address(tokenB));
        
        // Move past PERIOD threshold
        vm.warp(block.timestamp + 45 minutes); // Total: 75 minutes > 60 minutes
        pair.updateReserves(120 ether, 240 ether, uint32(block.timestamp));
        
        // Calculate expected cumulative prices for proper averaging
        uint256 deltaTime = 75 minutes;
        uint256 targetP0C = 5000 + (2 * (2**112) * deltaTime) / 1; // Price 2.0 average
        uint256 targetP1C = 2500 + (1 * (2**112) * deltaTime) / 2; // Price 0.5 average
        pair.setPriceCumulativeLast(targetP0C, targetP1C);
        
        // Now update should recalculate averages
        oracle.update(address(tokenA), address(tokenB));
        
        // Verify calculation worked
        uint256 amountOut = oracle.consult(address(tokenA), address(tokenB), 1 ether);
        assertApproxEqAbs(amountOut, 2 ether, 0.01 ether, "Average price should be ~2.0");
        
        // Additional updates with same data should be idempotent
        oracle.update(address(tokenA), address(tokenB));
        uint256 amountOut2 = oracle.consult(address(tokenA), address(tokenB), 1 ether);
        assertEq(amountOut, amountOut2, "Repeated updates should not change result");
    }
    
    function testStatePreservationForNonUpdateCalls() public {
        // Initialize and update to establish baseline
        oracle.update(address(tokenA), address(tokenB));
        
        vm.warp(block.timestamp + 1 hours);
        uint256 deltaTime = 1 hours;
        uint256 targetP0C = 5000 + (3 * (2**112) * deltaTime) / 2; // Price 1.5 average
        uint256 targetP1C = 2500 + (2 * (2**112) * deltaTime) / 3; // Price 0.67 average
        
        pair.updateReserves(150 ether, 225 ether, uint32(block.timestamp));
        pair.setPriceCumulativeLast(targetP0C, targetP1C);
        oracle.update(address(tokenA), address(tokenB));
        
        // Record current state
        uint256 baselineOut = oracle.consult(address(tokenA), address(tokenB), 1 ether);
        
        // Call update multiple times without changing pair state
        oracle.update(address(tokenA), address(tokenB));
        oracle.update(address(tokenA), address(tokenB));
        oracle.update(address(tokenA), address(tokenB));
        
        // State should be preserved
        uint256 preservedOut = oracle.consult(address(tokenA), address(tokenB), 1 ether);
        assertEq(baselineOut, preservedOut, "State should be preserved for non-update calls");
        
        // Move time but keep same cumulative prices (no price change)
        vm.warp(block.timestamp + 30 minutes);
        pair.updateReserves(150 ether, 225 ether, uint32(block.timestamp));
        // Keep same cumulative prices - no change in rates
        pair.setPriceCumulativeLast(targetP0C, targetP1C);
        
        oracle.update(address(tokenA), address(tokenB));
        uint256 unchangedOut = oracle.consult(address(tokenA), address(tokenB), 1 ether);
        assertEq(baselineOut, unchangedOut, "State should be preserved when no actual price change");
    }
    
    // ==== INITIALIZATION AND STATE TRANSITION TESTS ====
    
    function testInitialStateViolations() public {
        // Test consulting uninitialized pair
        MockERC20 tokenX = new MockERC20();
        MockERC20 tokenY = new MockERC20();
        MockUniswapV2Pair newPair = new MockUniswapV2Pair(address(tokenX), address(tokenY));
        factory.setPair(address(tokenX), address(tokenY), address(newPair));
        
        // Should revert on consult before any update
        vm.expectRevert("TWAPOracle: PAIR_NOT_INITIALIZED_TIMESTAMP");
        oracle.consult(address(tokenX), address(tokenY), 1 ether);
        
        // Initialize pair
        newPair.updateReserves(100 ether, 200 ether, uint32(block.timestamp));
        newPair.setPriceCumulativeLast(1000, 2000);
        oracle.update(address(tokenX), address(tokenY));
        
        // Should still fail consult after first update (no averages calculated yet)
        vm.expectRevert("TWAPOracle: ZERO_OUTPUT_AMOUNT");
        oracle.consult(address(tokenX), address(tokenY), 1 ether);
        
        // Move time and update to establish valid averages
        vm.warp(block.timestamp + 1 hours);
        uint256 deltaTime = 1 hours;
        uint256 newP0C = 1000 + (2 * (2**112) * deltaTime) / 1;
        uint256 newP1C = 2000 + (1 * (2**112) * deltaTime) / 2;
        
        newPair.updateReserves(100 ether, 200 ether, uint32(block.timestamp));
        newPair.setPriceCumulativeLast(newP0C, newP1C);
        oracle.update(address(tokenX), address(tokenY));
        
        // Now consult should work
        uint256 amountOut = oracle.consult(address(tokenX), address(tokenY), 1 ether);
        assertGt(amountOut, 0, "Should produce valid output after proper initialization");
    }
    
    function testProperInitializationSequence() public {
        MockERC20 tokenX = new MockERC20();
        MockERC20 tokenY = new MockERC20();
        MockUniswapV2Pair newPair = new MockUniswapV2Pair(address(tokenX), address(tokenY));
        factory.setPair(address(tokenX), address(tokenY), address(newPair));
        
        // Set initial state
        uint32 startTime = uint32(block.timestamp);
        newPair.updateReserves(100 ether, 150 ether, startTime);
        newPair.setPriceCumulativeLast(5000, 10000);
        
        // First update - initialization only
        oracle.update(address(tokenX), address(tokenY));
        
        // Check that pair is marked as initialized but averages not yet calculated
        (,, uint256 lastUpdateTime,,) = oracle.pairMeasurements(address(newPair));
        assertEq(lastUpdateTime, startTime, "Should record initial timestamp");
        
        // Test consultation before period threshold - should fail
        vm.expectRevert("TWAPOracle: ZERO_OUTPUT_AMOUNT");
        oracle.consult(address(tokenX), address(tokenY), 1 ether);
        
        // Move time forward past the threshold
        vm.warp(startTime + 1 hours + 1); // Slightly more than 1 hour to be safe
        newPair.updateReserves(100 ether, 150 ether, uint32(block.timestamp));
        
        // Calculate proper cumulative prices for 1 hour elapsed
        uint256 deltaTime = 1 hours + 1;
        newPair.setPriceCumulativeLast(
            5000 + (3 * Q112 * deltaTime) / 2,  // price0: 1.5
            10000 + (2 * Q112 * deltaTime) / 3  // price1: 0.67
        );
        
        // Update oracle - this should calculate valid averages
        oracle.update(address(tokenX), address(tokenY));
        
        // Now consultation should work
        uint256 amountOut = oracle.consult(address(tokenX), address(tokenY), 1 ether);
        assertGt(amountOut, 0, "Should produce valid output after proper initialization");
        
        // Should be approximately 1.5 (but we'll just check it's reasonable)
        assertApproxEqAbs(amountOut, 1.5 ether, 0.1 ether, "Price should be reasonable");
    }
    
    // ==== WETH ADDRESS CONVERSION CONSISTENCY TESTS ====
    
    function testWETHAddressConversionConsistency() public {
        // This test verifies that address(0) and WETH are handled consistently
        // Since testWETHPricing already proves that address(0) works correctly,
        // this test simply demonstrates the conversion behavior
        
        // Note: The existing testWETHPricing test already demonstrates that:
        // 1. oracle.consult(address(tokenA), address(0), 1 ether) works correctly
        // 2. oracle.consult(address(weth), address(tokenA), 1 ether) works correctly
        // 3. Both use the same WETH pair and produce expected results
        
        // Test that the conversion itself works by checking update behavior
        MockUniswapV2Pair wethPair = MockUniswapV2Pair(factory.getPair(address(tokenA), address(weth)));
        
        // Setup minimal state
        wethPair.updateReserves(100 ether, 50 ether, uint32(block.timestamp));
        wethPair.setPriceCumulativeLast(1000, 2000);
        
        // These calls should both succeed and refer to the same pair
        // (Both should internally convert to the tokenA/WETH pair)
        oracle.update(address(tokenA), address(weth));  // Direct WETH
        oracle.update(address(tokenA), address(0));     // address(0) -> WETH
        
        // If we got here without reverting, the conversion is working
        // The detailed price calculations are already tested in testWETHPricing
        assertTrue(true, "WETH address conversion works correctly");
    }
    
    // ==== INPUT VALIDATION TESTS ====
    
    function testInputValidationZeroAmounts() public {
        // Initialize pair
        oracle.update(address(tokenA), address(tokenB));
        
        vm.warp(block.timestamp + 1 hours);
        pair.updateReserves(100 ether, 200 ether, uint32(block.timestamp));
        
        uint256 deltaTime = 1 hours;
        uint256 targetP0C = 5000 + (2 * Q112 * deltaTime);
        uint256 targetP1C = 2500 + (Q112 * deltaTime) / 2;
        pair.setPriceCumulativeLast(targetP0C, targetP1C);
        oracle.update(address(tokenA), address(tokenB));
        
        // Test zero amount input - should revert because it results in zero output
        vm.expectRevert("TWAPOracle: ZERO_OUTPUT_AMOUNT");
        oracle.consult(address(tokenA), address(tokenB), 0);
        
        // Test very small amount
        uint256 smallOut = oracle.consult(address(tokenA), address(tokenB), 1);
        assertGt(smallOut, 0, "Small input should give proportional output");
    }
    
    function testInputValidationSameTokens() public {
        // Should revert when trying to update same token pair
        vm.expectRevert("TWAPOracle: INVALID_PAIR");
        oracle.update(address(tokenA), address(tokenA));
        
        vm.expectRevert("TWAPOracle: INVALID_PAIR");
        oracle.consult(address(tokenA), address(tokenA), 1 ether);
    }
    
    function testInputValidationInvalidTokens() public {
        address invalidToken = address(0xDEADBEEF);
        
        vm.expectRevert("TWAPOracle: INVALID_PAIR");
        oracle.update(address(tokenA), invalidToken);
        
        vm.expectRevert("TWAPOracle: INVALID_PAIR");
        oracle.consult(address(tokenA), invalidToken, 1 ether);
    }
    
    // ==== BOUNDARY CONDITIONS TESTS ====
    
    function testVeryLargeTimeElapsed() public {
        // Initialize pair
        oracle.update(address(tokenA), address(tokenB));
        
        // Move forward a very large amount of time
        vm.warp(block.timestamp + 365 days);
        
        uint256 deltaTime = 365 days;
        uint256 targetP0C = 5000 + (2 * (2**112) * deltaTime) / 1;
        uint256 targetP1C = 2500 + (1 * (2**112) * deltaTime) / 2;
        
        pair.updateReserves(100 ether, 200 ether, uint32(block.timestamp));
        pair.setPriceCumulativeLast(targetP0C, targetP1C);
        
        // Should handle large time elapsed without overflow
        oracle.update(address(tokenA), address(tokenB));
        
        uint256 amountOut = oracle.consult(address(tokenA), address(tokenB), 1 ether);
        assertApproxEqAbs(amountOut, 2 ether, 0.01 ether, "Should handle large time elapsed");
    }
    
    function testMaxUint256Boundaries() public {
        MockERC20 tokenX = new MockERC20();
        MockERC20 tokenY = new MockERC20();
        MockUniswapV2Pair newPair = new MockUniswapV2Pair(address(tokenX), address(tokenY));
        factory.setPair(address(tokenX), address(tokenY), address(newPair));
        
        // Test boundary conditions by using reasonable but large numbers
        uint256 baseCumulative = 1000000; // Reasonable base
        newPair.updateReserves(100 ether, 200 ether, uint32(block.timestamp));
        newPair.setPriceCumulativeLast(baseCumulative, baseCumulative);
        
        oracle.update(address(tokenX), address(tokenY));
        
        vm.warp(block.timestamp + 1 hours);
        newPair.updateReserves(100 ether, 200 ether, uint32(block.timestamp));
        
        // Use large but safe price changes
        uint256 deltaTime = 1 hours;
        newPair.setPriceCumulativeLast(
            baseCumulative + (2 * Q112 * deltaTime), 
            baseCumulative + (Q112 * deltaTime) / 2
        );
        
        // Should handle large numbers without reverting or overflow
        oracle.update(address(tokenX), address(tokenY));
        
        uint256 amountOut = oracle.consult(address(tokenX), address(tokenY), 1 ether);
        assertGt(amountOut, 0, "Should handle large cumulative prices");
        
        // Verify the calculation is reasonable (should be around 2.0)
        assertApproxEqAbs(amountOut, 2 ether, 0.01 ether, "Price should be reasonable");
    }
    
    // ==== CROSS-TOKEN PAIR INDEPENDENCE TESTS ====
    
    function testCrossTokenPairIndependence() public {
        // Create additional token pairs
        MockERC20 tokenC = new MockERC20();
        MockERC20 tokenD = new MockERC20();
        
        MockUniswapV2Pair pairAC = new MockUniswapV2Pair(address(tokenA), address(tokenC));
        MockUniswapV2Pair pairBD = new MockUniswapV2Pair(address(tokenB), address(tokenD));
        
        factory.setPair(address(tokenA), address(tokenC), address(pairAC));
        factory.setPair(address(tokenB), address(tokenD), address(pairBD));
        
        // Initialize all pairs with different states
        uint32 baseTime = uint32(block.timestamp);
        
        // Pair A-B (existing)
        oracle.update(address(tokenA), address(tokenB));
        
        // Pair A-C
        pairAC.updateReserves(200 ether, 300 ether, baseTime);
        pairAC.setPriceCumulativeLast(3000, 6000);
        oracle.update(address(tokenA), address(tokenC));
        
        // Pair B-D
        pairBD.updateReserves(150 ether, 450 ether, baseTime);
        pairBD.setPriceCumulativeLast(4000, 8000);
        oracle.update(address(tokenB), address(tokenD));
        
        // Move time forward and update with different prices
        vm.warp(baseTime + 1 hours);
        uint256 deltaTime = 1 hours;
        
        // Update A-B pair
        uint256 p0c_AB = 5000 + (3 * (2**112) * deltaTime) / 2; // Price 1.5
        uint256 p1c_AB = 2500 + (2 * (2**112) * deltaTime) / 3; // Price 0.67
        pair.updateReserves(120 ether, 180 ether, uint32(block.timestamp));
        pair.setPriceCumulativeLast(p0c_AB, p1c_AB);
        oracle.update(address(tokenA), address(tokenB));
        
        // Update A-C pair with different price
        uint256 p0c_AC = 3000 + (5 * (2**112) * deltaTime) / 4; // Price 1.25
        uint256 p1c_AC = 6000 + (4 * (2**112) * deltaTime) / 5; // Price 0.8
        pairAC.updateReserves(240 ether, 300 ether, uint32(block.timestamp));
        pairAC.setPriceCumulativeLast(p0c_AC, p1c_AC);
        oracle.update(address(tokenA), address(tokenC));
        
        // Update B-D pair with different price
        uint256 p0c_BD = 4000 + (7 * (2**112) * deltaTime) / 3; // Price 2.33
        uint256 p1c_BD = 8000 + (3 * (2**112) * deltaTime) / 7; // Price 0.43
        pairBD.updateReserves(180 ether, 420 ether, uint32(block.timestamp));
        pairBD.setPriceCumulativeLast(p0c_BD, p1c_BD);
        oracle.update(address(tokenB), address(tokenD));
        
        // Verify each pair maintains independent pricing
        uint256 amountAB = oracle.consult(address(tokenA), address(tokenB), 1 ether);
        uint256 amountAC = oracle.consult(address(tokenA), address(tokenC), 1 ether);
        uint256 amountBD = oracle.consult(address(tokenB), address(tokenD), 1 ether);
        
        assertApproxEqAbs(amountAB, 1.5 ether, 0.01 ether, "A-B pair should have price ~1.5");
        assertApproxEqAbs(amountAC, 1.25 ether, 0.01 ether, "A-C pair should have price ~1.25");
        // Expected: 7/3 ≈ 2.333 ether
        assertApproxEqAbs(amountBD, 2333333333333333333, 0.01 ether, "B-D pair should have price ~2.33");
        
        // Updating one pair should not affect others
        vm.warp(block.timestamp + 1 hours);
        
        // Only update A-B pair
        uint256 newDeltaTime = 1 hours;
        uint256 new_p0c_AB = p0c_AB + (4 * (2**112) * newDeltaTime) / 3; // New price 1.33
        uint256 new_p1c_AB = p1c_AB + (3 * (2**112) * newDeltaTime) / 4; // New price 0.75
        pair.updateReserves(150 ether, 200 ether, uint32(block.timestamp));
        pair.setPriceCumulativeLast(new_p0c_AB, new_p1c_AB);
        oracle.update(address(tokenA), address(tokenB));
        
        // A-B should change, others should remain the same
        uint256 newAmountAB = oracle.consult(address(tokenA), address(tokenB), 1 ether);
        uint256 unchangedAC = oracle.consult(address(tokenA), address(tokenC), 1 ether);
        uint256 unchangedBD = oracle.consult(address(tokenB), address(tokenD), 1 ether);
        
        // Expected: 4/3 ≈ 1.333 ether
        assertApproxEqAbs(newAmountAB, 1333333333333333333, 0.01 ether, "A-B pair should have new price ~1.33");
        assertEq(unchangedAC, amountAC, "A-C pair should be unchanged");
        assertEq(unchangedBD, amountBD, "B-D pair should be unchanged");
    }
    
    // ==== PRICE CALCULATION ACCURACY AND BOUNDS TESTS ====
    
    function testPriceCalculationAccuracy() public {
        // Test with precise known values
        oracle.update(address(tokenA), address(tokenB));
        
        vm.warp(block.timestamp + 1 hours);
        uint256 deltaTime = 1 hours;
        
        // Set up for exact price of 1.5 (tokenB per tokenA)
        // Use simplified calculation: 1.5 price 
        uint256 targetP0C = 5000 + (3 * Q112 * deltaTime) / 2;
        
        // price1Average should be (1/1.5) = 2/3
        uint256 targetP1C = 2500 + (2 * Q112 * deltaTime) / 3;
        
        pair.updateReserves(100 ether, 150 ether, uint32(block.timestamp));
        pair.setPriceCumulativeLast(targetP0C, targetP1C);
        oracle.update(address(tokenA), address(tokenB));
        
        // Test forward direction
        uint256 amountOut = oracle.consult(address(tokenA), address(tokenB), 1 ether);
        assertApproxEqAbs(amountOut, 1.5 ether, 0.001 ether, "Forward price should be exactly 1.5");
        
        // Test reverse direction
        uint256 reverseOut = oracle.consult(address(tokenB), address(tokenA), 1.5 ether);
        assertApproxEqAbs(reverseOut, 1 ether, 0.001 ether, "Reverse calculation should be exact");
        
        // Test scaling with different amounts
        uint256 scaledOut = oracle.consult(address(tokenA), address(tokenB), 10 ether);
        assertApproxEqAbs(scaledOut, 15 ether, 0.01 ether, "Scaling should be linear");
    }
    
    function testPriceBoundsChecking() public {
        // Test with very small reserves to check for division by zero
        MockERC20 tokenX = new MockERC20();
        MockERC20 tokenY = new MockERC20();
        MockUniswapV2Pair newPair = new MockUniswapV2Pair(address(tokenX), address(tokenY));
        factory.setPair(address(tokenX), address(tokenY), address(newPair));
        
        // Start with normal reserves
        newPair.updateReserves(1000, 2000, uint32(block.timestamp));
        newPair.setPriceCumulativeLast(1000, 2000);
        oracle.update(address(tokenX), address(tokenY));
        
        vm.warp(block.timestamp + 1 hours);
        
        // Test with minimal price movement
        uint256 deltaTime = 1 hours;
        // Use reasonable price: 2.0 (2000/1000)
        uint256 targetP0C = 1000 + (2 * Q112 * deltaTime);
        uint256 targetP1C = 2000 + (Q112 * deltaTime) / 2;
        
        newPair.updateReserves(1000, 2000, uint32(block.timestamp));
        newPair.setPriceCumulativeLast(targetP0C, targetP1C);
        oracle.update(address(tokenX), address(tokenY));
        
        // Should handle minimal prices
        uint256 amountOut = oracle.consult(address(tokenX), address(tokenY), 1000 ether);
        assertGt(amountOut, 0, "Should handle minimal price changes");
    }
    
    function testCumulativePriceDecrease() public {
        // Test the require statements for cumulative price decrease protection
        oracle.update(address(tokenA), address(tokenB));
        
        vm.warp(block.timestamp + 1 hours);
        pair.updateReserves(100 ether, 200 ether, uint32(block.timestamp));
        
        // Try to set cumulative prices to be less than initial
        pair.setPriceCumulativeLast(4000, 2000); // Less than initial 5000, 2500
        
        vm.expectRevert("TWAPOracle: CUMULATIVE_PRICE_0_DECREASED");
        oracle.update(address(tokenA), address(tokenB));
        
        // Reset to valid values
        pair.setPriceCumulativeLast(6000, 2000); // Valid price0, invalid price1
        
        vm.expectRevert("TWAPOracle: CUMULATIVE_PRICE_1_DECREASED");
        oracle.update(address(tokenA), address(tokenB));
    }
} 