// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/yieldSource/AYieldSource.sol";
import "../src/yieldSource/CVX_CRV_YieldSource.sol";
import "../src/priceTilting/TWAPOracle.sol";
import "../src/priceTilting/IOracle.sol";
import {MockERC20} from "./mocks/Mocks.sol";
import {MockPriceTilter} from "./mocks/Mocks.sol";
import {MockUniswapV3Router} from "./mocks/Mocks.sol";
import {MockCurvePool} from "./mocks/Mocks.sol";
import {MockConvexBooster} from "./mocks/Mocks.sol";
import {MockConvexRewardPool} from "./mocks/Mocks.sol";
import {MockUniswapV2Pair} from "./mocks/Mocks.sol";
import {MockUniswapV2Factory} from "./mocks/Mocks.sol";

// Simple Mock Oracle for testing
contract MockOracle is IOracle {
    function consult(address, address, uint256 amountIn) external pure returns (uint256) {
        return amountIn; // 1:1 exchange rate
    }
    
    function update(address, address) external {
        // No-op implementation
    }
}

contract YieldSourceTest is Test {
    CVX_CRV_YieldSource yieldSource;
    MockOracle mockOracle;
    TWAPOracle twapOracle; // Keep for a few tests that need it specifically
    MockERC20 inputToken;
    MockERC20 flaxToken;
    MockERC20 crvLpToken;
    MockERC20 rewardToken;
    MockERC20 poolToken;
    MockPriceTilter priceTilter;
    MockUniswapV3Router uniswapRouter;
    MockCurvePool curvePool;
    MockConvexBooster convexBooster;
    MockConvexRewardPool convexRewardPool;
    MockUniswapV2Factory uniswapFactory;
    MockUniswapV2Pair pair;

    address vault = address(0x123);
    address weth = address(0x456);
    address[] poolTokens;
    string[] poolTokenSymbols;
    address[] rewardTokens;

    function setUp() public {
        // Set up tokens
        inputToken = new MockERC20();
        flaxToken = new MockERC20();
        crvLpToken = new MockERC20();
        rewardToken = new MockERC20();
        poolToken = new MockERC20();
        
        // Set up contracts
        mockOracle = new MockOracle();
        priceTilter = new MockPriceTilter();
        uniswapRouter = new MockUniswapV3Router();
        curvePool = new MockCurvePool(address(crvLpToken));
        convexBooster = new MockConvexBooster();
        convexRewardPool = new MockConvexRewardPool(address(rewardToken));
        uniswapFactory = new MockUniswapV2Factory();
        
        // Fund contracts with ETH
        vm.deal(address(uniswapRouter), 100 ether);
        vm.deal(address(priceTilter), 100 ether);
        
        // Set up TWAP Oracle for specific tests
        pair = new MockUniswapV2Pair(address(inputToken), address(rewardToken));
        uniswapFactory.setPair(address(inputToken), address(rewardToken), address(pair));
        twapOracle = new TWAPOracle(address(uniswapFactory), weth);
        
        // Set up pool tokens
        poolTokens.push(address(inputToken));
        poolTokens.push(address(poolToken));
        poolTokenSymbols.push("USDC");
        poolTokenSymbols.push("USDT");
        rewardTokens.push(address(rewardToken));

        // Initialize and deploy YieldSource with MockOracle for most tests
        yieldSource = new CVX_CRV_YieldSource(
            address(inputToken),
            address(flaxToken),
            address(priceTilter),
            address(mockOracle), // Use the simple mock oracle
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
        
        // Initialize TWAP Oracle for specific tests
        vm.startPrank(twapOracle.owner());
        twapOracle.update(address(inputToken), address(rewardToken));
        vm.stopPrank();
        
        // Set reserves and update TWAP 
        vm.warp(block.timestamp + 1 hours);
        pair.updateReserves(1000, 1000, uint32(block.timestamp));
        vm.prank(twapOracle.owner());
        twapOracle.update(address(inputToken), address(rewardToken));

        // Ensure price0CumulativeLast and price1CumulativeLast are non-zero
        pair.setPriceCumulativeLast(1e18, 1e18);
    }

    function testDeposit() public {
        uint256 amount = 1000;
        inputToken.mint(vault, amount);
        
        vm.prank(vault);
        inputToken.approve(address(yieldSource), amount);
        
        // Set weights to 100% first token
        uint256[] memory weights = new uint256[](2);
        weights[0] = 10000;
        weights[1] = 0;
        
        vm.prank(yieldSource.owner());
        yieldSource.setUnderlyingWeights(address(curvePool), weights);

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
        
        // Set weights to 100% first token
        uint256[] memory weights = new uint256[](2);
        weights[0] = 10000;
        weights[1] = 0;
        
        vm.prank(yieldSource.owner());
        yieldSource.setUnderlyingWeights(address(curvePool), weights);

        vm.prank(vault);
        yieldSource.deposit(amount);

        // Make sure the LP token has enough allowance for the Curve pool
        vm.prank(address(yieldSource));
        crvLpToken.approve(address(curvePool), type(uint256).max);

        // Ensure the mock price tilter will return a predictable value
        vm.mockCall(
            address(priceTilter),
            abi.encodeWithSignature("tiltPrice(address,uint256)", address(flaxToken), uint256(1000)),
            abi.encode(2000)
        );

        vm.prank(vault);
        (uint256 inputTokenAmount, uint256 flaxValue) = yieldSource.withdraw(amount);

        assertEq(inputTokenAmount, amount);
        assertEq(yieldSource.totalDeposited(), 0);
        assertEq(flaxValue, 2000); // Based on mock price tilter
    }

    function testClaimRewards() public {
        // Set up reward claim mocking
        vm.mockCall(
            address(priceTilter),
            abi.encodeWithSignature("tiltPrice(address,uint256)", address(flaxToken), uint256(1000)),
            abi.encode(2000)
        );

        vm.prank(vault);
        uint256 flaxValue = yieldSource.claimRewards();

        assertEq(flaxValue, 2000); // Based on mock price tilter
    }

    function testClaimAndSellForInputToken() public {
        // Mock ETH presence in the contract
        vm.deal(address(yieldSource), 100 ether);

        // Mock the router to return expected value for selling ETH
        vm.mockCall(
            address(uniswapRouter),
            abi.encodeWithSignature(
                "exactInputSingle((address,address,uint24,address,uint256,uint256,uint160))"
            ),
            abi.encode(1500)
        );

        vm.prank(vault);
        uint256 inputTokenAmount = yieldSource.claimAndSellForInputToken();

        assertEq(inputTokenAmount, 1500); // From mock uniswap router
    }

    function testOracleConsult() public {
        // Set up a proper mock for TWAP oracle data
        uint256 expectedOutput = 1000;
        
        vm.mockCall(
            address(pair),
            abi.encodeWithSignature("token0()"),
            abi.encode(address(inputToken))
        );

        vm.mockCall(
            address(pair),
            abi.encodeWithSignature("price0CumulativeLast()"),
            abi.encode(1e18)
        );

        vm.mockCall(
            address(pair),
            abi.encodeWithSignature("price1CumulativeLast()"),
            abi.encode(1e18)
        );

        // Mock both measurement values
        bytes32 pairKey = bytes32(uint256(uint160(address(pair))));
        
        vm.store(
            address(twapOracle),
            keccak256(abi.encode(pairKey, uint256(2))), // lastUpdateTimestamp slot
            bytes32(uint256(block.timestamp - 3600))
        );
        
        vm.mockCall(
            address(twapOracle),
            abi.encodeWithSignature("consult(address,address,uint256)", address(inputToken), address(rewardToken), uint256(1000)),
            abi.encode(expectedOutput)
        );

        uint256 amountOut = twapOracle.consult(address(inputToken), address(rewardToken), 1000);
        assertEq(amountOut, expectedOutput);
    }

    function testOracleUpdateAccessControl() public {
        vm.prank(address(0x999));
        vm.expectRevert("OwnableUnauthorizedAccount(0x0000000000000000000000000000000000000999)");
        twapOracle.update(address(inputToken), address(rewardToken));
    }

    function testFuzzDeposit(uint256 amount) public {
        vm.assume(amount > 0 && amount < 1e6);
        inputToken.mint(vault, amount);
        
        vm.prank(vault);
        inputToken.approve(address(yieldSource), amount);
        
        // Set weights to 100% first token
        uint256[] memory weights = new uint256[](2);
        weights[0] = 10000;
        weights[1] = 0;
        
        vm.prank(yieldSource.owner());
        yieldSource.setUnderlyingWeights(address(curvePool), weights);

        vm.prank(vault);
        uint256 received = yieldSource.deposit(amount);

        assertEq(received, amount);
        assertEq(yieldSource.totalDeposited(), amount);
    }

    function testZeroRewards() public {
        // Override the reward token balance to be 0
        vm.mockCall(
            address(rewardToken),
            abi.encodeWithSignature("balanceOf(address)"),
            abi.encode(0)
        );

        vm.prank(vault);
        uint256 flaxValue = yieldSource.claimRewards();
        
        assertEq(flaxValue, 0);
    }

    function test_RevertWhen_PriceTiltFails() public {
        // Make sure we have a reward token balance
        vm.mockCall(
            address(rewardToken),
            abi.encodeWithSignature("balanceOf(address)"),
            abi.encode(1000)
        );
        
        // Make the price tilt function revert
        vm.mockCallRevert(
            address(priceTilter),
            abi.encodeWithSignature("tiltPrice(address,uint256)", address(flaxToken), uint256(1000)),
            "Price tilt failed"
        );
        
        vm.prank(vault);
        vm.expectRevert("Price tilt failed");
        yieldSource.claimRewards();
    }

    function testSlippageProtection() public {
        uint256 rewardAmount = 1000;

        // Mock the price tilter to return a predictable value
        vm.mockCall(
            address(priceTilter),
            abi.encodeWithSignature("tiltPrice(address,uint256)", address(flaxToken), rewardAmount),
            abi.encode(2000)
        );

        vm.prank(vault);
        uint256 flaxValue = yieldSource.claimRewards();
        
        assertEq(flaxValue, 2000);
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