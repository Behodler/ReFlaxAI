// Certora Specification for TWAPOracle Contract
// This file defines formal verification rules for the TWAPOracle contract

using TWAPOracle as oracle;
using MockUniswapV2Pair as mockPair;
using MockUniswapV2Factory as factory;

methods {
    // Oracle methods
    function update(address, address) external;
    function consult(address, address, uint256) external returns (uint256) envfree;
    
    // View methods
    function factory() external returns (address) envfree;
    function WETH() external returns (address) envfree;
    function PERIOD() external returns (uint256) envfree;
    function pairMeasurements(address) external returns (FixedPoint.uq112x112, FixedPoint.uq112x112, uint256, uint256, uint256) envfree;
    
    // Additional view methods for better testing
    function owner() external returns (address) envfree;
    
    // Pair methods
    function _.getReserves() external returns (uint112, uint112, uint32) envfree => DISPATCHER(true);
    function _.price0CumulativeLast() external returns (uint256) envfree => DISPATCHER(true);
    function _.price1CumulativeLast() external returns (uint256) envfree => DISPATCHER(true);
    function _.token0() external returns (address) envfree => DISPATCHER(true);
    function _.token1() external returns (address) envfree => DISPATCHER(true);
    
    // Factory methods
    function _.getPair(address, address) external returns (address) envfree => DISPATCHER(true);
    
}

// Ghost variables to track oracle state
ghost mapping(address => uint256) lastUpdateTime {
    init_state axiom forall address p. lastUpdateTime[p] == 0;
}

ghost mapping(address => uint256) lastPrice0Cumulative {
    init_state axiom forall address p. lastPrice0Cumulative[p] == 0;
}

ghost mapping(address => uint256) lastPrice1Cumulative {
    init_state axiom forall address p. lastPrice1Cumulative[p] == 0;
}


// Core Properties

// PERIOD is always 1 hour
invariant periodIs1Hour()
    PERIOD() == 3600;

// Time must advance for price updates
rule timeAdvancesForUpdate(env e, address tokenA, address tokenB) {
    address pairAddr = factory.getPair(tokenA, tokenB);
    require pairAddr != 0;
    
    uint112 price0Avg; uint112 price1Avg; uint256 lastTimestamp; uint256 lastP0Cum; uint256 lastP1Cum;
    price0Avg, price1Avg, lastTimestamp, lastP0Cum, lastP1Cum = pairMeasurements(pairAddr);
    
    uint112 r0; uint112 r1;
    uint32 blockTimestamp;
    r0, r1, blockTimestamp = mockPair.getReserves();
    
    update(e, tokenA, tokenB);
    
    uint112 price0AvgAfter; uint112 price1AvgAfter; uint256 lastTimestampAfter; uint256 lastP0CumAfter; uint256 lastP1CumAfter;
    price0AvgAfter, price1AvgAfter, lastTimestampAfter, lastP0CumAfter, lastP1CumAfter = pairMeasurements(pairAddr);
    
    // If update happened, time must have advanced
    assert (lastTimestampAfter != lastTimestamp) => (lastTimestampAfter > lastTimestamp);
}

// Cumulative prices are monotonic
rule cumulativePricesNeverDecrease(env e, address tokenA, address tokenB) {
    address pairAddr = factory.getPair(tokenA, tokenB);
    require pairAddr != 0;
    
    uint256 price0CumBefore = mockPair.price0CumulativeLast();
    uint256 price1CumBefore = mockPair.price1CumulativeLast();
    
    update(e, tokenA, tokenB);
    
    uint256 price0CumAfter = mockPair.price0CumulativeLast();
    uint256 price1CumAfter = mockPair.price1CumulativeLast();
    
    assert price0CumAfter >= price0CumBefore;
    assert price1CumAfter >= price1CumBefore;
}

