// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/yieldSource/AYieldSource.sol";
import "../src/yieldSource/CVX_CRV_YieldSource.sol";
import "../src/priceTilting/TWAPOracle.sol";
import "../src/priceTilting/IOracle.sol";
import {MockERC20, MockPriceTilter, MockUniswapV3Router,MockCurvePool,
MockConvexBooster,MockConvexRewardPool, MockUniswapV2Pair,MockUniswapV2Factory} from "./mocks/Mocks.sol";

contract YieldSourceTest is Test {
    CVX_CRV_YieldSource yieldSource;
    TWAPOracle twapOracle;
    MockERC20 inputToken;
    MockERC20 flaxToken;
    MockERC20 crvLpToken;
    MockERC20 rewardToken;
    MockPriceTilter priceTilter;
    MockUniswapV3Router uniswapRouter;
    MockCurvePool curvePool;
    MockConvexBooster convexBooster;
    MockConvexRewardPool convexRewardPool;
    MockUniswapV2Pair uniswapPair;
    MockUniswapV2Factory uniswapFactory;

    address vault = address(0x123);
    address[] poolTokens;
    string[] poolTokenSymbols;
    address[] rewardTokens;

    function setUp() public {
        inputToken = new MockERC20();
        flaxToken = new MockERC20();
        crvLpToken = new MockERC20();
        rewardToken = new MockERC20();
        priceTilter = new MockPriceTilter();
        uniswapRouter = new MockUniswapV3Router();
        curvePool = new MockCurvePool(address(crvLpToken));
        convexBooster = new MockConvexBooster();
        convexRewardPool = new MockConvexRewardPool(address(rewardToken));
        uniswapFactory = new MockUniswapV2Factory();
        uniswapPair = new MockUniswapV2Pair(address(inputToken), address(rewardToken));

        uniswapFactory.setPair(address(inputToken), address(rewardToken), address(uniswapPair));
        uniswapFactory.setPair(address(flaxToken), address(0x456), address(uniswapPair)); // Flax-WETH pair

        twapOracle = new TWAPOracle(address(uniswapFactory), address(0x456)); // Mock WETH
        vm.prank(twapOracle.owner());
        twapOracle.update(address(inputToken), address(rewardToken)); // Initialize pair
        vm.prank(twapOracle.owner());
        twapOracle.update(address(flaxToken), address(0x456)); // Flax-WETH pair

        poolTokens.push(address(inputToken));
        poolTokens.push(address(new MockERC20()));
        poolTokenSymbols.push("USDC");
        poolTokenSymbols.push("USDT");
        rewardTokens.push(address(rewardToken));

        yieldSource = new CVX_CRV_YieldSource(
            address(inputToken),
            address(flaxToken),
            address(priceTilter),
            address(twapOracle),
            "CRV triusd",
            address(curvePool),
            address(crvLpToken),
            address(convexBooster),
            address(convexRewardPool),
            123, // poolId
            address(uniswapRouter),
            poolTokens,
            poolTokenSymbols,
            rewardTokens
        );

        vm.prank(yieldSource.owner());
        yieldSource.whitelistVault(vault, true);

        // Mock TWAP update
        vm.warp(block.timestamp + 1 hours);
        uniswapPair.updateReserves(1000, 1000, 1 hours);
        vm.prank(twapOracle.owner());
        twapOracle.update(address(inputToken), address(rewardToken));
    }

    function testDeposit() public {
        uint256 amount = 1000;
        inputToken.mint(vault, amount);
        vm.prank(vault);
        inputToken.approve(address(yieldSource), amount);

        vm.prank(vault);
        uint256 received = yieldSource.deposit(amount);

        assertEq(received, amount);
        assertEq(yieldSource.totalDeposited(), amount);
    }

    function testWithdraw() public {
        uint256 amount = 1000;
        inputToken.mint(vault, amount);
        vm.prank(vault);
        inputToken.approve(address(yieldSource), amount);

        vm.prank(vault);
        yieldSource.deposit(amount);

        vm.prank(vault);
        (uint256 inputTokenAmount, uint256 flaxValue) = yieldSource.withdraw(amount);

        assertEq(inputTokenAmount, amount);
        assertEq(yieldSource.totalDeposited(), 0);
        assertGt(flaxValue, 0);
    }

    function testClaimRewards() public {
        vm.prank(vault);
        uint256 flaxValue = yieldSource.claimRewards();

        assertGt(flaxValue, 0); // MockPriceTilter: 1000 reward * 2000 = 2e6 Flax
    }

    function testClaimAndSellForInputToken() public {
        vm.prank(vault);
        uint256 inputTokenAmount = yieldSource.claimAndSellForInputToken();

        assertGt(inputTokenAmount, 0); // MockRouter: 1000 reward tokens
    }

    function testOracleConsult() public {
        uint256 amountIn = 1e18;
        uint256 amountOut = twapOracle.consult(address(inputToken), address(rewardToken), amountIn);
        assertGt(amountOut, 0);
    }

    function testOracleUpdateAccessControl() public {
        vm.prank(address(0x999));
        vm.expectRevert("Ownable: caller is not the owner");
        twapOracle.update(address(inputToken), address(rewardToken));
    }

    function testFuzzDeposit(uint256 amount) public {
        vm.assume(amount > 0 && amount < 1e18);
        inputToken.mint(vault, amount);
        vm.prank(vault);
        inputToken.approve(address(yieldSource), amount);

        vm.prank(vault);
        uint256 received = yieldSource.deposit(amount);

        assertEq(received, amount);
        assertEq(yieldSource.totalDeposited(), amount);
    }

    function testZeroRewards() public {
        vm.mockCall(
            address(convexRewardPool),
            abi.encodeWithSignature("getReward()"),
            abi.encode(true)
        );
        vm.prank(vault);
        uint256 flaxValue = yieldSource.claimRewards();
        assertEq(flaxValue, 0);
    }

    function test_RevertWhen_PriceTiltFails() public {
        vm.mockCallRevert(
            address(priceTilter),
            abi.encodeWithSignature("tiltPrice(address,uint256)", address(flaxToken), 1000),
            "Price tilt failed"
        );
        vm.prank(vault);
        vm.expectRevert("Price tilt failed");
        yieldSource.claimRewards();
    }

    function testSlippageProtection() public {
        vm.mockCall(
            address(twapOracle),
            abi.encodeWithSignature("consult(address,address,uint256)", address(rewardToken), address(0), 1000),
            abi.encode(1000)
        );
        vm.prank(vault);
        yieldSource.claimRewards(); // Should pass with mocked slippage
    }

    function testInvalidPair() public {
        vm.prank(twapOracle.owner());
        vm.expectRevert("Invalid pair");
        twapOracle.update(address(inputToken), address(0x999));
    }

    function testSetUnderlyingWeights() public {
        uint256[] memory weights = new uint256[](2);
        weights[0] = 5000; // 50%
        weights[1] = 5000; // 50%

        vm.prank(yieldSource.owner());
        yieldSource.setUnderlyingWeights(address(curvePool), weights);

        uint256 storedWeights0 = yieldSource.underlyingWeights(address(curvePool),0);
        uint256 storedWeights1 = yieldSource.underlyingWeights(address(curvePool),1);
        assertEq(storedWeights0, 5000);
        assertEq(storedWeights1, 5000);
    }

    function testSetUnderlyingWeightsInvalidSum() public {
        uint256[] memory weights = new uint256[](2);
        weights[0] = 5000;
        weights[1] = 4000; // Sum != 10000

        vm.prank(yieldSource.owner());
        vm.expectRevert("Weights must sum to 100%");
        yieldSource.setUnderlyingWeights(address(curvePool), weights);
    }
}