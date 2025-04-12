// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
interface IPriceTilter {
    function tiltPrice(address token, uint256 amount) external;
    function flaxToken() external view returns (address);
    function factory() external view returns (address);
    function getPrice(address tokenA, address tokenB) external returns (uint256);
    function addLiquidity(address tokenA, address tokenB, uint256 amountA, uint256 amountB) external;
}