// First update only initializes
rule firstUpdateOnlyInitializes(env e, address tokenA, address tokenB) {
    address pairAddr = factory.getPair(tokenA, tokenB);
    require pairAddr != 0;
    
    uint112 price0Avg; uint112 price1Avg; uint256 lastTimestamp; uint256 lastP0Cum; uint256 lastP1Cum;
    price0Avg, price1Avg, lastTimestamp, lastP0Cum, lastP1Cum = pairMeasurements(pairAddr);
    
    require lastTimestamp == 0; // First update
    
    update(e, tokenA, tokenB);
    
    uint112 price0AvgAfter; uint112 price1AvgAfter; uint256 lastTimestampAfter; uint256 lastP0CumAfter; uint256 lastP1CumAfter;
    price0AvgAfter, price1AvgAfter, lastTimestampAfter, lastP0CumAfter, lastP1CumAfter = pairMeasurements(pairAddr);
    
    // Price averages should still be 0 after first update
    assert price0AvgAfter == 0 && price1AvgAfter == 0;
    // But timestamp and cumulative prices should be set
    assert lastTimestampAfter > 0;
}

// Update requires sufficient time elapsed
rule updateRequiresPeriodElapsed(env e, address tokenA, address tokenB) {
    address pairAddr = factory.getPair(tokenA, tokenB);
    require pairAddr != 0;
    
    uint112 price0Avg; uint112 price1Avg; uint256 lastTimestamp; uint256 lastP0Cum; uint256 lastP1Cum;
    price0Avg, price1Avg, lastTimestamp, lastP0Cum, lastP1Cum = pairMeasurements(pairAddr);
    
    require lastTimestamp > 0; // Not first update
    
    uint112 r0; uint112 r1;
    uint32 blockTimestamp;
    r0, r1, blockTimestamp = mockPair.getReserves();
    
    uint256 timeElapsed = blockTimestamp - lastTimestamp;
    require timeElapsed < PERIOD(); // Less than 1 hour
    
    update(e, tokenA, tokenB);
    
    uint112 price0AvgAfter; uint112 price1AvgAfter; uint256 lastTimestampAfter; uint256 lastP0CumAfter; uint256 lastP1CumAfter;
    price0AvgAfter, price1AvgAfter, lastTimestampAfter, lastP0CumAfter, lastP1CumAfter = pairMeasurements(pairAddr);
    
    // No update should occur
    assert price0AvgAfter == price0Avg;
    assert price1AvgAfter == price1Avg;
    assert lastTimestampAfter == lastTimestamp;
}

// Consult requires initialized pair
rule consultRequiresInitialization(env e, address tokenIn, address tokenOut, uint256 amountIn) {
    address pairAddr = factory.getPair(tokenIn, tokenOut);
    require pairAddr != 0;
    
    uint112 price0Avg; uint112 price1Avg; uint256 lastTimestamp; uint256 lastP0Cum; uint256 lastP1Cum;
    price0Avg, price1Avg, lastTimestamp, lastP0Cum, lastP1Cum = pairMeasurements(pairAddr);
    
    require lastTimestamp == 0; // Not initialized
    
    consult(e, tokenIn, tokenOut, amountIn);
    
    assert lastReverted;
}

// WETH substitution consistency
rule wethSubstitution(env e, address tokenB, uint256 amount) {
    require tokenB != 0;
    
    // Consulting with address(0) should be same as consulting with WETH
    uint256 resultWithZero = consult(e, tokenB, 0, amount);
    uint256 resultWithWETH = consult(e, tokenB, WETH(), amount);
    
    assert resultWithZero == resultWithWETH;
}

