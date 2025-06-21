// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../src/priceTilting/TWAPOracle.sol";

/**
 * @title TWAPOracleHarness
 * @dev Test harness for TWAPOracle formal verification
 * Exposes internal functions and state for better testability
 */
contract TWAPOracleHarness is TWAPOracle {
    
    constructor(address _factory, address _WETH) TWAPOracle(_factory, _WETH) {}
    
    // Expose pairMeasurements struct fields for verification
    function getPairMeasurement(address pair) 
        external 
        view 
        returns (
            uint224 price0Average,
            uint224 price1Average, 
            uint32 lastUpdateTimestamp,
            uint256 lastPrice0Cumulative,
            uint256 lastPrice1Cumulative
        )
    {
        PairMeasurement storage measurement = pairMeasurements[pair];
        return (
            FixedPoint.decode112with18(measurement.price0Average),
            FixedPoint.decode112with18(measurement.price1Average),
            measurement.lastUpdateTimestamp,
            measurement.lastPrice0Cumulative,
            measurement.lastPrice1Cumulative
        );
    }
    
    // Individual field getters for cleaner verification
    function getLastUpdateTimestamp(address pair) external view returns (uint32) {
        return pairMeasurements[pair].lastUpdateTimestamp;
    }
    
    function getPrice0Average(address pair) external view returns (uint224) {
        return FixedPoint.decode112with18(pairMeasurements[pair].price0Average);
    }
    
    function getPrice1Average(address pair) external view returns (uint224) {
        return FixedPoint.decode112with18(pairMeasurements[pair].price1Average);
    }
    
    function getLastPrice0Cumulative(address pair) external view returns (uint256) {
        return pairMeasurements[pair].lastPrice0Cumulative;
    }
    
    function getLastPrice1Cumulative(address pair) external view returns (uint256) {
        return pairMeasurements[pair].lastPrice1Cumulative;
    }
    
    // Expose internal helper functions for verification
    function sortTokensWrapper(address tokenA, address tokenB) 
        external 
        pure 
        returns (address token0, address token1) 
    {
        return sortTokens(tokenA, tokenB);
    }
    
    function pairForWrapper(address tokenA, address tokenB) 
        external 
        view 
        returns (address pair) 
    {
        return pairFor(factory, tokenA, tokenB);
    }
    
    // Helper to check if pair is initialized
    function isPairInitialized(address pair) external view returns (bool) {
        return pairMeasurements[pair].lastUpdateTimestamp > 0;
    }
    
    // Helper to check if pair has valid TWAP data
    function hasValidTWAPData(address pair) external view returns (bool) {
        PairMeasurement storage measurement = pairMeasurements[pair];
        return measurement.lastUpdateTimestamp > 0 && 
               (measurement.price0Average._x > 0 || measurement.price1Average._x > 0);
    }
    
    // Time elapsed calculation helper
    function getTimeElapsed(address pair, uint32 currentTimestamp) 
        external 
        view 
        returns (uint256) 
    {
        uint32 lastUpdate = pairMeasurements[pair].lastUpdateTimestamp;
        if (lastUpdate == 0) return 0;
        return currentTimestamp > lastUpdate ? currentTimestamp - lastUpdate : 0;
    }
    
    // Check if update would occur given current conditions
    function wouldUpdate(address tokenA, address tokenB, uint32 currentTimestamp) 
        external 
        view 
        returns (bool) 
    {
        address pair = pairFor(factory, tokenA, tokenB);
        uint32 lastUpdate = pairMeasurements[pair].lastUpdateTimestamp;
        
        if (lastUpdate == 0) return true; // First update
        
        uint256 timeElapsed = currentTimestamp > lastUpdate ? currentTimestamp - lastUpdate : 0;
        return timeElapsed >= PERIOD;
    }
    
    // Simulate TWAP calculation without state changes
    function simulateTWAPCalculation(
        address tokenA, 
        address tokenB,
        uint256 currentPrice0Cumulative,
        uint256 currentPrice1Cumulative,
        uint32 currentTimestamp
    ) 
        external 
        view 
        returns (uint224 price0Average, uint224 price1Average) 
    {
        address pair = pairFor(factory, tokenA, tokenB);
        PairMeasurement storage measurement = pairMeasurements[pair];
        
        if (measurement.lastUpdateTimestamp == 0) {
            return (0, 0); // First update doesn't calculate averages
        }
        
        uint256 timeElapsed = currentTimestamp - measurement.lastUpdateTimestamp;
        if (timeElapsed < PERIOD) {
            return (
                FixedPoint.decode112with18(measurement.price0Average),
                FixedPoint.decode112with18(measurement.price1Average)
            );
        }
        
        // Calculate new averages
        uint224 price0Avg = FixedPoint.fraction(
            currentPrice0Cumulative - measurement.lastPrice0Cumulative,
            timeElapsed
        );
        uint224 price1Avg = FixedPoint.fraction(
            currentPrice1Cumulative - measurement.lastPrice1Cumulative,
            timeElapsed
        );
        
        return (FixedPoint.decode112with18(price0Avg), FixedPoint.decode112with18(price1Avg));
    }
    
    // Get all pair data in one call for efficient verification
    function getPairData(address tokenA, address tokenB) 
        external 
        view 
        returns (
            address pair,
            bool initialized,
            bool hasValidTWAP,
            uint32 lastUpdateTimestamp,
            uint224 price0Average,
            uint224 price1Average,
            uint256 lastPrice0Cumulative,
            uint256 lastPrice1Cumulative
        )
    {
        pair = pairFor(factory, tokenA, tokenB);
        PairMeasurement storage measurement = pairMeasurements[pair];
        
        initialized = measurement.lastUpdateTimestamp > 0;
        hasValidTWAP = initialized && (measurement.price0Average._x > 0 || measurement.price1Average._x > 0);
        lastUpdateTimestamp = measurement.lastUpdateTimestamp;
        price0Average = FixedPoint.decode112with18(measurement.price0Average);
        price1Average = FixedPoint.decode112with18(measurement.price1Average);
        lastPrice0Cumulative = measurement.lastPrice0Cumulative;
        lastPrice1Cumulative = measurement.lastPrice1Cumulative;
    }
    
    // Test WETH conversion logic
    function testWETHConversion(address token) external view returns (address convertedToken) {
        return token == address(0) ? WETH : token;
    }
    
    // Boundary condition testing
    function testBoundaryConditions(
        uint256 timeElapsed,
        uint256 priceCumulativeDiff
    ) 
        external 
        pure 
        returns (bool isValidTimeElapsed, bool isValidPriceDiff) 
    {
        isValidTimeElapsed = timeElapsed >= 3600 && timeElapsed < 365 days;
        isValidPriceDiff = priceCumulativeDiff < type(uint256).max / (2**112);
        return (isValidTimeElapsed, isValidPriceDiff);
    }
}