// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@oz_reflax/contracts/access/Ownable.sol";
import "@oz_reflax/contracts/token/ERC20/IERC20.sol";
import "../priceTilting/IPriceTilter.sol";

abstract contract AYieldSource is Ownable {
    IERC20 public inputToken;
    IPriceTilter public priceTilter;

    constructor(address _inputToken, address _priceTilter, address _owner) Ownable(_owner) {
        require(_inputToken.code.length > 0, "Invalid inputToken");
        require(_priceTilter.code.length > 0, "Invalid priceTilter");
        inputToken = IERC20(_inputToken);
        priceTilter = IPriceTilter(_priceTilter);
    }

    function deposit(uint256 amount) external virtual returns (uint256);
    function claimRewards() external virtual returns (uint256);
    function withdraw(uint256 amount) external virtual returns (uint256 inputTokenAmount, uint256 flaxValue);
}
