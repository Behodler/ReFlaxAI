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

/**
 * @title ICurvePoolNG
 * @author Justin Goro
 * @notice Interface for newer Curve StableSwapNG pools that use dynamic arrays
 * @dev Used for pools deployed after StableSwapNG implementation
 */
interface ICurvePoolNG {
    /**
     * @notice Returns the address of a coin in the pool by index
     * @param index Index of the coin
     * @return Address of the coin at the given index
     */
    function coins(uint256 index) external view returns (address);
    
    /**
     * @notice Returns the balance of a coin in the pool by index
     * @param index Index of the coin
     * @return Current balance of the coin in the pool
     */
    function balances(uint256 index) external view returns (uint256);
    
    /**
     * @notice Returns the number of coins in the pool
     * @return Number of coins in the pool
     */
    function N_COINS() external view returns (uint256);
    
    /**
     * @notice Calculates expected LP tokens for given input amounts
     * @param amounts Array of amounts for each coin to add
     * @param is_deposit True for deposits, false for withdrawals
     * @return Expected amount of LP tokens
     * @dev This function accounts for slippage but not fees
     */
    function calc_token_amount(uint256[] memory amounts, bool is_deposit) external view returns (uint256);
    
    /**
     * @notice Calculates output amount for withdrawing one coin
     * @param token_amount Amount of LP tokens to burn
     * @param i Index of the coin to receive
     * @return Amount of coin to receive
     */
    function calc_withdraw_one_coin(uint256 token_amount, int128 i) external view returns (uint256);
    
    /**
     * @notice Gets exchange rate between two coins
     * @param i Index of input coin
     * @param j Index of output coin
     * @param dx Amount of input coin
     * @return Amount of output coin
     */
    function get_dy(int128 i, int128 j, uint256 dx) external view returns (uint256);
    
    /**
     * @notice Gets the virtual price of the pool
     * @return Virtual price scaled by 1e18
     */
    function get_virtual_price() external view returns (uint256);
    
    /**
     * @notice Gets the current fee
     * @return Fee in basis points * 1e4
     */
    function fee() external view returns (uint256);
    
    /**
     * @notice Adds liquidity to the pool using dynamic array
     * @param amounts Array of amounts for each coin to add
     * @param min_mint_amount Minimum LP tokens to receive
     * @return Amount of LP tokens minted
     * @dev Tokens must be approved before calling
     */
    function add_liquidity(uint256[] memory amounts, uint256 min_mint_amount) external returns (uint256);
    
    /**
     * @notice Removes liquidity from the pool in one coin
     * @param token_amount Amount of LP tokens to burn
     * @param i Index of the coin to receive
     * @param min_amount Minimum amount of coin to receive
     * @return Amount of coin received
     */
    function remove_liquidity_one_coin(uint256 token_amount, int128 i, uint256 min_amount) external returns (uint256);
}