// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "@oz_reflax/contracts/access/Ownable.sol";
import "@oz_reflax/contracts/token/ERC20/IERC20.sol";
import "../priceTilting/IPriceTilter.sol";

abstract contract AYieldSource is Ownable {
    IERC20 public inputToken;
    IPriceTilter public priceTilter;

constructor(IERC20 _inputToken, IPriceTilter _priceTilter) {
    inputToken = _inputToken;
    priceTilter = _priceTilter;
}

function deposit(uint256 amount) external virtual returns (uint256);
function claimRewards() external virtual returns (uint256);
function withdraw(uint256 amount) external virtual returns (uint256);

}

