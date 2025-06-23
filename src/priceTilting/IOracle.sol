// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/**
 * @title IOracle
 * @author Justin Goro
 * @notice Interface for oracle contracts providing time-weighted average prices
 * @dev Used for slippage protection in yield source operations
 */
interface IOracle {
    /**
     * @notice Consults the oracle for the expected output amount based on TWAP
     * @param tokenIn Address of the input token
     * @param tokenOut Address of the output token (address(0) for ETH)
     * @param amountIn Amount of input tokens
     * @return amountOut Expected output amount based on TWAP
     * @dev Used to calculate minimum acceptable amounts for swaps
     */
    function consult(address tokenIn, address tokenOut, uint256 amountIn) external view returns (uint256 amountOut);
    
    /**
     * @notice Updates the TWAP for a given token pair
     * @param tokenA First token in the pair
     * @param tokenB Second token in the pair
     * @dev Should be called before operations to ensure fresh price data
     */
    function update(address tokenA, address tokenB) external;
}
