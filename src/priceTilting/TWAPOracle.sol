// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@oz_reflax/contracts/access/Ownable.sol";
import "@oz_reflax/contracts/token/ERC20/IERC20.sol";
import "@uniswap_reflax/core/interfaces/IUniswapV2Pair.sol";
import "@uniswap_reflax/core/interfaces/IUniswapV2Factory.sol";
import "@uniswap_reflax/periphery/lib/FixedPoint.sol";
import "../priceTilting/IOracle.sol";

contract TWAPOracle is IOracle, Ownable {
    using FixedPoint for FixedPoint.uq112x112;
    using FixedPoint for FixedPoint.uq144x112;

    address public immutable factory;
    address public immutable WETH;
    uint256 public constant PERIOD = 1 hours; // TWAP period

    struct PairMeasurement {
        FixedPoint.uq112x112 price0Average;
        FixedPoint.uq112x112 price1Average;
        uint256 lastUpdateTimestamp;
    }

    mapping(address => PairMeasurement) public pairMeasurements;

    event PairUpdated(address indexed pair, uint256 price0Average, uint256 price1Average);

    constructor(address _factory, address _WETH) Ownable(msg.sender) {
        factory = _factory;
        WETH = _WETH;
    }

    modifier validPair(address tokenIn, address tokenOut) {
        address pair = IUniswapV2Factory(factory).getPair(tokenIn, tokenOut);
        require(pair != address(0), "Invalid pair");
        require(pairMeasurements[pair].lastUpdateTimestamp != 0, "Pair not initialized");
        _;
    }

    function update(address tokenA, address tokenB) external {
        address pair = IUniswapV2Factory(factory).getPair(tokenA, tokenB);
        require(pair != address(0), "Invalid pair");

        PairMeasurement storage measurement = pairMeasurements[pair];
        IUniswapV2Pair pairContract = IUniswapV2Pair(pair);

        (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast) = pairContract.getReserves();
        uint256 price0Cumulative = pairContract.price0CumulativeLast();
        uint256 price1Cumulative = pairContract.price1CumulativeLast();

        if (measurement.lastUpdateTimestamp == 0) {
            measurement.lastUpdateTimestamp = blockTimestampLast;
            return;
        }

        uint32 timeElapsed = blockTimestampLast - uint32(measurement.lastUpdateTimestamp);
        if (timeElapsed >= PERIOD) {
            measurement.price0Average = FixedPoint.uq112x112(
                uint224((price0Cumulative - measurement.lastUpdateTimestamp) / timeElapsed)
            );
            measurement.price1Average = FixedPoint.uq112x112(
                uint224((price1Cumulative - measurement.lastUpdateTimestamp) / timeElapsed)
            );
            measurement.lastUpdateTimestamp = blockTimestampLast;
            emit PairUpdated(pair, measurement.price0Average._x, measurement.price1Average._x);
        }
    }

    function consult(address tokenIn, address tokenOut, uint256 amountIn)
        external
        view
        validPair(tokenIn, tokenOut)
        returns (uint256 amountOut)
    {
        tokenOut = tokenOut == address(0) ? WETH : tokenOut;
        address pair = IUniswapV2Factory(factory).getPair(tokenIn, tokenOut);
        PairMeasurement memory measurement = pairMeasurements[pair];
        IUniswapV2Pair pairContract = IUniswapV2Pair(pair);

        if (tokenIn == pairContract.token0()) {
            amountOut = (measurement.price0Average.mul(amountIn)).decode144();
        } else {
            require(tokenIn == pairContract.token1(), "Invalid token");
            amountOut = (measurement.price1Average.mul(amountIn)).decode144();
        }

        require(amountOut > 0, "Zero output");
    }
}