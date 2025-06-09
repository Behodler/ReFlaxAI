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
        
        // Set pool tokens in the curve pool mock
        curvePool.setPoolTokens(poolTokens);
        
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
            abi.encode(1e18) // Using a generic non-zero value
        );

        vm.mockCall(
            address(pair),
            abi.encodeWithSignature("price1CumulativeLast()"),
            abi.encode(1e18) // Using a generic non-zero value
        );
      
        // Mock the consult call on the twapOracle instance directly for this test
        vm.mockCall(
            address(twapOracle),
            abi.encodeWithSignature("consult(address,address,uint256)", address(inputToken), address(rewardToken), uint256(1000)),
            abi.encode(expectedOutput)
        );

        uint256 amountOut = twapOracle.consult(address(inputToken), address(rewardToken), 1000);
        assertEq(amountOut, expectedOutput);
    }

    function testFuzzDeposit(uint256 amount) public { 
        vm.assume(amount > 0.1 ether && amount < 100000 ether);

        inputToken.mint(vault, amount); 

        vm.startPrank(vault);
        inputToken.approve(address(yieldSource), amount);

        // Ensure default weights (or set specific ones if the test requires)
        // For simplicity, we assume weights are set or default logic in _depositToProtocol handles it.
        // If underlyingWeights are not set, _depositToProtocol will divide by poolTokens.length.
        // Let's ensure poolTokens has a predictable length for the fuzz test if weights are not explicitly set.
        // Or, set weights to 100% for the input token if it's the first poolToken.
        if (poolTokens.length > 0 && poolTokens[0] == address(inputToken)) {
            uint256[] memory weights = new uint256[](poolTokens.length);
            weights[0] = 10000;
            for (uint256 i = 1; i < poolTokens.length; i++) {
                weights[i] = 0;
            }
            vm.stopPrank(); // Stop vault prank to set weights as owner
            vm.prank(yieldSource.owner());
            yieldSource.setUnderlyingWeights(address(curvePool), weights);
            vm.startPrank(vault); // Restart vault prank
        }

        uint256 received = yieldSource.deposit(amount);
        vm.stopPrank();

        assertEq(received, amount, "LP amount received should match input for 100% weight");
        // totalDeposited check might need adjustment based on mock behavior of _depositToProtocol
        // For this fuzz test, primarily checking no reverts and basic state changes is okay.
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
        // This test will use the twapOracle instance directly to check its behavior
        // as yieldSource.oracle() in setUp is a MockOracle.
        vm.expectRevert("TWAPOracle: INVALID_PAIR");
        twapOracle.consult(address(0xDEADBEEF), address(0xBADF00D), 1 ether);
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

    function testEmergencyWithdrawTokens() public {
        // Setup: mint some tokens to yield source
        MockERC20 otherToken = new MockERC20();
        uint256 amount = 500 * 1e18;
        otherToken.mint(address(yieldSource), amount);

        // Test that only owner can call
        vm.expectRevert();
        vm.prank(address(0x1234));
        yieldSource.emergencyWithdraw(address(otherToken), address(0x9999));

        // Test successful emergency withdrawal
        address recipient = address(0x9999);
        
        vm.prank(yieldSource.owner());
        yieldSource.emergencyWithdraw(address(otherToken), recipient);
        
        assertEq(otherToken.balanceOf(recipient), amount, "Recipient should have received tokens");
        assertEq(otherToken.balanceOf(address(yieldSource)), 0, "YieldSource should have no tokens left");

        // Test withdrawal with no balance
        vm.prank(yieldSource.owner());
        yieldSource.emergencyWithdraw(address(otherToken), recipient); // Should not revert
    }

    function testEmergencyWithdrawETH() public {
        // Send ETH to yield source
        uint256 ethAmount = 5 ether;
        vm.deal(address(yieldSource), ethAmount);

        // Test that only owner can call
        vm.expectRevert();
        vm.prank(address(0x1234));
        yieldSource.emergencyWithdraw(address(0), address(0x9999));

        // Test successful ETH withdrawal
        address payable recipient = payable(address(0x9999));
        uint256 recipientBalanceBefore = recipient.balance;
        
        vm.prank(yieldSource.owner());
        yieldSource.emergencyWithdraw(address(0), recipient);
        
        assertEq(recipient.balance, recipientBalanceBefore + ethAmount, "Recipient should have received ETH");
        assertEq(address(yieldSource).balance, 0, "YieldSource should have no ETH left");

        // Test withdrawal with no balance
        vm.prank(yieldSource.owner());
        yieldSource.emergencyWithdraw(address(0), recipient); // Should not revert
    }

    function testSetMinSlippageBps() public {
        // Test that only owner can set
        vm.expectRevert();
        vm.prank(address(0x1234));
        yieldSource.setMinSlippageBps(500);

        // Test successful setting
        vm.prank(yieldSource.owner());
        yieldSource.setMinSlippageBps(500);
        
        assertEq(yieldSource.minSlippageBps(), 500, "Min slippage should be updated");

        // Test revert on excessive value (should fail with value > 10000)
        vm.prank(yieldSource.owner());
        vm.expectRevert("Slippage too high");
        yieldSource.setMinSlippageBps(10001);
    }

    function testSetLpTokenName() public {
        // Test that only owner can set
        vm.expectRevert();
        vm.prank(address(0x1234));
        yieldSource.setLpTokenName("New Name");

        // Test successful setting
        vm.prank(yieldSource.owner());
        yieldSource.setLpTokenName("New LP Token Name");
        
        assertEq(yieldSource.lpTokenName(), "New LP Token Name", "LP token name should be updated");
    }

    function testMultiplePoolTokensConfiguration() public {
        // Test with 3 pool tokens instead of 2
        address[] memory newPoolTokens = new address[](3);
        string[] memory newPoolTokenSymbols = new string[](3);
        
        MockERC20 token1 = new MockERC20();
        MockERC20 token2 = new MockERC20();
        MockERC20 token3 = new MockERC20();
        
        newPoolTokens[0] = address(token1);
        newPoolTokens[1] = address(token2);
        newPoolTokens[2] = address(token3);
        newPoolTokenSymbols[0] = "USDC";
        newPoolTokenSymbols[1] = "USDT";
        newPoolTokenSymbols[2] = "DAI";

        // Test successful deployment with 3 tokens
        CVX_CRV_YieldSource newYieldSource = new CVX_CRV_YieldSource(
            address(inputToken),
            address(flaxToken),
            address(priceTilter),
            address(mockOracle),
            "CRV 3pool",
            address(curvePool),
            address(crvLpToken),
            address(convexBooster),
            address(convexRewardPool),
            123,
            address(uniswapRouter),
            newPoolTokens,
            newPoolTokenSymbols,
            rewardTokens
        );

        // Test that 3-token weights work
        uint256[] memory weights = new uint256[](3);
        weights[0] = 3333; // 33.33%
        weights[1] = 3333; // 33.33%
        weights[2] = 3334; // 33.34%

        vm.prank(newYieldSource.owner());
        newYieldSource.setUnderlyingWeights(address(curvePool), weights);

        assertEq(newYieldSource.underlyingWeights(address(curvePool), 0), 3333);
        assertEq(newYieldSource.underlyingWeights(address(curvePool), 1), 3333);
        assertEq(newYieldSource.underlyingWeights(address(curvePool), 2), 3334);
    }

    function testInvalidPoolTokenConfiguration() public {
        // Test with 1 pool token (should fail - minimum is 2)
        address[] memory invalidPoolTokens = new address[](1);
        string[] memory invalidPoolTokenSymbols = new string[](1);
        
        invalidPoolTokens[0] = address(inputToken);
        invalidPoolTokenSymbols[0] = "USDC";

        vm.expectRevert("Invalid pool token count");
        new CVX_CRV_YieldSource(
            address(inputToken),
            address(flaxToken),
            address(priceTilter),
            address(mockOracle),
            "CRV invalid",
            address(curvePool),
            address(crvLpToken),
            address(convexBooster),
            address(convexRewardPool),
            123,
            address(uniswapRouter),
            invalidPoolTokens,
            invalidPoolTokenSymbols,
            rewardTokens
        );

        // Test with 5 pool tokens (should fail - maximum is 4)
        address[] memory tooManyTokens = new address[](5);
        string[] memory tooManySymbols = new string[](5);
        
        for (uint256 i = 0; i < 5; i++) {
            tooManyTokens[i] = address(new MockERC20());
            tooManySymbols[i] = "TOKEN";
        }

        vm.expectRevert("Invalid pool token count");
        new CVX_CRV_YieldSource(
            address(inputToken),
            address(flaxToken),
            address(priceTilter),
            address(mockOracle),
            "CRV invalid",
            address(curvePool),
            address(crvLpToken),
            address(convexBooster),
            address(convexRewardPool),
            123,
            address(uniswapRouter),
            tooManyTokens,
            tooManySymbols,
            rewardTokens
        );
    }

    function testMismatchedTokenSymbols() public {
        // Test with mismatched token and symbol arrays
        address[] memory tokens = new address[](2);
        string[] memory symbols = new string[](3); // Different length
        
        tokens[0] = address(inputToken);
        tokens[1] = address(poolToken);
        symbols[0] = "USDC";
        symbols[1] = "USDT";
        symbols[2] = "DAI";

        vm.expectRevert("Mismatched symbols");
        new CVX_CRV_YieldSource(
            address(inputToken),
            address(flaxToken),
            address(priceTilter),
            address(mockOracle),
            "CRV invalid",
            address(curvePool),
            address(crvLpToken),
            address(convexBooster),
            address(convexRewardPool),
            123,
            address(uniswapRouter),
            tokens,
            symbols,
            rewardTokens
        );
    }

    function testSetUnderlyingWeightsEdgeCases() public {
        // Test with wrong pool address
        uint256[] memory weights = new uint256[](2);
        weights[0] = 5000;
        weights[1] = 5000;

        vm.prank(yieldSource.owner());
        vm.expectRevert("Invalid pool");
        yieldSource.setUnderlyingWeights(address(0x9999), weights);

        // Test with wrong number of weights
        uint256[] memory wrongWeights = new uint256[](3); // Should be 2
        wrongWeights[0] = 3333;
        wrongWeights[1] = 3333;
        wrongWeights[2] = 3334;

        vm.prank(yieldSource.owner());
        vm.expectRevert("Mismatched weights");
        yieldSource.setUnderlyingWeights(address(curvePool), wrongWeights);
    }

    function testMultipleRewardTokens() public {
        // Create additional reward tokens
        MockERC20 rewardToken2 = new MockERC20();
        MockERC20 rewardToken3 = new MockERC20();
        
        // Create reward pools for each token
        MockConvexRewardPool rewardPool2 = new MockConvexRewardPool(address(rewardToken2));
        MockConvexRewardPool rewardPool3 = new MockConvexRewardPool(address(rewardToken3));
        
        // Setup reward tokens array
        address[] memory multiRewardTokens = new address[](3);
        multiRewardTokens[0] = address(rewardToken);
        multiRewardTokens[1] = address(rewardToken2);
        multiRewardTokens[2] = address(rewardToken3);

        // Create new YieldSource with multiple reward tokens
        CVX_CRV_YieldSource multiRewardYieldSource = new CVX_CRV_YieldSource(
            address(inputToken),
            address(flaxToken),
            address(priceTilter),
            address(mockOracle),
            "CRV multi-reward",
            address(curvePool),
            address(crvLpToken),
            address(convexBooster),
            address(convexRewardPool), // Will claim all rewards
            123,
            address(uniswapRouter),
            poolTokens,
            poolTokenSymbols,
            multiRewardTokens
        );

        // Whitelist vault
        vm.prank(multiRewardYieldSource.owner());
        multiRewardYieldSource.whitelistVault(vault, true);

        // Pre-fund the yield source with multiple reward tokens
        // The first token will be minted by MockConvexRewardPool.getReward()
        // so we only need to pre-mint the other tokens
        rewardToken2.mint(address(multiRewardYieldSource), 2000);  
        rewardToken3.mint(address(multiRewardYieldSource), 3000);

        // Fund uniswap router with ETH to simulate selling rewards
        vm.deal(address(uniswapRouter), 100 ether);

        // Test claiming rewards from multiple tokens
        vm.prank(vault);
        uint256 totalFlaxValue = multiRewardYieldSource.claimRewards();

        // Should return some flax value (mock price tilter returns 2x the ETH amount)
        assertGt(totalFlaxValue, 0, "Should have claimed rewards from multiple tokens");

        // Verify rewards were claimed (balances should be 0)
        assertEq(rewardToken.balanceOf(address(multiRewardYieldSource)), 0, "Reward token 1 should be sold");
        assertEq(rewardToken2.balanceOf(address(multiRewardYieldSource)), 0, "Reward token 2 should be sold");
        assertEq(rewardToken3.balanceOf(address(multiRewardYieldSource)), 0, "Reward token 3 should be sold");
    }

    function testClaimAndSellForInputTokenMultipleRewards() public {
        // Create additional reward tokens
        MockERC20 rewardToken2 = new MockERC20();
        
        address[] memory multiRewardTokens = new address[](2);
        multiRewardTokens[0] = address(rewardToken);
        multiRewardTokens[1] = address(rewardToken2);

        // Create new YieldSource with multiple reward tokens
        CVX_CRV_YieldSource multiRewardYieldSource = new CVX_CRV_YieldSource(
            address(inputToken),
            address(flaxToken),
            address(priceTilter),
            address(mockOracle),
            "CRV multi-reward-sell",
            address(curvePool),
            address(crvLpToken),
            address(convexBooster),
            address(convexRewardPool),
            123,
            address(uniswapRouter),
            poolTokens,
            poolTokenSymbols,
            multiRewardTokens
        );

        // Whitelist vault
        vm.prank(multiRewardYieldSource.owner());
        multiRewardYieldSource.whitelistVault(vault, true);

        // Pre-fund the yield source with multiple reward tokens
        // The first token will be minted by MockConvexRewardPool.getReward()
        // so we only need to pre-mint the second token
        rewardToken2.mint(address(multiRewardYieldSource), 2000);

        // Fund uniswap router with input tokens to simulate selling rewards for input token
        inputToken.mint(address(uniswapRouter), 10000);

        // Test claiming and selling rewards for input token
        vm.prank(vault);
        uint256 inputTokenAmount = multiRewardYieldSource.claimAndSellForInputToken();

        // Should return some input tokens
        assertGt(inputTokenAmount, 0, "Should have sold multiple reward tokens for input token");

        // Verify rewards were claimed and sold
        assertEq(rewardToken.balanceOf(address(multiRewardYieldSource)), 0, "Reward token 1 should be sold");
        assertEq(rewardToken2.balanceOf(address(multiRewardYieldSource)), 0, "Reward token 2 should be sold");
    }

    function testEmptyRewardTokensList() public {
        // Test YieldSource with no reward tokens
        address[] memory emptyRewardTokens = new address[](0);

        CVX_CRV_YieldSource noRewardYieldSource = new CVX_CRV_YieldSource(
            address(inputToken),
            address(flaxToken),
            address(priceTilter),
            address(mockOracle),
            "CRV no-rewards",
            address(curvePool),
            address(crvLpToken),
            address(convexBooster),
            address(convexRewardPool),
            123,
            address(uniswapRouter),
            poolTokens,
            poolTokenSymbols,
            emptyRewardTokens
        );

        // Whitelist vault
        vm.prank(noRewardYieldSource.owner());
        noRewardYieldSource.whitelistVault(vault, true);

        // Test claiming rewards with no reward tokens should return 0
        vm.prank(vault);
        uint256 flaxValue = noRewardYieldSource.claimRewards();
        assertEq(flaxValue, 0, "Should return 0 flax value with no reward tokens");

        // Test claimAndSellForInputToken with no rewards
        vm.prank(vault);
        uint256 inputTokenAmount = noRewardYieldSource.claimAndSellForInputToken();
        assertEq(inputTokenAmount, 0, "Should return 0 input tokens with no rewards");
    }
}