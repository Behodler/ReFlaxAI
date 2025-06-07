// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@oz_reflax/access/Ownable.sol";
import "@oz_reflax/token/ERC20/IERC20.sol";
import "../priceTilting/IOracle.sol";
import {IUniswapV2Router02} from "@uniswap_reflax/periphery/interfaces/IUniswapV2Router02.sol";
import {IUniswapV2Factory} from "@uniswap_reflax/core/interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Pair} from "@uniswap_reflax/core/interfaces/IUniswapV2Pair.sol";

contract PriceTilterTWAP is Ownable {
    IUniswapV2Factory public factory;
    IUniswapV2Router02 public router;
    IERC20 public flaxToken;
    IOracle public oracle;
    uint256 public priceTiltRatio; // In basis points (e.g., 8000 = 80%)

    mapping(address => bool) public isPairRegistered;

    event PairRegistered(address indexed tokenA, address indexed tokenB, address pair);
    event PriceTiltRatioUpdated(uint256 newRatio);
    event LiquidityAdded(address indexed pair, uint256 amountFlax, uint256 amountETH);

    constructor(
        address _factory,
        address _router,
        address _flaxToken,
        address _oracle
    ) Ownable(msg.sender) {
        require(_factory != address(0), "Invalid factory address");
        require(_router != address(0), "Invalid router address");
        require(_flaxToken != address(0), "Invalid Flax token address");
        require(_oracle != address(0), "Invalid oracle address");
        factory = IUniswapV2Factory(_factory);
        router = IUniswapV2Router02(_router);
        flaxToken = IERC20(_flaxToken);
        oracle = IOracle(_oracle);
        priceTiltRatio = 8000; // Default: 80%
    }

    function setPriceTiltRatio(uint256 newRatio) external onlyOwner {
        require(newRatio <= 10000, "Ratio exceeds 100%");
        priceTiltRatio = newRatio;
        emit PriceTiltRatioUpdated(newRatio);
    }

    function registerPair(address tokenA, address tokenB) external onlyOwner {
        require(tokenA != address(0) && tokenB != address(0), "Invalid token address");
        require(tokenA != tokenB, "Tokens must be different");
        address pair = factory.getPair(tokenA, tokenB);
        require(pair != address(0), "Pair does not exist");
        require(!isPairRegistered[pair], "Pair already registered");

        isPairRegistered[pair] = true;
        oracle.update(tokenA, tokenB);

        emit PairRegistered(tokenA, tokenB, pair);
    }

    function getPrice(address tokenA, address tokenB) external returns (uint256) {
        address pair = factory.getPair(tokenA, tokenB);
        require(isPairRegistered[pair], "Pair not registered");

        oracle.update(tokenA, tokenB);

        address token0 = IUniswapV2Pair(pair).token0();
        if (token0 == tokenA) {
            return oracle.consult(tokenA, tokenB, 1e18);
        } else {
            return oracle.consult(tokenA, tokenB, 1e18);
        }
    }

    function tiltPrice(address token, uint256 ethAmount) external payable returns (uint256) {
        require(token == address(flaxToken), "Invalid token");
        require(msg.value == ethAmount, "ETH amount mismatch");
        require(ethAmount > 0, "Zero ETH amount");

        address weth = router.WETH();
        address pair = factory.getPair(address(flaxToken), weth);
        require(isPairRegistered[pair], "Flax-WETH pair not registered");

        oracle.update(address(flaxToken), weth);

        // Get TWAP price: ETH per 1e18 Flax
        uint256 ethPerFlax = oracle.consult(address(flaxToken), weth, 1e18);
        require(ethPerFlax > 0, "Invalid TWAP price");

        // Calculate Flax value: ethAmount / ethPerFlax * 1e18
        uint256 flaxValue = (ethAmount * 1e18) / ethPerFlax;

        // Apply priceTiltRatio to reduce Flax amount for liquidity (e.g., 80% of flaxValue)
        uint256 flaxAmount = (flaxValue * priceTiltRatio) / 10000;
        require(flaxAmount > 0, "Zero Flax amount");

        // Ensure contract has enough Flax tokens
        require(flaxToken.balanceOf(address(this)) >= flaxAmount, "Insufficient Flax balance");

        // Approve Flax tokens for router
        flaxToken.approve(address(router), flaxAmount);

        // Use the entire ETH amount available in the contract
        uint256 totalEthAmount = ethAmount;
        if (address(this).balance > ethAmount) {
            totalEthAmount = address(this).balance;
        }

        // Add liquidity using addLiquidityETH
        (,, uint256 liquidity) = router.addLiquidityETH{value: totalEthAmount}(
            address(flaxToken), // Always Flax as the ERC20 token
            flaxAmount,
            0, // No minimum for simplicity
            0,
            address(this),
            block.timestamp + 300
        );

        require(liquidity > 0, "Liquidity addition failed");

        emit LiquidityAdded(pair, flaxAmount, totalEthAmount);

        return flaxValue;
    }
    
    // Emergency withdrawal function
    function emergencyWithdraw(address token, address recipient) external onlyOwner {
        if (token == address(0)) {
            // Withdraw ETH
            uint256 balance = address(this).balance;
            if (balance > 0) {
                payable(recipient).transfer(balance);
            }
        } else {
            // Withdraw ERC20 token
            IERC20 tokenToWithdraw = IERC20(token);
            uint256 balance = tokenToWithdraw.balanceOf(address(this));
            if (balance > 0) {
                tokenToWithdraw.transfer(recipient, balance);
            }
        }
    }

    receive() external payable {}
}