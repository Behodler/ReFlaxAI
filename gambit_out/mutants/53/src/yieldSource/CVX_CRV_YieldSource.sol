// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "interfaces/IUniswapV3Router.sol";
import {AYieldSource} from "./AYieldSource.sol";
import {IERC20} from "@oz_reflax/token/ERC20/IERC20.sol";
import {SafeERC20} from "@oz_reflax/token/ERC20/utils/SafeERC20.sol";

/**
 * @title ICurvePool
 * @notice Interface for interacting with Curve pools
 */
interface ICurvePool {
    /**
     * @notice Removes liquidity in a single token
     * @param token_amount Amount of LP tokens to burn
     * @param i Index of the token to receive
     * @param min_amount Minimum amount of token to receive
     * @return Amount of token received
     */
    function remove_liquidity_one_coin(uint256 token_amount, int128 i, uint256 min_amount) external returns (uint256);
    
    /**
     * @notice Gets the address of a pool token by index
     * @param i Index of the token
     * @return Address of the token
     */
    function coins(uint256 i) external view returns (address);
}

/**
 * @title IConvexBooster
 * @notice Interface for Convex booster contract
 */
interface IConvexBooster {
    /**
     * @notice Deposits LP tokens into Convex
     * @param pid Pool ID
     * @param amount Amount of LP tokens to deposit
     * @param stake Whether to stake tokens
     * @return Success status
     */
    function deposit(uint256 pid, uint256 amount, bool stake) external returns (bool);
    
    /**
     * @notice Withdraws LP tokens from Convex
     * @param pid Pool ID
     * @param amount Amount of LP tokens to withdraw
     * @return Success status
     */
    function withdraw(uint256 pid, uint256 amount) external returns (bool);
}

/**
 * @title IConvexRewardPool
 * @notice Interface for Convex reward pool
 */
interface IConvexRewardPool {
    /**
     * @notice Claims all available rewards
     * @return Success status
     */
    function getReward() external returns (bool);
}

/**
 * @title CVX_CRV_YieldSource
 * @author Justin Goro
 * @notice Concrete yield source implementation for Convex/Curve strategies
 * @dev Deposits input tokens into Curve pools and stakes LP tokens in Convex for enhanced rewards
 */
