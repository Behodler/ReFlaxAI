// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title ICurvePool
 * @author Justin Goro
 * @notice Interface for Curve pool contracts with 2 tokens
 * @dev Used for adding/removing liquidity from Curve stable pools
 */
interface ICurvePool {
    /**
     * @notice Returns the address of a coin in the pool by index
     * @param index Index of the coin (0 or 1 for 2-token pools)
     * @return Address of the coin at the given index
     */
    function coins(uint256 index) external view returns (address);
    
    /**
     * @notice Returns the balance of a coin in the pool by index
     * @param index Index of the coin (0 or 1 for 2-token pools)
     * @return Current balance of the coin in the pool
     */
    function balances(uint256 index) external view returns (uint256);
    
    /**
     * @notice Adds liquidity to the pool
     * @param amounts Array of amounts for each coin to add
     * @param min_mint_amount Minimum LP tokens to receive
     * @return Amount of LP tokens minted
     * @dev Tokens must be approved before calling
     */
    function add_liquidity(uint256[2] memory amounts, uint256 min_mint_amount) external returns (uint256);
    
    /**
     * @notice Removes liquidity from the pool proportionally
     * @param _amount Amount of LP tokens to burn
     * @param min_amounts Minimum amounts of each coin to receive
     * @dev LP tokens must be approved before calling
     */
    function remove_liquidity(uint256 _amount, uint256[2] memory min_amounts) external;
}