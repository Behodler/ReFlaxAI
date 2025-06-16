// Certora Specification for TWAPOracle Contract
// This file defines formal verification rules for the TWAPOracle contract

using TWAPOracle as oracle
using UniswapV2Pair as pair
using UniswapV2Factory as factory

methods {
    // Oracle methods
    update(address, address) envfree
    consult(address, address, uint256) returns (uint256) envfree
    
    // View methods
    factory() returns (address) envfree
    WETH() returns (address) envfree
    PERIOD() returns (uint256) envfree
    pairMeasurements(address) returns (uint112, uint112, uint256, uint256, uint256) envfree
    
    // Pair methods
    pair.getReserves() returns (uint112, uint112, uint32) envfree => DISPATCHER(true)
    pair.price0CumulativeLast() returns (uint256) envfree => DISPATCHER(true)
    pair.price1CumulativeLast() returns (uint256) envfree => DISPATCHER(true)
    pair.token0() returns (address) envfree => DISPATCHER(true)
    pair.token1() returns (address) envfree => DISPATCHER(true)
    
    // Factory methods
    factory.getPair(address, address) returns (address) envfree => DISPATCHER(true)
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
    PERIOD() == 3600

// Time must advance for price updates
rule timeAdvancesForUpdate(env e, address tokenA, address tokenB) {
    address pairAddr = factory.getPair(tokenA, tokenB);
    require pairAddr != 0;
    
    uint112 price0Avg, price1Avg, lastTimestamp, lastP0Cum, lastP1Cum;
    price0Avg, price1Avg, lastTimestamp, lastP0Cum, lastP1Cum = pairMeasurements(pairAddr);
    
    uint112 r0, r1;
    uint32 blockTimestamp;
    r0, r1, blockTimestamp = pair.getReserves();
    
    update(e, tokenA, tokenB);
    
    uint112 price0AvgAfter, price1AvgAfter, lastTimestampAfter, lastP0CumAfter, lastP1CumAfter;
    price0AvgAfter, price1AvgAfter, lastTimestampAfter, lastP0CumAfter, lastP1CumAfter = pairMeasurements(pairAddr);
    
    // If update happened, time must have advanced
    assert (lastTimestampAfter != lastTimestamp) => (lastTimestampAfter > lastTimestamp);
}

// Cumulative prices are monotonic
rule cumulativePricesNeverDecrease(env e, address tokenA, address tokenB) {
    address pairAddr = factory.getPair(tokenA, tokenB);
    require pairAddr != 0;
    
    uint256 price0CumBefore = pair.price0CumulativeLast();
    uint256 price1CumBefore = pair.price1CumulativeLast();
    
    update(e, tokenA, tokenB);
    
    uint256 price0CumAfter = pair.price0CumulativeLast();
    uint256 price1CumAfter = pair.price1CumulativeLast();
    
    assert price0CumAfter >= price0CumBefore;
    assert price1CumAfter >= price1CumBefore;
}

// First update only initializes
rule firstUpdateOnlyInitializes(env e, address tokenA, address tokenB) {
    address pairAddr = factory.getPair(tokenA, tokenB);
    require pairAddr != 0;
    
    uint112 price0Avg, price1Avg, lastTimestamp, lastP0Cum, lastP1Cum;
    price0Avg, price1Avg, lastTimestamp, lastP0Cum, lastP1Cum = pairMeasurements(pairAddr);
    
    require lastTimestamp == 0; // First update
    
    update(e, tokenA, tokenB);
    
    uint112 price0AvgAfter, price1AvgAfter, lastTimestampAfter, lastP0CumAfter, lastP1CumAfter;
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
    
    uint112 price0Avg, price1Avg, lastTimestamp, lastP0Cum, lastP1Cum;
    price0Avg, price1Avg, lastTimestamp, lastP0Cum, lastP1Cum = pairMeasurements(pairAddr);
    
    require lastTimestamp > 0; // Not first update
    
    uint112 r0, r1;
    uint32 blockTimestamp;
    r0, r1, blockTimestamp = pair.getReserves();
    
    uint256 timeElapsed = blockTimestamp - lastTimestamp;
    require timeElapsed < PERIOD(); // Less than 1 hour
    
    update(e, tokenA, tokenB);
    
    uint112 price0AvgAfter, price1AvgAfter, lastTimestampAfter, lastP0CumAfter, lastP1CumAfter;
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
    
    uint112 price0Avg, price1Avg, lastTimestamp, lastP0Cum, lastP1Cum;
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
    
    uint112 price0Avg, price1Avg, lastTimestamp, lastP0Cum, lastP1Cum;
    price0Avg, price1Avg, lastTimestamp, lastP0Cum, lastP1Cum = pairMeasurements(pairAddr);
    
    require lastTimestamp > 0; // Already initialized
    
    uint256 currentP0Cum = pair.price0CumulativeLast();
    uint256 currentP1Cum = pair.price1CumulativeLast();
    
    uint112 r0, r1;
    uint32 blockTimestamp;
    r0, r1, blockTimestamp = pair.getReserves();
    
    uint256 timeElapsed = blockTimestamp - lastTimestamp;
    require timeElapsed >= PERIOD();
    
    update(e, tokenA, tokenB);
    
    uint112 price0AvgAfter, price1AvgAfter, lastTimestampAfter, lastP0CumAfter, lastP1CumAfter;
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
    
    uint112 price0Avg, price1Avg, lastTimestamp, lastP0Cum, lastP1Cum;
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
    
    uint112 price0Avg, price1Avg, lastTimestamp, lastP0Cum, lastP1Cum;
    price0Avg, price1Avg, lastTimestamp, lastP0Cum, lastP1Cum = pairMeasurements(pairAddr);
    
    update(e, tokenA, tokenB);
    
    uint112 price0AvgMid, price1AvgMid, lastTimestampMid, lastP0CumMid, lastP1CumMid;
    price0AvgMid, price1AvgMid, lastTimestampMid, lastP0CumMid, lastP1CumMid = pairMeasurements(pairAddr);
    
    // Second update in same conditions
    update(e, tokenA, tokenB);
    
    uint112 price0AvgAfter, price1AvgAfter, lastTimestampAfter, lastP0CumAfter, lastP1CumAfter;
    price0AvgAfter, price1AvgAfter, lastTimestampAfter, lastP0CumAfter, lastP1CumAfter = pairMeasurements(pairAddr);
    
    // State should be same after both updates
    assert price0AvgAfter == price0AvgMid;
    assert price1AvgAfter == price1AvgMid;
    assert lastTimestampAfter == lastTimestampMid;
}