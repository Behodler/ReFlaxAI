// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@oz_reflax/contracts/access/Ownable.sol";
import "@oz_reflax/contracts/token/ERC20/IERC20.sol";
import "../priceTilting/IOracle.sol";

import {IUniswapV2Router02} from "@uniswap_reflax/periphery/interfaces/IUniswapV2Router02.sol";
import {IUniswapV2Factory} from "@uniswap_reflax/core/interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Pair} from "@uniswap_reflax/core/interfaces/IUniswapV2Pair.sol";

contract PriceTilter is Ownable {
    IUniswapV2Factory public factory;
    IUniswapV2Router02 public router;
    IERC20 public flaxToken;
    IOracle public oracle;

    mapping(address => bool) public isPairRegistered;

    event PairRegistered(address indexed tokenA, address indexed tokenB, address pair);

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
    }

    /**
     * @notice Registers a Uniswap V2 pair for TWAP calculations.
     * @dev Only callable by the owner.
     * @param tokenA The first token in the pair.
     * @param tokenB The second token in the pair.
     */
    function registerPair(address tokenA, address tokenB) external onlyOwner {
        require(tokenA != address(0) && tokenB != address(0), "Invalid token address");
        require(tokenA != tokenB, "Tokens must be different");
        address pair = factory.getPair(tokenA, tokenB);
        require(pair != address(0), "Pair does not exist");
        require(!isPairRegistered[pair], "Pair already registered");

        isPairRegistered[pair] = true;
        oracle.update(tokenA, tokenB); // Initialize pair in TWAPOracle

        emit PairRegistered(tokenA, tokenB, pair);
    }

    /**
     * @notice Retrieves the TWAP-based price of tokenA in terms of tokenB.
     * @dev Updates TWAP oracle state and returns price for 1e18 tokenA.
     * @param tokenA The first token in the pair.
     * @param tokenB The second token in the pair.
     * @return The TWAP price as a uint256.
     */
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

    /**
     * @notice Adds liquidity to a Uniswap V2 pair to influence price tilting.
     * @param tokenA The first token in the pair.
     * @param tokenB The second token in the pair.
     * @param amountA The amount of tokenA to add.
     * @param amountB The amount of tokenB to add.
     */
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountA,
        uint256 amountB
    ) external {
        address pair = factory.getPair(tokenA, tokenB);
        require(isPairRegistered[pair], "Pair not registered");

        IERC20(tokenA).transferFrom(msg.sender, address(this), amountA);
        IERC20(tokenB).transferFrom(msg.sender, address(this), amountB);

        IERC20(tokenA).approve(address(router), amountA);
        IERC20(tokenB).approve(address(router), amountB);

        router.addLiquidity(
            tokenA,
            tokenB,
            amountA,
            amountB,
            0,
            0,
            address(this),
            block.timestamp + 300
        );
    }

    /**
     * @notice Tilts the price by returning Flax value for ETH amount.
     * @param token The token to tilt (expected to be flaxToken).
     * @param ethAmount The amount of ETH received.
     * @return The Flax value based on TWAP price.
     */
    function tiltPrice(address token, uint256 ethAmount) external payable returns (uint256) {
        require(token == address(flaxToken), "Invalid token");
        require(msg.value == ethAmount, "ETH amount mismatch");

        address pair = factory.getPair(address(flaxToken), router.WETH());
        require(isPairRegistered[pair], "Flax-WETH pair not registered");

        oracle.update(address(flaxToken), router.WETH());

        // Get TWAP price of Flax in ETH (amount of ETH for 1e18 Flax)
        uint256 ethPerFlax = oracle.consult(address(flaxToken), router.WETH(), 1e18);
        require(ethPerFlax > 0, "Invalid TWAP price");

        // Calculate Flax value: ethAmount / ethPerFlax * 1e18
        uint256 flaxValue = (ethAmount * 1e18) / ethPerFlax;

        return flaxValue;
    }
}