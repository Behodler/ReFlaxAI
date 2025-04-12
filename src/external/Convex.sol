// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IConvexStaking {
    function stake(uint256 _amount) external;
    function withdraw(uint256 _amount) external;
    function getReward() external;
}