contract CVX_CRV_YieldSource is AYieldSource {
    using SafeERC20 for IERC20;

    /// @notice Array of tokens in the Curve pool (e.g., USDC, USDT, DAI)
    IERC20[] public poolTokens;
    
    /// @notice Symbols of pool tokens for identification
    string[] public poolTokenSymbols;
    
    /// @notice Number of tokens in the Curve pool (2, 3, or 4)
    uint256 public immutable numPoolTokens;
    
    /// @notice Mapping from pool address to allocation weights for each token
    /// @dev Weights are in basis points (10000 = 100%)
    mapping(address => uint256[]) public underlyingWeights;
    
    /// @notice Address of the Curve pool contract
    address public immutable curvePool;
    
    /// @notice Curve LP token received after adding liquidity
    IERC20 public immutable crvLpToken;
    
    /// @notice Convex booster contract for depositing LP tokens
    address public immutable convexBooster;
    
    /// @notice Convex reward pool contract for claiming rewards
    address public immutable convexRewardPool;
    
    /// @notice ID of the Convex pool
    uint256 public immutable poolId;
    
    /// @notice Uniswap V3 router for token swaps
    address public immutable uniswapV3Router;
    
    /// @notice Default Uniswap V3 fee tier (0.3%)
    uint24 public constant UNISWAP_FEE = 3000;

    /**
     * @notice Emitted when pool token allocation weights are updated
     * @param pool Address of the Curve pool
     * @param weights New allocation weights in basis points
     */
    event UnderlyingWeightsUpdated(address indexed pool, uint256[] weights);

    /**
     * @notice Initializes the CVX/CRV yield source with all necessary contracts and parameters
     * @param _inputToken Address of the input token (e.g., USDC)
     * @param _flaxToken Address of the Flax token
     * @param _priceTilter Address of the price tilter contract
     * @param _oracle Address of the TWAP oracle contract
     * @param _lpTokenName Human-readable name for the LP token
     * @param _curvePool Address of the Curve pool
     * @param _crvLpToken Address of the Curve LP token
     * @param _convexBooster Address of the Convex booster contract
     * @param _convexRewardPool Address of the Convex reward pool
     * @param _poolId ID of the Convex pool
     * @param _uniswapV3Router Address of Uniswap V3 router
     * @param _poolTokens Array of pool token addresses (2-4 tokens)
     * @param _poolTokenSymbols Array of pool token symbols
     * @param _rewardTokens Array of reward token addresses
     */
    constructor(
        address _inputToken,
        address _flaxToken,
        address _priceTilter,
        address _oracle,
        string memory _lpTokenName,
        address _curvePool,
        address _crvLpToken,
        address _convexBooster,
        address _convexRewardPool,
        uint256 _poolId,
        address _uniswapV3Router,
        address[] memory _poolTokens,
        string[] memory _poolTokenSymbols,
        address[] memory _rewardTokens
    ) AYieldSource(_inputToken, _flaxToken, _priceTilter, _oracle, _lpTokenName) {
        require(_poolTokens.length >= 2 && _poolTokens.length <= 4, "Invalid pool token count");
        require(_poolTokens.length == _poolTokenSymbols.length, "Mismatched symbols");

        curvePool = _curvePool;
        crvLpToken = IERC20(_crvLpToken);
        convexBooster = _convexBooster;
        convexRewardPool = _convexRewardPool;
        poolId = _poolId;
        uniswapV3Router = _uniswapV3Router;
        numPoolTokens = _poolTokens.length;

        // Initialize pool tokens and symbols
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

    /**
     * @notice Sets the allocation weights for pool tokens
     * @param pool Address of the Curve pool (must match curvePool)
     * @param weights Array of weights in basis points (must sum to 10000)
     * @dev Only callable by owner
     */
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

    /**
     * @notice Updates TWAP oracle prices for all relevant token pairs
     * @dev Updates Flax/ETH, input token/ETH, pool tokens/ETH, and reward tokens/ETH pairs
     * @dev address(0) represents ETH in oracle calls
     */
    function _updateOracle() internal override {
        // Update oracle for Flax and ETH pair
        oracle.update(address(flaxToken), address(0)); // address(0) is used as WETH proxy for oracle
        
        // Update oracle for input token and ETH pair if needed
        if (address(inputToken) != address(0)) {
            oracle.update(address(inputToken), address(0));
        }
        
        // Update oracles for pool tokens
        for (uint256 i = 0; i < poolTokens.length; i++) {
            if (address(poolTokens[i]) != address(inputToken) && address(poolTokens[i]) != address(0)) {
                oracle.update(address(poolTokens[i]), address(0));
            }
        }
        
        // Update oracles for reward tokens
        for (uint256 i = 0; i < rewardTokens.length; i++) {
            if (rewardTokens[i] != address(0) && rewardTokens[i] != address(flaxToken)) {
                /// DeleteExpressionMutation(`oracle.update(rewardTokens[i], address(0))` |==> `assert(true)`) of: `oracle.update(rewardTokens[i], address(0));`
                assert(true);
            }
        }
    }

    /**
     * @notice Deposits input tokens into Curve pool and stakes LP tokens in Convex
     * @param amount Amount of input tokens to deposit
     * @return lpAmount Amount of LP tokens received and staked
     * @dev Swaps input token to pool tokens based on weights, adds liquidity to Curve, stakes in Convex
     */
    function _depositToProtocol(uint256 amount) internal override returns (uint256) {
        // Update TWAP oracle before deposit - REMOVED (handled by AYieldSource.deposit)
        
        // Allocate inputToken based on weights
        uint256[] memory weights = underlyingWeights[curvePool];
        if (weights.length == 0) {
            weights = new uint256[](poolTokens.length);
            for (uint256 i = 0; i < poolTokens.length; i++) {
                weights[i] = 10000 / poolTokens.length;
            }
        }

        uint256[] memory amounts = new uint256[](poolTokens.length);
        
        // Handle each pool token
        for (uint256 i = 0; i < poolTokens.length; i++) {
            uint256 allocatedAmount = (amount * weights[i]) / 10000;
            
            // If this pool token is the same as input token, no swap needed
            if (address(poolTokens[i]) == address(inputToken)) {
                amounts[i] = allocatedAmount;
            } else if (allocatedAmount > 0) {
                // Need to swap inputToken to this pool token (only if amount > 0)
                uint256 minOut = oracle.consult(address(inputToken), address(poolTokens[i]), allocatedAmount);
                minOut = (minOut * (10000 - minSlippageBps)) / 10000;
                amounts[i] = IUniswapV3Router(uniswapV3Router).exactInputSingle(
                    IUniswapV3Router.ExactInputSingleParams({
                        tokenIn: address(inputToken),
                        tokenOut: address(poolTokens[i]),
                        fee: UNISWAP_FEE,
                        recipient: address(this),
                        amountIn: allocatedAmount,
                        amountOutMinimum: minOut,
                        sqrtPriceLimitX96: 0
                    })
                );
            } else {
                // Zero allocated amount, skip swap
                amounts[i] = 0;
            }
        }

        // Add liquidity to Curve
        uint256 lpAmount = _addLiquidityToCurve(amounts);

        // Deposit LP tokens to Convex
        IConvexBooster(convexBooster).deposit(poolId, lpAmount, true);
        
        // Update TWAP oracle after deposit - REMOVED
        
        return lpAmount;
    }

    /**
     * @notice Withdraws from Convex and Curve, converting back to input token
     * @param amount Amount of LP tokens to withdraw
     * @return inputTokenAmount Amount of input tokens received
     * @return flaxValue Value of claimed rewards in Flax tokens
     * @dev Unstakes from Convex, removes liquidity from Curve, and claims rewards
     */
    function _withdrawFromProtocol(uint256 amount) internal override returns (uint256 inputTokenAmount, uint256 flaxValue) {
        // Update TWAP oracle before withdrawal - REMOVED (handled by AYieldSource.withdraw)
        
        // The amount parameter represents input token amount (e.g., USDC) that the user wants to withdraw
        // We need to convert this to the equivalent LP token amount to withdraw from Convex
        
        // Calculate LP amount to withdraw based on proportion of input tokens
        // This is an approximation - in a real system, you'd want more sophisticated calculation
        uint256 lpAmountToWithdraw;
        if (totalDeposited > 0) {
            // Calculate proportional LP amount based on input token amount requested
            // Assume roughly 1:1 ratio for this mock (should use actual pool math in production)
            lpAmountToWithdraw = amount * 1e12; // Convert USDC (6 decimals) to LP equivalent (18 decimals)
            
            // Ensure we don't withdraw more than what we have
            if (lpAmountToWithdraw > totalDeposited) {
                lpAmountToWithdraw = totalDeposited;
            }
        } else {
            lpAmountToWithdraw = 0;
        }
        
        if (lpAmountToWithdraw > 0) {
            // Withdraw LP tokens from Convex
            IConvexBooster(convexBooster).withdraw(poolId, lpAmountToWithdraw);

            // Find the index of input token in the pool
            uint256 inputTokenIndex = type(uint256).max;
            for (uint256 i = 0; i < poolTokens.length; i++) {
                if (address(poolTokens[i]) == address(inputToken)) {
                    inputTokenIndex = i;
                    break;
                }
            }
            
            // If input token is one of the pool tokens, remove liquidity to that token
            if (inputTokenIndex != type(uint256).max) {
                inputTokenAmount = ICurvePool(curvePool).remove_liquidity_one_coin(lpAmountToWithdraw, int128(int256(inputTokenIndex)), 0);
            } else {
                // Input token is not in the pool, need to remove liquidity and swap
                // For simplicity, remove to the first token and swap
                uint256 token0Amount = ICurvePool(curvePool).remove_liquidity_one_coin(lpAmountToWithdraw, 0, 0);
                
                if (token0Amount > 0) {
                    // Swap pool token to input token
                    uint256 minOut = oracle.consult(address(poolTokens[0]), address(inputToken), token0Amount);
                    minOut = (minOut * (10000 - minSlippageBps)) / 10000;
                    
                    poolTokens[0].approve(uniswapV3Router, token0Amount);
                    inputTokenAmount = IUniswapV3Router(uniswapV3Router).exactInputSingle(
                        IUniswapV3Router.ExactInputSingleParams({
                            tokenIn: address(poolTokens[0]),
                            tokenOut: address(inputToken),
                            fee: UNISWAP_FEE,
                            recipient: address(this),
                            amountIn: token0Amount,
                            amountOutMinimum: minOut,
                            sqrtPriceLimitX96: 0
                        })
                    );
                } else {
                    inputTokenAmount = 0;
                }
            }
        }

        // Claim rewards during withdrawal
        flaxValue = _claimAndSellRewards();
        
        // Update TWAP oracle after withdrawal - REMOVED
    }

    /**
     * @notice Claims a specific reward token from Convex
     * @param token Address of the reward token to claim
     * @return Amount of reward tokens claimed
     * @dev Claims all rewards when first token is requested, then returns balance
     */
    function _claimRewardToken(address token) internal override returns (uint256) {
        // Update TWAP oracle before claiming rewards - REMOVED (handled by AYieldSource.claimRewards)
        
        // Check if this is the first reward token being claimed
        // If so, claim all rewards from Convex
        if (token == rewardTokens[0]) {
            IConvexRewardPool(convexRewardPool).getReward();
        }
        // Return balance of specific reward token
        return IERC20(token).balanceOf(address(this));
    }

    /**
     * @notice Sells reward tokens for ETH via Uniswap V3
     * @param token Address of the reward token to sell
     * @param amount Amount of tokens to sell
     * @return ethAmount Amount of ETH received
     * @dev Uses TWAP oracle for slippage protection
     */
    function _sellRewardToken(address token, uint256 amount) internal override returns (uint256 ethAmount) {
        if (amount == 0) return 0;
        
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

    /**
     * @notice Sells ETH for input tokens via Uniswap V3
     * @param ethAmount Amount of ETH to sell
     * @return inputTokenAmount Amount of input tokens received
     * @dev Uses TWAP oracle for slippage protection
     * @dev IMPORTANT: Must send ETH value with the swap call when tokenIn is ETH (address(0))
     */
    function _sellEthForInputToken(uint256 ethAmount) internal override returns (uint256 inputTokenAmount) {
        if (ethAmount == 0) return 0;
        
        uint256 minInputOut = oracle.consult(address(0), address(inputToken), ethAmount);
        minInputOut = (minInputOut * (10000 - minSlippageBps)) / 10000;

        inputTokenAmount = IUniswapV3Router(uniswapV3Router).exactInputSingle{value: ethAmount}(
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

    /**
     * @notice Calculates Flax value of ETH using the price tilter
     * @param ethAmount Amount of ETH to value
     * @return flaxAmount Calculated value in Flax tokens
     * @dev Sends ETH to price tilter which adds liquidity and returns Flax value
     */
    function _getFlaxValue(uint256 ethAmount) internal override returns (uint256 flaxAmount) {
        (bool success, bytes memory data) = address(priceTilter).call{value: ethAmount}(
            abi.encodeWithSignature("tiltPrice(address,uint256)", address(flaxToken), ethAmount)
        );
        require(success, "Price tilt failed");
        flaxAmount = abi.decode(data, (uint256));
    }

    /**
     * @notice Claims all rewards and sells them for ETH, then calculates Flax value
     * @return flaxValue Total value of rewards in Flax tokens
     * @dev Internal helper function used during withdrawals
     */
    function _claimAndSellRewards() private returns (uint256 flaxValue) {
        // Update TWAP oracle before claiming rewards - REMOVED (handled by AYieldSource.withdraw or AYieldSource.claimRewards)
        
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
        
        // Update TWAP oracle after selling rewards - REMOVED
    }

    /**
     * @notice Helper function to add liquidity to Curve pools with variable token counts
     * @param amounts Array of token amounts to add
     * @return lpAmount Amount of LP tokens received
     * @dev Uses low-level calls to handle 2, 3, or 4 token pools
     */
    function _addLiquidityToCurve(uint256[] memory amounts) private returns (uint256 lpAmount) {
        bytes memory data;
        
        if (numPoolTokens == 2) {
            uint256[2] memory amounts2;
            amounts2[0] = amounts[0];
            amounts2[1] = amounts[1];
            data = abi.encodeWithSignature("add_liquidity(uint256[2],uint256)", amounts2, 0);
        } else if (numPoolTokens == 3) {
            uint256[3] memory amounts3;
            amounts3[0] = amounts[0];
            amounts3[1] = amounts[1];
            amounts3[2] = amounts[2];
            data = abi.encodeWithSignature("add_liquidity(uint256[3],uint256)", amounts3, 0);
        } else if (numPoolTokens == 4) {
            uint256[4] memory amounts4;
            amounts4[0] = amounts[0];
            amounts4[1] = amounts[1];
            amounts4[2] = amounts[2];
            amounts4[3] = amounts[3];
            data = abi.encodeWithSignature("add_liquidity(uint256[4],uint256)", amounts4, 0);
        } else {
            revert("Unsupported pool size");
        }
        
        (bool success, bytes memory result) = curvePool.call(data);
        require(success, "add_liquidity failed");
        lpAmount = abi.decode(result, (uint256));
    }

    /**
     * @notice Allows the contract to receive ETH
     */
    receive() external payable {}
    
    /**
     * @notice Emergency function to withdraw ETH or ERC20 tokens
     * @param token Address of the token to withdraw (address(0) for ETH)
     * @param recipient Address to receive the tokens
     * @dev Only callable by owner for emergency recovery
     */
    function emergencyWithdraw(address token, address recipient) external onlyOwner {
        if (token == address(0)) {
            // Withdraw ETH
            uint256 balance = address(this).balance;
            if (balance > 0) {
                payable(recipient).transfer(balance);
            }
        } else {
            // Withdraw ERC20 token
            IERC20 erc20 = IERC20(token);
            uint256 balance = erc20.balanceOf(address(this));
            if (balance > 0) {
                erc20.safeTransfer(recipient, balance);
            }
        }
    }
}