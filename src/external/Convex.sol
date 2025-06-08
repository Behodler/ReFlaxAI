// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IConvexStaking
 * @author Justin Goro
 * @notice Interface for Convex staking contracts
 * @dev Used for staking Curve LP tokens in Convex to earn boosted rewards
 */
interface IConvexStaking {
    /**
     * @notice Stakes LP tokens into the Convex reward pool
     * @param _amount Amount of LP tokens to stake
     * @dev LP tokens must be approved before staking
     */
    function stake(uint256 _amount) external;
    
    /**
     * @notice Withdraws staked LP tokens from the Convex reward pool
     * @param _amount Amount of LP tokens to withdraw
     * @dev Returns the LP tokens to the caller
     */
    function withdraw(uint256 _amount) external;
    
    /**
     * @notice Claims all available rewards from the staking pool
     * @dev Rewards are sent to the caller (typically CRV, CVX, and other tokens)
     */
    function getReward() external;
}