// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "@oz_reflax/contracts/access/Ownable.sol";
import {IERC20} from "@oz_reflax/contracts/token/ERC20/IERC20.sol";
import {TWAPOracle, IUniswapV2Pair} from "./TWAPOracle.sol";
import "../external/UniswapV2.sol";

contract PriceTilter is Ownable {
    IUniswapV2Factory public factory;
    IUniswapV2Router02 public router;
    IERC20 public flaxToken;
    TWAPOracle public twapOracle;

    mapping(address => bool) public isPairRegistered;

    event PairRegistered(address indexed tokenA, address indexed tokenB, address pair);

    constructor(address _factory, address _router, address _flaxToken, address _twapOracle) Ownable(msg.sender) {
        require(_factory != address(0), "Invalid factory address");
        require(_router != address(0), "Invalid router address");
        require(_flaxToken != address(0), "Invalid Flax token address");
        require(_twapOracle != address(0), "Invalid TWAP oracle address");
        factory = IUniswapV2Factory(_factory);
        router = IUniswapV2Router02(_router);
        flaxToken = IERC20(_flaxToken);
        twapOracle = TWAPOracle(_twapOracle);
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
        twapOracle.initializePair(pair);

        emit PairRegistered(tokenA, tokenB, pair);
    }

    /**
     * @notice Retrieves the TWAP-based price of tokenA in terms of tokenB.
     * @dev May update TWAP oracle state.
     * @param tokenA The first token in the pair.
     * @param tokenB The second token in the pair.
     * @return The TWAP price as a uint256.
     */
    function getPrice(address tokenA, address tokenB) external returns (uint256) {
        address pair = factory.getPair(tokenA, tokenB);
        require(isPairRegistered[pair], "Pair not registered");

        twapOracle.updateTWAP(pair);

        address token0 = IUniswapV2Pair(pair).token0();
        if (token0 == tokenA) {
            return twapOracle.getPrice0(pair);
        } else {
            return twapOracle.getPrice1(pair);
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

   }