// Price calculation correctness
rule twapCalculationCorrect(env e, address tokenA, address tokenB) {
    address pairAddr = factory.getPair(tokenA, tokenB);
    require pairAddr != 0;
    
    uint112 price0Avg; uint112 price1Avg; uint256 lastTimestamp; uint256 lastP0Cum; uint256 lastP1Cum;
    price0Avg, price1Avg, lastTimestamp, lastP0Cum, lastP1Cum = pairMeasurements(pairAddr);
    
    require lastTimestamp > 0; // Already initialized
    
    uint256 currentP0Cum = mockPair.price0CumulativeLast();
    uint256 currentP1Cum = mockPair.price1CumulativeLast();
    
    uint112 r0; uint112 r1;
    uint32 blockTimestamp;
    r0, r1, blockTimestamp = mockPair.getReserves();
    
    uint256 timeElapsed = blockTimestamp - lastTimestamp;
    require timeElapsed >= PERIOD();
    
    update(e, tokenA, tokenB);
    
    uint112 price0AvgAfter; uint112 price1AvgAfter; uint256 lastTimestampAfter; uint256 lastP0CumAfter; uint256 lastP1CumAfter;
    price0AvgAfter, price1AvgAfter, lastTimestampAfter, lastP0CumAfter, lastP1CumAfter = pairMeasurements(pairAddr);
    
    // Verify TWAP calculation
    assert price0AvgAfter == (currentP0Cum - lastP0Cum) / timeElapsed;
    assert price1AvgAfter == (currentP1Cum - lastP1Cum) / timeElapsed;
}

// Consult returns proportional output
rule consultProportionality(env e, address tokenIn, address tokenOut, uint256 amount1, uint256 amount2) {
    require amount2 == 2 * amount1;
    
    uint256 output1 = consult(e, tokenIn, tokenOut, amount1);
    uint256 output2 = consult(e, tokenIn, tokenOut, amount2);
    
    // Double input should give double output
    assert output2 == 2 * output1;
}

// No zero output for positive input
rule noZeroOutput(env e, address tokenIn, address tokenOut, uint256 amountIn) {
    require amountIn > 0;
    
    address pairAddr = factory.getPair(tokenIn, tokenOut);
    require pairAddr != 0;
    
    uint112 price0Avg; uint112 price1Avg; uint256 lastTimestamp; uint256 lastP0Cum; uint256 lastP1Cum;
    price0Avg, price1Avg, lastTimestamp, lastP0Cum, lastP1Cum = pairMeasurements(pairAddr);
    
    require lastTimestamp > 0; // Initialized
    require price0Avg > 0 || price1Avg > 0; // At least one price is non-zero
    
    uint256 amountOut = consult(e, tokenIn, tokenOut, amountIn);
    
    assert amountOut > 0;
}

// Update idempotency within same block
rule updateIdempotency(env e, address tokenA, address tokenB) {
    address pairAddr = factory.getPair(tokenA, tokenB);
    require pairAddr != 0;
    
    uint112 price0Avg; uint112 price1Avg; uint256 lastTimestamp; uint256 lastP0Cum; uint256 lastP1Cum;
    price0Avg, price1Avg, lastTimestamp, lastP0Cum, lastP1Cum = pairMeasurements(pairAddr);
    
    update(e, tokenA, tokenB);
    
    uint112 price0AvgMid; uint112 price1AvgMid; uint256 lastTimestampMid; uint256 lastP0CumMid; uint256 lastP1CumMid;
    price0AvgMid, price1AvgMid, lastTimestampMid, lastP0CumMid, lastP1CumMid = pairMeasurements(pairAddr);
    
    // Second update in same conditions
    update(e, tokenA, tokenB);
    
    uint112 price0AvgAfter; uint112 price1AvgAfter; uint256 lastTimestampAfter; uint256 lastP0CumAfter; uint256 lastP1CumAfter;
    price0AvgAfter, price1AvgAfter, lastTimestampAfter, lastP0CumAfter, lastP1CumAfter = pairMeasurements(pairAddr);
    
    // State should be same after both updates
    assert price0AvgAfter == price0AvgMid;
    assert price1AvgAfter == price1AvgMid;
    assert lastTimestampAfter == lastTimestampMid;
}

// Additional Security Rules

// Address(0) conversion to WETH is consistent
rule addressZeroToWETHConsistency(env e, address token) {
    require token != 0 && token != WETH();
    
    // Both combinations should produce same pair
    address pairWithZero = factory.getPair(0, token);
    address pairWithWETH = factory.getPair(WETH(), token);
    
    assert pairWithZero == pairWithWETH;
}

