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
        address _inputToken,
        address _priceTilter,
        address _curvePool,
        address _convexStakingContract,
        address _uniswapRouter,
        address _crvToken,
        address _cvxToken,
        address _weth,
        uint256 _tiltRatio
    ) AYieldSource(_inputToken, _priceTilter, msg.sender) {
        require(_inputToken.code.length > 0, "Invalid inputToken");
        (bool success,) = _inputToken.call(
            abi.encodeWithSignature("transferFrom(address,address,uint256)", address(0), address(0), 0)
        );
        require(success, "inputToken transferFrom not supported");
        (success,) = _inputToken.call(abi.encodeWithSignature("balanceOf(address)", address(0)));
        require(success, "inputToken balanceOf not supported");

        require(_priceTilter.code.length > 0, "Invalid priceTilter");
        (success,) = _priceTilter.call(abi.encodeWithSignature("flaxToken()"));
        require(success, "priceTilter flaxToken not supported");
        (success,) = _priceTilter.call(abi.encodeWithSignature("getPrice(address,address)", address(0), address(0)));
        require(success, "priceTilter getPrice not supported");
        (success,) = _priceTilter.call(
            abi.encodeWithSignature("addLiquidity(address,address,uint256,uint256)", address(0), address(0), 0, 0)
        );
        require(success, "priceTilter addLiquidity not supported");

        require(_curvePool.code.length > 0, "Invalid curvePool");
        (success,) = _curvePool.call(abi.encodeWithSignature("coins(uint256)", 0));
        require(success, "curvePool coins not supported");
        (success,) = _curvePool.call(abi.encodeWithSignature("balances(uint256)", 0));
        require(success, "curvePool balances not supported");
        (success,) = _curvePool.call(abi.encodeWithSignature("add_liquidity(uint256[2],uint256)", [uint256(0), 0], 0));
        require(success, "curvePool add_liquidity not supported");
        (success,) =
            _curvePool.call(abi.encodeWithSignature("remove_liquidity(uint256,uint256[2])", 0, [uint256(0), 0]));
        require(success, "curvePool remove_liquidity not supported");

        require(_convexStakingContract.code.length > 0, "Invalid convexStakingContract");
        (success,) = _convexStakingContract.call(abi.encodeWithSignature("stake(uint256)", 0));
        require(success, "convexStakingContract stake not supported");
        (success,) = _convexStakingContract.call(abi.encodeWithSignature("withdraw(uint256)", 0));
        require(success, "convexStakingContract withdraw not supported");
        (success,) = _convexStakingContract.call(abi.encodeWithSignature("getReward()"));
        require(success, "convexStakingContract getReward not supported");

        require(_uniswapRouter.code.length > 0, "Invalid uniswapRouter");
        (success,) = _uniswapRouter.call(
            abi.encodeWithSignature(
                "swapExactTokensForTokens(uint256,uint256,address[],address,uint256)",
                0,
                0,
                new address[](0),
                address(0),
                0
            )
        );
        require(success, "uniswapRouter swapExactTokensForTokens not supported");
        (success,) = _uniswapRouter.call(
            abi.encodeWithSignature(
                "swapExactTokensForETH(uint256,uint256,address[],address,uint256)",
                0,
                0,
                new address[](0),
                address(0),
                0
            )
        );
        require(success, "uniswapRouter swapExactTokensForETH not supported");

        require(_crvToken.code.length > 0, "Invalid crvToken");
        (success,) = _crvToken.call(abi.encodeWithSignature("balanceOf(address)", address(0)));
        require(success, "crvToken balanceOf not supported");
        (success,) = _crvToken.call(abi.encodeWithSignature("approve(address,uint256)", address(0), 0));
        require(success, "crvToken approve not supported");

        require(_cvxToken.code.length > 0, "Invalid cvxToken");
        (success,) = _cvxToken.call(abi.encodeWithSignature("balanceOf(address)", address(0)));
        require(success, "cvxToken balanceOf not supported");
        (success,) = _cvxToken.call(abi.encodeWithSignature("approve(address,uint256)", address(0), 0));
        require(success, "cvxToken approve not supported");

        require(_weth.code.length > 0, "Invalid weth");
        (success,) = _weth.call(abi.encodeWithSignature("deposit()"));
        require(success, "weth deposit not supported");
        (success,) = _weth.call(abi.encodeWithSignature("approve(address,uint256)", address(0), 0));
        require(success, "weth approve not supported");

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

    function withdraw(uint256 lpAmount)
        external
        override
        claimsRewards
        returns (uint256 inputTokenAmount, uint256 flaxValue)
    {
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
            uint256 flax_per_weth = (10 ** 36) / twapPrice;
            uint256 flaxForLiquidity = (ethBalance * tiltRatio / 10000 * flax_per_weth) / 10 ** 18;
            IERC20(flax).transfer(address(this), flaxForLiquidity);
            IWETH(weth).deposit{value: ethBalance}();
            IERC20(flax).approve(address(priceTilter), flaxForLiquidity);
            IERC20(weth).approve(address(priceTilter), ethBalance);
            priceTilter.addLiquidity(flax, weth, flaxForLiquidity, ethBalance);
        }
    }

    function _getFlaxValue() private returns (uint256) {
        uint256 ethBalance = address(this).balance;
        if (ethBalance == 0) return 0;
        address flax = priceTilter.flaxToken();
        uint256 twapPrice = priceTilter.getPrice(flax, weth);
        uint256 flax_per_weth = (10 ** 36) / twapPrice;
        return (ethBalance * flax_per_weth) / 10 ** 18;
    }

    function swapTokenToToken(address fromToken, address toToken, uint256 amountIn, uint256 minAmountOut) internal {
        IERC20(fromToken).approve(uniswapRouter, amountIn);
        address[] memory path = new address[](2);
        path[0] = fromToken;
        path[1] = toToken;
        IUniswapV2Router02(uniswapRouter).swapExactTokensForTokens(
            amountIn, minAmountOut, path, address(this), block.timestamp + 300
        );
    }

    function sellTokenForETH(address token, uint256 amountIn) internal {
        IERC20(token).approve(uniswapRouter, amountIn);
        address[] memory path = new address[](2);
        path[0] = token;
        path[1] = weth;
        IUniswapV2Router02(uniswapRouter).swapExactTokensForETH(amountIn, 0, path, address(this), block.timestamp + 300);
    }

    receive() external payable {}
}
