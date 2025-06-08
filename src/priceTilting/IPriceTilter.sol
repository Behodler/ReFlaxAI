// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IPriceTilter
 * @author Justin Goro
 * @notice Interface for price tilter contracts that manage Flax pricing
 * @dev Implements price tilting by adding liquidity with reduced Flax amounts
 */
interface IPriceTilter {
    /**
     * @notice Tilts the price of a token by adding liquidity
     * @param token Address of the token (typically Flax)
     * @param amount Amount of ETH or tokens to use for liquidity
     * @dev Adds less of the specified token than its TWAP value to increase its price
     */
    function tiltPrice(address token, uint256 amount) external;
    
    /**
     * @notice Returns the Flax token address
     * @return Address of the Flax token
     */
    function flaxToken() external view returns (address);
    
    /**
     * @notice Returns the Uniswap factory address
     * @return Address of the Uniswap factory
     */
    function factory() external view returns (address);
    
    /**
     * @notice Gets the current price between two tokens
     * @param tokenA First token in the pair
     * @param tokenB Second token in the pair
     * @return Price of tokenA in terms of tokenB
     * @dev May update oracle before returning price
     */
    function getPrice(address tokenA, address tokenB) external returns (uint256);
    
    /**
     * @notice Adds liquidity to a token pair
     * @param tokenA First token in the pair
     * @param tokenB Second token in the pair
     * @param amountA Amount of tokenA to add
     * @param amountB Amount of tokenB to add
     * @dev Used for general liquidity provision without price tilting
     */
    function addLiquidity(address tokenA, address tokenB, uint256 amountA, uint256 amountB) external;
}

