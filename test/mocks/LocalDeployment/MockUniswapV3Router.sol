// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IERC20} from "@oz_reflax/token/ERC20/IERC20.sol";
import "interfaces/IUniswapV3Router.sol";

contract MockUniswapV3Router is IUniswapV3Router {
    struct TokenPair {
        address tokenIn;
        address tokenOut;
        uint256 price; // Price in 1e18 format (tokenOut per tokenIn)
        uint256 liquidity; // Available liquidity
        uint256 baseSlippageBps; // Base slippage in basis points
    }

    mapping(bytes32 => TokenPair) public tokenPairs;
    mapping(address => uint256) public tokenPrices; // USD prices in 1e6 format
    uint256 public globalSlippageBps = 30; // Default 0.3% slippage
    uint256 public constant MAX_SLIPPAGE = 500; // 5% max slippage
    uint256 public constant LIQUIDITY_IMPACT_THRESHOLD = 1e18; // $1000 threshold

    event SwapExecuted(
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        uint256 slippageApplied,
        address recipient
    );

    constructor() {
        // Initialize with realistic token prices (USD in 1e6 format)
        tokenPrices[address(0)] = 2000 * 1e6; // ETH: $2000
        // Other tokens will be set by deployment script
    }

    function setTokenPrice(address token, uint256 priceUSD) external {
        tokenPrices[token] = priceUSD;
    }

    function setPair(
        address tokenIn,
        address tokenOut,
        uint256 price,
        uint256 liquidity,
        uint256 baseSlippageBps
    ) external {
        bytes32 key = keccak256(abi.encodePacked(tokenIn, tokenOut));
        tokenPairs[key] = TokenPair({
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            price: price,
            liquidity: liquidity,
            baseSlippageBps: baseSlippageBps
        });
        
        // Set reverse pair
        bytes32 reverseKey = keccak256(abi.encodePacked(tokenOut, tokenIn));
        tokenPairs[reverseKey] = TokenPair({
            tokenIn: tokenOut,
            tokenOut: tokenIn,
            price: 1e36 / price, // Inverse price
            liquidity: liquidity,
            baseSlippageBps: baseSlippageBps
        });
    }

    function setGlobalSlippage(uint256 slippageBps) external {
        require(slippageBps <= MAX_SLIPPAGE, "Slippage too high");
        globalSlippageBps = slippageBps;
    }

    function exactInputSingle(ExactInputSingleParams calldata params) 
        external 
        payable 
        override 
        returns (uint256 amountOut) 
    {
        require(params.amountIn > 0, "Amount must be positive");
        
        // Handle ETH input
        if (params.tokenIn == address(0)) {
            require(msg.value >= params.amountIn, "Insufficient ETH sent");
        } else {
            IERC20(params.tokenIn).transferFrom(msg.sender, address(this), params.amountIn);
        }

        // Calculate output amount with realistic price impact
        amountOut = _calculateOutputAmount(params.tokenIn, params.tokenOut, params.amountIn);
        
        // Apply slippage
        uint256 appliedSlippage = _calculateSlippage(params.tokenIn, params.tokenOut, params.amountIn);
        amountOut = (amountOut * (10000 - appliedSlippage)) / 10000;
        
        // Check minimum output
        require(amountOut >= params.amountOutMinimum, "Insufficient output amount");
        
        // Transfer output tokens
        if (params.tokenOut == address(0)) {
            // Output is ETH
            payable(params.recipient).transfer(amountOut);
        } else {
            // Ensure we have enough tokens to send
            uint256 balance = IERC20(params.tokenOut).balanceOf(address(this));
            if (balance < amountOut) {
                // Mint tokens if we don't have enough (for testing)
                _mintTokens(params.tokenOut, amountOut - balance);
            }
            IERC20(params.tokenOut).transfer(params.recipient, amountOut);
        }
        
        emit SwapExecuted(
            params.tokenIn,
            params.tokenOut,
            params.amountIn,
            amountOut,
            appliedSlippage,
            params.recipient
        );
    }

    function _calculateOutputAmount(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) internal view returns (uint256) {
        bytes32 key = keccak256(abi.encodePacked(tokenIn, tokenOut));
        TokenPair memory pair = tokenPairs[key];
        
        if (pair.price > 0) {
            // Use configured pair price
            return (amountIn * pair.price) / 1e18;
        }
        
        // Fallback to USD price calculation
        uint256 priceIn = tokenPrices[tokenIn];
        uint256 priceOut = tokenPrices[tokenOut];
        
        if (priceIn > 0 && priceOut > 0) {
            // Convert amountIn to USD, then to tokenOut
            uint256 usdValue = (amountIn * priceIn) / 1e18; // Assuming 18 decimals
            return (usdValue * 1e18) / priceOut;
        }
        
        // Default 1:1 ratio if no price data
        return amountIn;
    }

    function _calculateSlippage(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) internal view returns (uint256) {
        bytes32 key = keccak256(abi.encodePacked(tokenIn, tokenOut));
        TokenPair memory pair = tokenPairs[key];
        
        uint256 baseSlippage = pair.baseSlippageBps > 0 ? pair.baseSlippageBps : globalSlippageBps;
        
        // Calculate price impact based on trade size vs liquidity
        if (pair.liquidity > 0) {
            uint256 tradeUsdValue = (amountIn * tokenPrices[tokenIn]) / 1e18;
            if (tradeUsdValue > LIQUIDITY_IMPACT_THRESHOLD) {
                // Additional slippage for large trades
                uint256 impactMultiplier = (tradeUsdValue * 100) / pair.liquidity;
                uint256 additionalSlippage = (baseSlippage * impactMultiplier) / 100;
                baseSlippage += additionalSlippage;
                
                // Cap at maximum slippage
                if (baseSlippage > MAX_SLIPPAGE) {
                    baseSlippage = MAX_SLIPPAGE;
                }
            }
        }
        
        return baseSlippage;
    }

    function _mintTokens(address token, uint256 amount) internal {
        // This is a mock function to mint tokens for testing
        // In a real router, this would not exist
        (bool success, ) = token.call(
            abi.encodeWithSignature("mint(address,uint256)", address(this), amount)
        );
        require(success, "Failed to mint tokens");
    }

    // View functions for testing
    function getOutputAmount(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) external view returns (uint256 amountOut, uint256 slippage) {
        amountOut = _calculateOutputAmount(tokenIn, tokenOut, amountIn);
        slippage = _calculateSlippage(tokenIn, tokenOut, amountIn);
        amountOut = (amountOut * (10000 - slippage)) / 10000;
    }

    function getPairInfo(address tokenIn, address tokenOut) 
        external 
        view 
        returns (TokenPair memory) 
    {
        bytes32 key = keccak256(abi.encodePacked(tokenIn, tokenOut));
        return tokenPairs[key];
    }

    // Allow receiving ETH
    receive() external payable {}
    fallback() external payable {}
}