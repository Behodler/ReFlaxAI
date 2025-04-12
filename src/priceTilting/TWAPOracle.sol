// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "@oz_reflax/contracts/access/Ownable.sol";
import "@oz_reflax/contracts/token/ERC20/IERC20.sol";
interface IUniswapV2Pair {
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function price0CumulativeLast() external view returns (uint256);
    function price1CumulativeLast() external view returns (uint256);
    function token0() external view returns (address);
    function token1() external view returns (address);
}
contract TWAPOracle is Ownable {
    uint256 public sampleInterval;

struct TWAPData {
    uint256 price0CumulativeLast;
    uint256 price1CumulativeLast;
    uint32 lastBlockTimestamp;
    uint256 price0Average;
    uint256 price1Average;
    uint256 lastUpdateTimestamp;
}

mapping(address => TWAPData) public twapData;

event SampleIntervalUpdated(uint256 newInterval);
event PairInitialized(address indexed pair);
event TWAPUpdated(address indexed pair, uint256 price0Average, uint256 price1Average);

constructor(uint256 _sampleInterval) Ownable(msg.sender) {
    require(_sampleInterval > 0, "Invalid sample interval");
    sampleInterval = _sampleInterval;
}

function setSampleInterval(uint256 _sampleInterval) external onlyOwner {
    require(_sampleInterval > 0, "Invalid sample interval");
    sampleInterval = _sampleInterval;
    emit SampleIntervalUpdated(_sampleInterval);
}

function initializePair(address pair) external onlyOwner {
    require(pair != address(0), "Invalid pair address");
    require(twapData[pair].lastUpdateTimestamp == 0, "Pair already initialized");

    IUniswapV2Pair uniswapPair = IUniswapV2Pair(pair);
    (, , uint32 blockTimestampLast) = uniswapPair.getReserves();

    twapData[pair] = TWAPData({
        price0CumulativeLast: uniswapPair.price0CumulativeLast(),
        price1CumulativeLast: uniswapPair.price1CumulativeLast(),
        lastBlockTimestamp: blockTimestampLast,
        price0Average: 0,
        price1Average: 0,
        lastUpdateTimestamp: block.timestamp
    });

    emit PairInitialized(pair);
}

function updateTWAP(address pair) external {
    TWAPData storage data = twapData[pair];
    require(data.lastUpdateTimestamp != 0, "Pair not initialized");

    uint256 timeElapsed = block.timestamp - data.lastUpdateTimestamp;
    if (timeElapsed >= sampleInterval * 60) {
        IUniswapV2Pair uniswapPair = IUniswapV2Pair(pair);
        (, , uint32 blockTimestampLast) = uniswapPair.getReserves();

        uint256 price0Cumulative = uniswapPair.price0CumulativeLast();
        uint256 price1Cumulative = uniswapPair.price1CumulativeLast();

        uint32 timeElapsedSinceLast = blockTimestampLast - data.lastBlockTimestamp;
        if (timeElapsedSinceLast > 0) {
            uint256 price0Average = (price0Cumulative - data.price0CumulativeLast) / timeElapsedSinceLast;
            uint256 price1Average = (price1Cumulative - data.price1CumulativeLast) / timeElapsedSinceLast;

            data.price0Average = price0Average;
            data.price1Average = price1Average;
            data.price0CumulativeLast = price0Cumulative;
            data.price1CumulativeLast = price1Cumulative;
            data.lastBlockTimestamp = blockTimestampLast;
            data.lastUpdateTimestamp = block.timestamp;

            emit TWAPUpdated(pair, price0Average, price1Average);
        }
    }
}

function getPrice0(address pair) external view returns (uint256) {
    TWAPData storage data = twapData[pair];
    require(data.lastUpdateTimestamp != 0, "Pair not initialized");
    return data.price0Average;
}

function getPrice1(address pair) external view returns (uint256) {
    TWAPData storage data = twapData[pair];
    require(data.lastUpdateTimestamp != 0, "Pair not initialized");
    return data.price1Average;
}

}

