// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ICurvePool {
    function coins(uint256) external view returns (address);
    function balances(uint256) external view returns (uint256);
    function add_liquidity(uint256[2] memory amounts, uint256 min_mint_amount) external returns (uint256);
    function remove_liquidity(uint256 _amount, uint256[2] memory min_amounts) external;
}