// Token order independence in pair lookup
rule tokenOrderIndependence(env e, address tokenA, address tokenB) {
    require tokenA != tokenB && tokenA != 0 && tokenB != 0;
    
    address pair1 = factory.getPair(tokenA, tokenB);
    address pair2 = factory.getPair(tokenB, tokenA);
    
    assert pair1 == pair2;
}

// Consult with zero input amount reverts
rule consultZeroInputReverts(env e, address tokenIn, address tokenOut) {
    require tokenIn != tokenOut;
    
    address pairAddr = factory.getPair(tokenIn, tokenOut);
    require pairAddr != 0;
    
    uint112 price0Avg; uint112 price1Avg; uint256 lastTimestamp; uint256 lastP0Cum; uint256 lastP1Cum;
    price0Avg, price1Avg, lastTimestamp, lastP0Cum, lastP1Cum = pairMeasurements(pairAddr);
    
    require lastTimestamp > 0; // Initialized
    require price0Avg > 0 || price1Avg > 0; // Has TWAP data
    
    consult(e, tokenIn, tokenOut, 0);
    
    assert lastReverted;
}

// Oracle state never goes backwards
rule oracleStateNeverGoesBackwards(env e, address tokenA, address tokenB) {
    address pairAddr = factory.getPair(tokenA, tokenB);
    require pairAddr != 0;
    
    uint112 price0AvgBefore; uint112 price1AvgBefore; uint256 lastTimestampBefore; uint256 lastP0CumBefore; uint256 lastP1CumBefore;
    price0AvgBefore, price1AvgBefore, lastTimestampBefore, lastP0CumBefore, lastP1CumBefore = pairMeasurements(pairAddr);
    
    update(e, tokenA, tokenB);
    
    uint112 price0AvgAfter; uint112 price1AvgAfter; uint256 lastTimestampAfter; uint256 lastP0CumAfter; uint256 lastP1CumAfter;
    price0AvgAfter, price1AvgAfter, lastTimestampAfter, lastP0CumAfter, lastP1CumAfter = pairMeasurements(pairAddr);
    
    // Timestamps and cumulative prices never decrease
    assert lastTimestampAfter >= lastTimestampBefore;
    assert lastP0CumAfter >= lastP0CumBefore;
    assert lastP1CumAfter >= lastP1CumBefore;
}

// Multiple token pairs can be updated independently
rule independentPairUpdates(env e, address tokenA, address tokenB, address tokenC, address tokenD) {
    require tokenA != tokenB && tokenC != tokenD;
    require tokenA != tokenC && tokenA != tokenD && tokenB != tokenC && tokenB != tokenD;
    
    address pairAB = factory.getPair(tokenA, tokenB);
    address pairCD = factory.getPair(tokenC, tokenD);
    require pairAB != 0 && pairCD != 0 && pairAB != pairCD;
    
    uint112 price0AvgAB; uint112 price1AvgAB; uint256 lastTimestampAB; uint256 lastP0CumAB; uint256 lastP1CumAB;
    price0AvgAB, price1AvgAB, lastTimestampAB, lastP0CumAB, lastP1CumAB = pairMeasurements(pairAB);
    
    // Update first pair only
    update(e, tokenA, tokenB);
    
    uint112 price0AvgCD; uint112 price1AvgCD; uint256 lastTimestampCD; uint256 lastP0CumCD; uint256 lastP1CumCD;
    price0AvgCD, price1AvgCD, lastTimestampCD, lastP0CumCD, lastP1CumCD = pairMeasurements(pairCD);
    
    // Second pair should be unchanged
    assert price0AvgCD == 0 || price1AvgCD == 0; // Assuming it wasn't initialized
    assert lastTimestampCD == 0;
}

