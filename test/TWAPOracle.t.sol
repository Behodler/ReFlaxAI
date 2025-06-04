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
        vm.warp(10 hours); // Ensure block.timestamp starts at a reasonably large value

        // Get the WETH pair instance that was created in setUp
        MockUniswapV2Pair wethPair = MockUniswapV2Pair(factory.getPair(address(tokenA), address(weth)));
        uint256 testDeltaTime = 1 hours; // This is the deltaTime the test *intends* for price averaging over a specific segment
        uint256 oracleEffectiveElapsedTime = 3 hours; // This is what the oracle will actually see based on timestamp manipulation

        // Explicitly set initial state for THIS test for the WETH pair
        uint256 initialP0C_weth_test = 7000; 
        uint256 initialP1C_weth_test = 8000;
        uint112 reserve0_weth_test = 150 ether; 
        uint112 reserve1_weth_test = 75 ether; 
        uint32 initialTimestamp_weth_test = uint32(block.timestamp - (oracleEffectiveElapsedTime - testDeltaTime)); // e.g., 10h - (3h - 1h) = 8h

        wethPair.updateReserves(reserve0_weth_test, reserve1_weth_test, initialTimestamp_weth_test);
        wethPair.setPriceCumulativeLast(initialP0C_weth_test, initialP1C_weth_test);
        
        // Initialize pair in oracle - this will record the above cumulatives and timestamp (e.g., 8h)
        oracle.update(address(tokenA), address(weth));
        
        // Move time forward for TWAP calculation period. block.timestamp becomes e.g., 10h + 1h = 11h
        vm.warp(block.timestamp + testDeltaTime); 
        
        // Update reserves for the WETH pair again for the "current" state
        uint112 currentReserve0_weth = 160 ether;
        uint112 currentReserve1_weth = 96 ether; 
        uint32 currentTimestamp_weth_for_pair = uint32(block.timestamp); // e.g., 11h
        wethPair.updateReserves(currentReserve0_weth, currentReserve1_weth, currentTimestamp_weth_for_pair);
        
        // Calculate and set new cumulative prices for the WETH pair for target avg price
        // The oracle will see an elapsed time of (currentTimestamp_weth_for_pair - initialTimestamp_weth_test) = oracleEffectiveElapsedTime (3h)
        // So, the delta cumulative must be calculated for this period to achieve target avg price.
        // Target avg price of tokenA/WETH (token0/token1 price) = 0.55 (11/20)
        uint256 targetP0C_weth = initialP0C_weth_test + (11 * Q112 * oracleEffectiveElapsedTime) / 20;
        // Target avg price of WETH/tokenA (token1/token0 price) = 1/0.55 (20/11)
        uint256 targetP1C_weth = initialP1C_weth_test + (20 * Q112 * oracleEffectiveElapsedTime) / 11; 
        wethPair.setPriceCumulativeLast(targetP0C_weth, targetP1C_weth);
        
        // Update oracle - this will calculate averages based on the change from initialP0C/P1C_weth_test over oracleEffectiveElapsedTime
        oracle.update(address(tokenA), address(weth));
        
        // Consult tokenA -> ETH price (ETH is tokenOut = address(0))
        // tokenA is token0 of the wethPair. ETH (WETH) is token1.
        // We are asking for price of token1 (WETH) in terms of token0 (tokenA).
        // The oracle's price0Average stores (price of token1 / price of token0).
        uint256 ethOut = oracle.consult(address(tokenA), address(0), 1 ether);
        
        // Verify ETH price
        assertApproxEqAbs(ethOut, 0.55 ether, 0.01 ether, "Token -> ETH price should be approximately 0.55 ETH");
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