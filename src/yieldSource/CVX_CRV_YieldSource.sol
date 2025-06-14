// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AYieldSource} from "./AYieldSource.sol";
import {IERC20} from "@oz_reflax/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@oz_reflax/contracts/token/ERC20/utils/SafeERC20.sol";

interface IUniswapV3Router {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }
    function exactInputSingle(ExactInputSingleParams calldata params) external returns (uint256);
}

interface ICurvePool {
    function add_liquidity(uint256[4] calldata amounts, uint256 min_mint_amount) external returns (uint256);
    function remove_liquidity_one_coin(uint256 token_amount, int128 i, uint256 min_amount) external returns (uint256);
    function coins(uint256 i) external view returns (address);
}

interface IConvexBooster {
    function deposit(uint256 pid, uint256 amount, bool stake) external returns (bool);
    function withdraw(uint256 pid, uint256 amount) external returns (bool);
}

interface IConvexRewardPool {
    function getReward() external returns (bool);
}

contract CVX_CRV_YieldSource is AYieldSource {
    using SafeERC20 for IERC20;

    IERC20[] public poolTokens; // e.g., USDC, USDT, DAI
    string[] public poolTokenSymbols; // e.g., ["USDC", "USDT", "DAI"]
    mapping(address => uint256[]) public underlyingWeights; // Pool => weights
    address public immutable curvePool; // CRV pool
    IERC20 public immutable crvLpToken; // CRV LP token
    address public immutable convexBooster; // Convex Booster
    address public immutable convexRewardPool; // Convex Reward Pool
    uint256 public immutable poolId; // Convex pool ID
    address public immutable uniswapV3Router; // Uniswap V3 router
    uint24 public constant UNISWAP_FEE = 3000; // 0.3% fee tier

    event UnderlyingWeightsUpdated(address indexed pool, uint256[] weights);

    constructor(
        address _inputToken, // e.g., USDC
        address _flaxToken,
        address _priceTilter,
        address _oracle, // TWAPOracle
        string memory _lpTokenName, // "CRV triusd"
        address _curvePool,
        address _crvLpToken,
        address _convexBooster,
        address _convexRewardPool,
        uint256 _poolId,
        address _uniswapV3Router,
        address[] memory _poolTokens, // 2–4 tokens
        string[] memory _poolTokenSymbols, // e.g., ["USDC", "USDT", "DAI"]
        address[] memory _rewardTokens // Arbitrary reward tokens
    ) AYieldSource(_inputToken, _flaxToken, _priceTilter, _oracle, _lpTokenName) {
        require(_poolTokens.length >= 2 && _poolTokens.length <= 4, "Invalid pool token count");
        require(_poolTokens.length == _poolTokenSymbols.length, "Mismatched symbols");

        curvePool = _curvePool;
        crvLpToken = IERC20(_crvLpToken);
        convexBooster = _convexBooster;
        convexRewardPool = _convexRewardPool;
        poolId = _poolId;
        uniswapV3Router = _uniswapV3Router;

        // Initialize pool tokens and symbolsapprove
        for (uint256 i = 0; i < _poolTokens.length; i++) {
            poolTokens.push(IERC20(_poolTokens[i]));
            poolTokenSymbols.push(_poolTokenSymbols[i]);
            IERC20(_poolTokens[i]).approve(_curvePool, type(uint256).max);
        }

        // Initialize reward tokens
        for (uint256 i = 0; i < _rewardTokens.length; i++) {
            rewardTokens.push(_rewardTokens[i]);
        }

        // Approve tokens
        inputToken.approve(_uniswapV3Router, type(uint256).max);
        crvLpToken.approve(_convexBooster, type(uint256).max);
    }

    function setUnderlyingWeights(address pool, uint256[] memory weights) external onlyOwner {
        require(pool == curvePool, "Invalid pool");
        require(weights.length == poolTokens.length, "Mismatched weights");
        uint256 total;
        for (uint256 i = 0; i < weights.length; i++) {
            total += weights[i];
        }
        require(total == 10000, "Weights must sum to 100%");
        underlyingWeights[pool] = weights;
        emit UnderlyingWeightsUpdated(pool, weights);
    }

    function _depositToProtocol(uint256 amount) internal override returns (uint256) {
        // Allocate inputToken based on weights
        uint256[] memory weights = underlyingWeights[curvePool];
        if (weights.length == 0) {
            weights = new uint256[](poolTokens.length);
            for (uint256 i = 0; i < poolTokens.length; i++) {
                weights[i] = 10000 / poolTokens.length;
            }
        }

        uint256[] memory amounts = new uint256[](poolTokens.length);
        amounts[0] = (amount * weights[0]) / 10000; // inputToken (e.g., USDC)
        for (uint256 i = 1; i < poolTokens.length; i++) {
            uint256 swapAmount = (amount * weights[i]) / 10000;
            uint256 minOut = oracle.consult(address(inputToken), address(poolTokens[i]), swapAmount);
            minOut = (minOut * (10000 - minSlippageBps)) / 10000;
            amounts[i] = IUniswapV3Router(uniswapV3Router).exactInputSingle(
                IUniswapV3Router.ExactInputSingleParams({
                    tokenIn: address(inputToken),
                    tokenOut: address(poolTokens[i]),
                    fee: UNISWAP_FEE,
                    recipient: address(this),
                    amountIn: swapAmount,
                    amountOutMinimum: minOut,
                    sqrtPriceLimitX96: 0
                })
            );
        }

        // Add liquidity to Curve
        uint256[4] memory curveAmounts; // Max 4 tokens
        for (uint256 i = 0; i < poolTokens.length; i++) {
            curveAmounts[i] = amounts[i];
        }
        uint256 lpAmount = ICurvePool(curvePool).add_liquidity(curveAmounts, 0);

        // Deposit LP tokens to Convex
        IConvexBooster(convexBooster).deposit(poolId, lpAmount, true);
        return lpAmount;
    }

    function _withdrawFromProtocol(uint256 amount) internal override returns (uint256 inputTokenAmount, uint256 flaxValue) {
        // Withdraw from Convex
        IConvexBooster(convexBooster).withdraw(poolId, amount);

        // Remove liquidity from Curve (get inputToken, e.g., USDC)
        inputTokenAmount = ICurvePool(curvePool).remove_liquidity_one_coin(amount, 0, 0);

        // Claim rewards during withdrawal
        flaxValue = _claimAndSellRewards();
    }

    function _claimRewardToken(address /* token */) internal override returns (uint256) {
        // Claim rewards from Convex
        IConvexRewardPool(convexRewardPool).getReward();
        // Sum reward token balances
        uint256 total;
        for (uint256 i = 0; i < rewardTokens.length; i++) {
            total += IERC20(rewardTokens[i]).balanceOf(address(this));
        }
        return total;
    }

    function _sellRewardToken(address token, uint256 amount) internal override returns (uint256 ethAmount) {
        uint256 minEthOut = oracle.consult(token, address(0), amount);
        minEthOut = (minEthOut * (10000 - minSlippageBps)) / 10000;

        IERC20(token).approve(uniswapV3Router, amount);
        ethAmount = IUniswapV3Router(uniswapV3Router).exactInputSingle(
            IUniswapV3Router.ExactInputSingleParams({
                tokenIn: token,
                tokenOut: address(0), // ETH
                fee: UNISWAP_FEE,
                recipient: address(this),
                amountIn: amount,
                amountOutMinimum: minEthOut,
                sqrtPriceLimitX96: 0
            })
        );
    }

    function _sellEthForInputToken(uint256 ethAmount) internal override returns (uint256 inputTokenAmount) {
        uint256 minInputOut = oracle.consult(address(0), address(inputToken), ethAmount);
        minInputOut = (minInputOut * (10000 - minSlippageBps)) / 10000;

        inputTokenAmount = IUniswapV3Router(uniswapV3Router).exactInputSingle(
            IUniswapV3Router.ExactInputSingleParams({
                tokenIn: address(0), // ETH
                tokenOut: address(inputToken),
                fee: UNISWAP_FEE,
                recipient: address(this),
                amountIn: ethAmount,
                amountOutMinimum: minInputOut,
                sqrtPriceLimitX96: 0
            })
        );
    }

    function _getFlaxValue(uint256 ethAmount) internal override returns (uint256 flaxAmount) {
        (bool success, bytes memory data) = address(priceTilter).call{value: ethAmount}(
            abi.encodeWithSignature("tiltPrice(address,uint256)", address(flaxToken), ethAmount)
        );
        require(success, "Price tilt failed");
        flaxAmount = abi.decode(data, (uint256));
    }

    function _claimAndSellRewards() private returns (uint256 flaxValue) {
        uint256 ethAmount;
        for (uint256 i = 0; i < rewardTokens.length; i++) {
            address token = rewardTokens[i];
            uint256 amount = _claimRewardToken(token);
            if (amount > 0) {
                emit RewardClaimed(token, amount);
                ethAmount += _sellRewardToken(token, amount);
                emit RewardSold(token, amount, ethAmount);
            }
        }
        if (ethAmount > 0) {
            flaxValue = _getFlaxValue(ethAmount);
            emit FlaxValueCalculated(ethAmount, flaxValue);
        }
    }

    receive() external payable {}
}