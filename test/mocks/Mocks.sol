// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@oz_reflax/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@oz_reflax/contracts/token/ERC20/utils/SafeERC20.sol";

// Mock ERC20 token for testing
contract MockERC20 is IERC20 {
    using SafeERC20 for IERC20;

    string public name = "Mock Token";
    string public symbol = "MOCK";
    uint8 public decimals = 18;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function mint(address to, uint256 amount) external {
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        require(allowance[from][msg.sender] >= amount, "Insufficient allowance");
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
        return true;
    }
}

// Mock YieldSource for Vault.t.sol
contract MockYieldSource {
    using SafeERC20 for IERC20;

    IERC20 public inputToken;
    uint256 public totalDeposited;
    uint256 private _withdrawInputAmount;
    uint256 private _flaxValue;

    constructor(address _inputToken) {
        inputToken = IERC20(_inputToken);
    }

    function deposit(uint256 amount) external returns (uint256) {
        inputToken.safeTransferFrom(msg.sender, address(this), amount);
        totalDeposited += amount;
        return amount;
    }

    function withdraw(uint256 amount) external returns (uint256 inputTokenAmount, uint256 flaxValue) {
        require(totalDeposited >= amount, "Insufficient deposited amount");
        totalDeposited -= amount;
        inputTokenAmount = _withdrawInputAmount;
        flaxValue = _flaxValue;
        inputToken.safeTransfer(msg.sender, inputTokenAmount);
    }

    function claimRewards() external returns (uint256) {
        return _flaxValue;
    }

    function claimAndSellForInputToken() external returns (uint256 inputTokenAmount) {
        return 0; // Not used in Vault.t.sol tests
    }

    function setReturnValues(uint256 inputTokenAmount, uint256 flaxValue) external {
        _withdrawInputAmount = inputTokenAmount;
        _flaxValue = flaxValue;
    }
}

// Mock Uniswap V3 Router
contract MockUniswapV3Router {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    function exactInputSingle(ExactInputSingleParams calldata params) external returns (uint256) {
        require(params.amountIn >= params.amountOutMinimum, "Insufficient output");
        IERC20(params.tokenIn).transferFrom(msg.sender, address(this), params.amountIn);
        IERC20(params.tokenOut).transfer(params.recipient, params.amountIn);
        return params.amountIn;
    }
}

// Mock Curve Pool
contract MockCurvePool {
    address public lpToken;

    constructor(address _lpToken) {
        lpToken = _lpToken;
    }

    function coins(uint256) external pure returns (address) {
        return address(0);
    }

    function balances(uint256) external pure returns (uint256) {
        return 0;
    }

    function add_liquidity(uint256[4] calldata amounts, uint256) external returns (uint256) {
        uint256 total;
        for (uint256 i = 0; i < amounts.length; i++) {
            total += amounts[i];
        }
        MockERC20(lpToken).mint(msg.sender, total);
        return total;
    }

    function remove_liquidity_one_coin(uint256 token_amount, int128, uint256) external returns (uint256) {
        MockERC20(lpToken).transferFrom(msg.sender, address(this), token_amount);
        return token_amount;
    }
}

// Mock Convex Booster
contract MockConvexBooster {
    function deposit(uint256, uint256 amount, bool) external returns (bool) {
        return true;
    }

    function withdraw(uint256, uint256) external returns (bool) {
        return true;
    }
}

// Mock Convex Reward Pool
contract MockConvexRewardPool {
    address public rewardToken;

    constructor(address _rewardToken) {
        rewardToken = _rewardToken;
    }

    function getReward() external returns (bool) {
        MockERC20(rewardToken).mint(msg.sender, 1000);
        return true;
    }
}

// Mock Uniswap V2 Pair
contract MockUniswapV2Pair {
    address public token0;
    address public token1;
    uint112 public reserve0;
    uint112 public reserve1;
    uint32 public blockTimestampLast;
    uint256 public price0CumulativeLast;
    uint256 public price1CumulativeLast;

    constructor(address _token0, address _token1) {
        token0 = _token0;
        token1 = _token1;
    }

    function getReserves() external view returns (uint112, uint112, uint32) {
        return (reserve0, reserve1, blockTimestampLast);
    }

    function updateReserves(uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast) external {
        reserve0 = _reserve0;
        reserve1 = _reserve1;
        blockTimestampLast = _blockTimestampLast;
        price0CumulativeLast += uint256(_reserve1) * 1e18 / _reserve0;
        price1CumulativeLast += uint256(_reserve0) * 1e18 / _reserve1;
    }
}

// Mock Uniswap V2 Factory
contract MockUniswapV2Factory {
    mapping(address => mapping(address => address)) public getPair;

    function setPair(address tokenA, address tokenB, address pair) external {
        getPair[tokenA][tokenB] = pair;
        getPair[tokenB][tokenA] = pair;
    }
}

// Mock PriceTilter
contract MockPriceTilter {
    function tiltPrice(address, uint256 amount) external pure returns (uint256) {
        return amount * 2000; // Mocked value from YieldSource.t.sol
    }
}