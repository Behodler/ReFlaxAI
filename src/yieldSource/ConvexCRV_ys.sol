// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "@oz_reflax/contracts/token/ERC20/IERC20.sol";
import "./AYieldSource.sol";
import "../priceTilting/IPriceTilter.sol";
import {Flax} from "../Flax.sol";
import "../external/UniswapV2.sol";

interface ICurvePool {
    function coins(uint256) external view returns (address);
    function balances(uint256) external view returns (uint256);
    function add_liquidity(uint256[2] memory amounts, uint256 min_mint_amount) external returns (uint256);
    function remove_liquidity(uint256 _amount, uint256[2] memory min_amounts) external;
}
interface IConvexStaking {
    function stake(uint256 _amount) external;
    function withdraw(uint256 _amount) external;
    function getReward() external;
}
interface IWETH is IERC20 {
    function deposit() external payable;
    function withdraw(uint256 wad) external;
}
contract ConvexCurveYieldSource is AYieldSource {
    address public curvePool;
    address public convexStakingContract;
    address public uniswapRouter;
    address public crvToken;
    address public cvxToken;
    address public weth;
    uint256 public tiltRatio;

constructor(
    IERC20 _inputToken,
    IPriceTilter _priceTilter,
    address _curvePool,
    address _convexStakingContract,
    address _uniswapRouter,
    address _crvToken,
    address _cvxToken,
    address _weth,
    uint256 _tiltRatio
) AYieldSource(_inputToken, _priceTilter) Ownable(msg.sender) {
    curvePool = _curvePool;
    convexStakingContract = _convexStakingContract;
    uniswapRouter = _uniswapRouter;
    crvToken = _crvToken;
    cvxToken = _cvxToken;
    weth = _weth;
    tiltRatio = _tiltRatio;
}

function deposit(uint256 amount) external override returns (uint256) {
    inputToken.transferFrom(msg.sender, address(this), amount);
    address coin0 = ICurvePool(curvePool).coins(0);
    address coin1 = ICurvePool(curvePool).coins(1);
    uint256 balance0 = ICurvePool(curvePool).balances(0);
    uint256 balance1 = ICurvePool(curvePool).balances(1);
    uint256 total_balance = balance0 + balance1;
    uint256 amount_to_coin0;
    uint256 amount_to_coin1;
    if (total_balance == 0) {
        amount_to_coin0 = amount / 2;
        amount_to_coin1 = amount - amount_to_coin0;
    } else {
        uint256 fraction_coin0 = (balance0 * 1e18) / total_balance;
        amount_to_coin0 = (amount * fraction_coin0) / 1e18;
        amount_to_coin1 = amount - amount_to_coin0;
    }
    uint256 amount_coin0;
    uint256 amount_coin1;
    if (address(inputToken) == coin0) {
        amount_coin0 = amount_to_coin0;
        swapTokenToToken(address(inputToken), coin1, amount_to_coin1, 0);
        amount_coin1 = IERC20(coin1).balanceOf(address(this));
    } else if (address(inputToken) == coin1) {
        amount_coin1 = amount_to_coin1;
        swapTokenToToken(address(inputToken), coin0, amount_to_coin0, 0);
        amount_coin0 = IERC20(coin0).balanceOf(address(this));
    } else {
        swapTokenToToken(address(inputToken), coin0, amount_to_coin0, 0);
        swapTokenToToken(address(inputToken), coin1, amount_to_coin1, 0);
        amount_coin0 = IERC20(coin0).balanceOf(address(this));
        amount_coin1 = IERC20(coin1).balanceOf(address(this));
    }
    IERC20(coin0).approve(curvePool, amount_coin0);
    IERC20(coin1).approve(curvePool, amount_coin1);
    uint256[2] memory amounts = [amount_coin0, amount_coin1];
    uint256 lpAmount = ICurvePool(curvePool).add_liquidity(amounts, 0);
    IERC20(curvePool).approve(convexStakingContract, lpAmount);
    IConvexStaking(convexStakingContract).stake(lpAmount);
    return lpAmount;
}

function claimRewards() external override returns (uint256) {
    IConvexStaking(convexStakingContract).getReward();
    uint256 crvBalance = IERC20(crvToken).balanceOf(address(this));
    uint256 cvxBalance = IERC20(cvxToken).balanceOf(address(this));
    if (crvBalance > 0) {
        sellTokenForETH(crvToken, crvBalance);
    }
    if (cvxBalance > 0) {
        sellTokenForETH(cvxToken, cvxBalance);
    }
    uint256 ethBalance = address(this).balance;
    address flax = priceTilter.flaxToken(); // Updated to use interface

    uint256 twapPrice = priceTilter.getPrice(flax, weth); // Updated to use interface
    uint256 flax_per_weth = (10**36) / twapPrice;
    uint256 flaxValue = (ethBalance * flax_per_weth) / 10**18;
    uint256 flaxForLiquidity = (ethBalance * tiltRatio / 10000 * flax_per_weth) / 10**18;
    Flax(flax).mint(address(this), flaxForLiquidity);
    IWETH(weth).deposit{value: ethBalance}();
    IERC20(flax).approve(address(priceTilter), flaxForLiquidity); // Updated to use interface
    IERC20(weth).approve(address(priceTilter), ethBalance); // Updated to use interface
    priceTilter.addLiquidity(flax, weth, flaxForLiquidity, ethBalance); // Updated to use interface
    return flaxValue;
}

function withdraw(uint256 lpAmount) external override returns (uint256) {
    IConvexStaking(convexStakingContract).withdraw(lpAmount);
    ICurvePool(curvePool).remove_liquidity(lpAmount, [uint256(0), 0]);
    address coin0 = ICurvePool(curvePool).coins(0);
    address coin1 = ICurvePool(curvePool).coins(1);
    uint256 balance_coin0 = IERC20(coin0).balanceOf(address(this));
    uint256 balance_coin1 = IERC20(coin1).balanceOf(address(this));
    if (coin0 != address(inputToken)) {
        swapTokenToToken(coin0, address(inputToken), balance_coin0, 0);
    }
    if (coin1 != address(inputToken)) {
        swapTokenToToken(coin1, address(inputToken), balance_coin1, 0);
    }
    uint256 inputTokenBalance = inputToken.balanceOf(address(this));
    inputToken.transfer(msg.sender, inputTokenBalance);
    return inputTokenBalance;
}

function swapTokenToToken(address fromToken, address toToken, uint256 amountIn, uint256 minAmountOut) internal {
    IERC20(fromToken).approve(uniswapRouter, amountIn);
    address[] memory path = new address[](2);
    path[0] = fromToken;
    path[1] = toToken;
    IUniswapV2Router02(uniswapRouter).swapExactTokensForTokens(
        amountIn,
        minAmountOut,
        path,
        address(this),
        block.timestamp + 300
    );
}

function sellTokenForETH(address token, uint256 amountIn) internal {
    IERC20(token).approve(uniswapRouter, amountIn);
    address[] memory path = new address[](2);
    path[0] = token;
    path[1] = weth;
    IUniswapV2Router02(uniswapRouter).swapExactTokensForETH(
        amountIn,
        0,
        path,
        address(this),
        block.timestamp + 300
    );
}

receive() external payable {}

}

