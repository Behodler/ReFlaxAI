// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "@oz_reflax/contracts/token/ERC20/IERC20.sol";
import "./AYieldSource.sol";
import "../priceTilting/IPriceTilter.sol";
import "../external/UniswapV2.sol";
import {IWETH} from "../external/UniswapV2.sol";
import {ICurvePool} from "../external/Curve.sol";
import {IConvexStaking} from "../external/Convex.sol";

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
    ) AYieldSource(_inputToken, _priceTilter, msg.sender) {
        curvePool = _curvePool;
        convexStakingContract = _convexStakingContract;
        uniswapRouter = _uniswapRouter;
        crvToken = _crvToken;
        cvxToken = _cvxToken;
        weth = _weth;
        tiltRatio = _tiltRatio;
    }

    modifier claimsRewards() {
        _claimAndProcessRewards();
        _;
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

    function claimRewards() external override claimsRewards returns (uint256) {
        return _getFlaxValue();
    }

    function withdraw(uint256 lpAmount) external override claimsRewards returns (uint256 inputTokenAmount, uint256 flaxValue) {
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
        inputTokenAmount = inputToken.balanceOf(address(this));
        inputToken.transfer(msg.sender, inputTokenAmount);
        flaxValue = _getFlaxValue();
        return (inputTokenAmount, flaxValue);
    }

    function _claimAndProcessRewards() private {
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
        if (ethBalance > 0) {
            address flax = priceTilter.flaxToken();
            uint256 twapPrice = priceTilter.getPrice(flax, weth);
            uint256 flax_per_weth = (10**36) / twapPrice;
            uint256 flaxForLiquidity = (ethBalance * tiltRatio / 10000 * flax_per_weth) / 10**18;
            IERC20(flax).transfer(address(this), flaxForLiquidity);
            IWETH(weth).deposit{value: ethBalance}();
            IERC20(flax).approve(address(priceTilter), flaxForLiquidity);
            IERC20(weth).approve(address(priceTilter), ethBalance);
            priceTilter.addLiquidity(flax, weth, flaxForLiquidity, ethBalance);
        }
    }

    function _getFlaxValue() private  returns (uint256) {
        uint256 ethBalance = address(this).balance;
        if (ethBalance == 0) return 0;
        address flax = priceTilter.flaxToken();
        uint256 twapPrice = priceTilter.getPrice(flax, weth);
        uint256 flax_per_weth = (10**36) / twapPrice;
        return (ethBalance * flax_per_weth) / 10**18;
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