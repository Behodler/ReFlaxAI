// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IUniswapV3Router
 * @author Justin Goro
 * @notice Interface for Uniswap V3 swap router (subset of functions)
 * @dev Used for single-hop token swaps with exact input amounts
 */
interface IUniswapV3Router {
    /**
     * @notice Parameters for single-hop exact input swaps
     * @param tokenIn Address of the input token
     * @param tokenOut Address of the output token
     * @param fee Pool fee tier (e.g., 3000 for 0.3%)
     * @param recipient Address to receive output tokens
     * @param amountIn Exact amount of input tokens to swap
     * @param amountOutMinimum Minimum acceptable output amount
     * @param sqrtPriceLimitX96 Price limit (0 for no limit)
     */
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    /**
     * @notice Swaps exact amount of input tokens for output tokens
     * @param params Swap parameters including tokens, amounts, and limits
     * @return amountOut Amount of output tokens received
     * @dev Input tokens must be approved or ETH sent with call
     */
    function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut);
} 