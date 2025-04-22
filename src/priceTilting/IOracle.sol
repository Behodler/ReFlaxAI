// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IOracle {
    function consult(address tokenIn, address tokenOut, uint256 amountIn) external view returns (uint256 amountOut);
    function update(address tokenA, address tokenB) external;
}