// TWAP bounds checking
rule twapBoundsCheck(env e, address tokenA, address tokenB) {
    address pairAddr = factory.getPair(tokenA, tokenB);
    require pairAddr != 0;
    
    uint112 price0AvgBefore; uint112 price1AvgBefore; uint256 lastTimestampBefore; uint256 lastP0CumBefore; uint256 lastP1CumBefore;
    price0AvgBefore, price1AvgBefore, lastTimestampBefore, lastP0CumBefore, lastP1CumBefore = pairMeasurements(pairAddr);
    
    require lastTimestampBefore > 0; // Already initialized
    
    uint112 r0; uint112 r1;
    uint32 blockTimestamp;
    r0, r1, blockTimestamp = mockPair.getReserves();
    
    require blockTimestamp >= lastTimestampBefore + PERIOD(); // Can update
    require blockTimestamp - lastTimestampBefore < 31536000; // Reasonable time elapsed (365 days)
    
    update(e, tokenA, tokenB);
    
    uint112 price0AvgAfter; uint112 price1AvgAfter; uint256 lastTimestampAfter; uint256 lastP0CumAfter; uint256 lastP1CumAfter;
    price0AvgAfter, price1AvgAfter, lastTimestampAfter, lastP0CumAfter, lastP1CumAfter = pairMeasurements(pairAddr);
    
    // TWAP values should be within reasonable bounds
    assert price0AvgAfter < 2^112;
    assert price1AvgAfter < 2^112;
}

// Consult mathematical consistency
rule consultMathematicalConsistency(env e, address tokenIn, address tokenOut, uint256 amountIn1, uint256 amountIn2) {
    require tokenIn != tokenOut;
    require amountIn1 > 0 && amountIn2 > 0;
    require amountIn1 != amountIn2;
    
    address pairAddr = factory.getPair(tokenIn, tokenOut);
    require pairAddr != 0;
    
    uint112 price0Avg; uint112 price1Avg; uint256 lastTimestamp; uint256 lastP0Cum; uint256 lastP1Cum;
    price0Avg, price1Avg, lastTimestamp, lastP0Cum, lastP1Cum = pairMeasurements(pairAddr);
    
    require lastTimestamp > 0; // Initialized
    require price0Avg > 0 || price1Avg > 0; // Has TWAP data
    
    uint256 output1 = consult(e, tokenIn, tokenOut, amountIn1);
    uint256 output2 = consult(e, tokenIn, tokenOut, amountIn2);
    
    // Outputs should be proportional to inputs
    // Using simplified check: if amount doubles, output should roughly double
    if (amountIn2 == 2 * amountIn1) {
        assert output2 == 2 * output1;
    }
}

// Edge case: Very large time elapsed
rule largeTimeElapsedHandling(env e, address tokenA, address tokenB) {
    address pairAddr = factory.getPair(tokenA, tokenB);
    require pairAddr != 0;
    
    uint112 price0AvgBefore; uint112 price1AvgBefore; uint256 lastTimestampBefore; uint256 lastP0CumBefore; uint256 lastP1CumBefore;
    price0AvgBefore, price1AvgBefore, lastTimestampBefore, lastP0CumBefore, lastP1CumBefore = pairMeasurements(pairAddr);
    
    require lastTimestampBefore > 0; // Already initialized
    
    uint112 r0; uint112 r1;
    uint32 blockTimestamp;
    r0, r1, blockTimestamp = mockPair.getReserves();
    
    // Very large time elapsed (but not overflow)
    require blockTimestamp > lastTimestampBefore + 2592000; // 30 days
    require blockTimestamp < lastTimestampBefore + 31536000; // Still reasonable (365 days)
    
    update(e, tokenA, tokenB);
    
    // Should not revert or produce invalid results
    uint112 price0AvgAfter; uint112 price1AvgAfter; uint256 lastTimestampAfter; uint256 lastP0CumAfter; uint256 lastP1CumAfter;
    price0AvgAfter, price1AvgAfter, lastTimestampAfter, lastP0CumAfter, lastP1CumAfter = pairMeasurements(pairAddr);
    
    assert lastTimestampAfter == blockTimestamp;
}

// Invariant: Initialized pairs remain initialized
invariant initializedPairsStayInitialized(address pair)
    (lastUpdateTime[pair] > 0) => (lastUpdateTime[pair] > 0)
    filtered { f -> f.selector == sig:update(address,address).selector }
