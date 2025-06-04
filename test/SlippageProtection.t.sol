// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/yieldSource/CVX_CRV_YieldSource.sol";
import "./mocks/Mocks.sol";

// Mock oracle that returns predictable slippage-related values
contract SlippageOracle {
    uint256 private _slippageRate = 9500; // 5% slippage by default
    
    function setSlippageRate(uint256 rate) external {
        _slippageRate = rate;
    }
    
    function consult(address, address, uint256 amountIn) external view returns (uint256) {
        return (amountIn * _slippageRate) / 10000;
    }
    
    function update(address, address) external {}
}

contract SlippageProtectionTest is Test {
    CVX_CRV_YieldSource yieldSource;
    MockERC20 inputToken;
    MockERC20 flaxToken;
    MockERC20 poolToken1;
    MockERC20 poolToken2;
    MockERC20 rewardToken;
    SlippageOracle oracle;
    MockUniswapV3Router uniswapRouter;
    MockCurvePool curvePool;
    MockConvexBooster convexBooster;
    MockConvexRewardPool convexRewardPool;
    MockPriceTilter priceTilter;
    address owner;
    address vault;
    
    function setUp() public {
        owner = address(this);
        vault = address(0xBEEF);
        
        // Create tokens
        inputToken = new MockERC20();
        flaxToken = new MockERC20();
        poolToken1 = new MockERC20();
        poolToken2 = new MockERC20();
        rewardToken = new MockERC20();
        
        // Create LP token
        MockERC20 lpToken = new MockERC20();
        
        // Create mock contracts
        oracle = new SlippageOracle();
        uniswapRouter = new MockUniswapV3Router();
        curvePool = new MockCurvePool(address(lpToken));
        convexBooster = new MockConvexBooster();
        convexRewardPool = new MockConvexRewardPool(address(rewardToken));
        priceTilter = new MockPriceTilter();
        
        // Fund contracts
        vm.deal(address(uniswapRouter), 100 ether);
        inputToken.mint(address(this), 1000 ether);
        inputToken.mint(vault, 1000 ether);
        poolToken1.mint(address(uniswapRouter), 1000 ether);
        poolToken2.mint(address(uniswapRouter), 1000 ether);
        lpToken.mint(address(curvePool), 1000 ether);
        flaxToken.mint(address(priceTilter), 1000 ether);
        
        // Set up address arrays for constructor
        address[] memory poolTokens = new address[](3);
        poolTokens[0] = address(inputToken);
        poolTokens[1] = address(poolToken1);
        poolTokens[2] = address(poolToken2);
        
        string[] memory poolTokenSymbols = new string[](3);
        poolTokenSymbols[0] = "INPUT";
        poolTokenSymbols[1] = "POOL1";
        poolTokenSymbols[2] = "POOL2";
        
        address[] memory rewardTokens = new address[](1);
        rewardTokens[0] = address(rewardToken);
        
        // Deploy YieldSource
        yieldSource = new CVX_CRV_YieldSource(
            address(inputToken),
            address(flaxToken),
            address(priceTilter),
            address(oracle),
            "LP Token",
            address(curvePool),
            address(lpToken),
            address(convexBooster),
            address(convexRewardPool),
            1, // Pool ID
            address(uniswapRouter),
            poolTokens,
            poolTokenSymbols,
            rewardTokens
        );
        
        // Whitelist vault
        yieldSource.whitelistVault(vault, true);
        
        // Approve tokens
        inputToken.approve(address(yieldSource), type(uint256).max);
        vm.prank(vault);
        inputToken.approve(address(yieldSource), type(uint256).max);
    }
    
    function testSlippageProtectionDefaultValue() public {
        // Check default slippage value
        assertEq(yieldSource.minSlippageBps(), 50, "Default slippage should be 50 bps (0.5%)");
    }
    
    function testSetMinSlippageBps() public {
        // Set new slippage value
        yieldSource.setMinSlippageBps(100);
        
        // Check updated value
        assertEq(yieldSource.minSlippageBps(), 100, "Slippage should be updated to 100 bps (1%)");
    }
    
    function testRevertOnExcessiveSlippage() public {
        // Set high slippage protection (0.1% max slippage)
        yieldSource.setMinSlippageBps(10);
        
        // Set oracle to return 5% slippage (9500/10000)
        oracle.setSlippageRate(9500);
        
        // Deposit should revert because slippage is higher than allowed
        vm.prank(vault);
        vm.expectRevert("Insufficient output");
        yieldSource.deposit(100 ether);
    }
    
    function testAllowAcceptableSlippage() public {
        // Set slippage protection to 10% max slippage
        yieldSource.setMinSlippageBps(1000);
        
        // Set oracle to return 5% slippage (9500/10000)
        oracle.setSlippageRate(9500);
        
        // Deposit should succeed because slippage is within allowed range
        vm.prank(vault);
        yieldSource.deposit(100 ether);
        
        // Verify deposit succeeded
        assertEq(yieldSource.totalDeposited(), 100 ether, "Deposit should succeed with acceptable slippage");
    }
    
    function testSlippageCalculationInSellRewardToken() public {
        // Set up a YieldSource with a custom slippage that we can monitor
        yieldSource.setMinSlippageBps(200); // 2% max slippage
        
        // Set oracle to return value with 1.5% slippage
        oracle.setSlippageRate(9850);
        
        // Set up rewards
        rewardToken.mint(address(yieldSource), 10 ether);
        
        // Call claim rewards which internally calls _sellRewardToken
        vm.prank(vault);
        yieldSource.claimRewards();
        
        // Verify that ETH was received (reward token sold successfully)
        uint256 ethBalance = address(yieldSource).balance;
        assertTrue(ethBalance > 0, "ETH balance should be positive after selling reward token");
    }
    
    function testSlippageCalculationInSellEthForInputToken() public {
        // Set slippage protection to 2% max slippage
        yieldSource.setMinSlippageBps(200);
        
        // Set oracle to return value with 1.5% slippage
        oracle.setSlippageRate(9850);
        
        // Fund YieldSource with ETH
        vm.deal(address(yieldSource), 1 ether);
        
        // Call function that internally calls _sellEthForInputToken
        vm.prank(vault);
        uint256 inputTokenAmount = yieldSource.claimAndSellForInputToken();
        
        // Verify input tokens were received
        assertTrue(inputTokenAmount > 0, "Input token amount should be positive after selling ETH");
    }
    
    function testRevertOnExcessiveOwnerSlippageSetting() public {
        // Try to set slippage higher than 100%
        vm.expectRevert("Slippage too high");
        yieldSource.setMinSlippageBps(11000);
    }
    
    function testDepositWithCustomWeights() public {
        // Set custom weights for pool tokens
        uint256[] memory weights = new uint256[](3);
        weights[0] = 3000; // 30% in input token
        weights[1] = 4000; // 40% in pool token 1
        weights[2] = 3000; // 30% in pool token 2
        
        yieldSource.setUnderlyingWeights(address(curvePool), weights);
        
        // Set slippage to 5%
        yieldSource.setMinSlippageBps(500);
        
        // Set oracle to return value with 3% slippage
        oracle.setSlippageRate(9700);
        
        // Deposit
        vm.prank(vault);
        yieldSource.deposit(100 ether);
        
        // Verify deposit succeeded
        assertEq(yieldSource.totalDeposited(), 100 ether, "Deposit should succeed with custom weights");
    }
} 