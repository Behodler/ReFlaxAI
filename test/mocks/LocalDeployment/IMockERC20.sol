// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IMockERC20 {
    function mint(address to, uint256 amount) external;
    function burn(uint256 amount) external;
}