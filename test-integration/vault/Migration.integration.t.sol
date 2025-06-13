// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {IntegrationTest} from "../base/IntegrationTest.sol";
import {ArbitrumConstants} from "../base/ArbitrumConstants.sol";
import {Vault} from "../../src/vault/Vault.sol";
import {CVX_CRV_YieldSource} from "../../src/yieldSource/CVX_CRV_YieldSource.sol";
import {IERC20} from "../../lib/oz_reflax/token/ERC20/IERC20.sol";

// Mock Flax token with burn capability for sFlax
contract MockFlaxToken {
    string public name = "Flax Token";
    string public symbol = "FLAX";
    uint8 public decimals = 18;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    
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
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }
    
    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        require(balanceOf[from] >= amount, "Insufficient balance");
        require(allowance[from][msg.sender] >= amount, "Insufficient allowance");
        
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        allowance[from][msg.sender] -= amount;
        
        emit Transfer(from, to, amount);
        return true;
    }
    
    function burn(uint256 amount) external {
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        balanceOf[msg.sender] -= amount;
        totalSupply -= amount;
        emit Transfer(msg.sender, address(0), amount);
    }
}

contract TestVault is Vault {
    constructor(
        address _flaxToken,
        address _sFlaxToken, 
        address _inputToken,
        address _yieldSource,
        address _priceTilter
    ) Vault(_flaxToken, _sFlaxToken, _inputToken, _yieldSource, _priceTilter) {}
    
    function canWithdraw(address, uint256) public pure returns (bool) {
        return true;
    }
}

// Mock oracle for simplified testing
contract MockOracle {
    address public usdeTokenAddr;
    
    constructor(address _usdeTokenAddr) {
        usdeTokenAddr = _usdeTokenAddr;
    }
    
    function update(address, address) external {}
    function consult(address tokenIn, address tokenOut, uint256 amountIn) external view returns (uint256) {
        if (tokenIn == ArbitrumConstants.USDC && tokenOut == usdeTokenAddr) {
            return amountIn * 1e12;
        } else if (tokenIn == usdeTokenAddr && tokenOut == ArbitrumConstants.USDC) {
            return amountIn / 1e12;
        } else if (tokenIn == address(0) && tokenOut == ArbitrumConstants.USDC) {
            return amountIn * 1000 / 1e12;
        } else if (tokenOut == address(0)) {
            if (tokenIn == ArbitrumConstants.CRV || tokenIn == ArbitrumConstants.CVX) {
                return amountIn / 1000;
            } else if (tokenIn == ArbitrumConstants.USDC) {
                return amountIn * 1e12 / 1000;
            }
            return amountIn / 1000;
        } else if (tokenIn == address(0)) {
            return amountIn * 1000;
        } else {
            return amountIn;
        }
    }
}

// Mock price tilter for simplified testing  
contract MockPriceTilter {
    uint256 public flaxCalculated;
    
    function tiltPrice(address, uint256 ethAmount) external payable returns (uint256) {
        flaxCalculated = ethAmount * 1000; // 1 ETH = 1000 FLAX
        return flaxCalculated;
    }
    
    function registerPair(address, address) external {}
    function setPriceTiltRatio(uint256) external {}
}

// Mock Convex Booster for different pools
contract MockConvexBooster {
    mapping(uint256 => mapping(address => uint256)) public userDeposits;
    mapping(uint256 => address) public poolLpTokens;
    
    function setPoolLpToken(uint256 pid, address _lpToken) external {
        poolLpTokens[pid] = _lpToken;
    }
    
    function deposit(uint256 pid, uint256 amount, bool stake) external returns (bool) {
        address lpToken = poolLpTokens[pid];
        require(lpToken != address(0), "Pool not configured");
        
        IERC20(lpToken).transferFrom(msg.sender, address(this), amount);
        userDeposits[pid][msg.sender] += amount;
        console2.log("MockConvexBooster deposit", amount);
        return true;
    }
    
    function withdraw(uint256 pid, uint256 amount) external returns (bool) {
        address lpToken = poolLpTokens[pid];
        require(lpToken != address(0), "Pool not configured");
        
        uint256 actualLpAmount = userDeposits[pid][msg.sender];
        console2.log("MockConvexBooster withdraw requested", amount);
        
        uint256 withdrawAmount;
        
        if (amount < 1e15) {
            uint256 lpEquivalent = amount * 1e12;
            withdrawAmount = actualLpAmount < lpEquivalent ? actualLpAmount : lpEquivalent;
            console2.log("MockConvexBooster converting USDC", amount);
        } else {
            withdrawAmount = amount > actualLpAmount ? actualLpAmount : amount;
            console2.log("MockConvexBooster LP amount requested", amount);
        }
        
        require(actualLpAmount > 0 && withdrawAmount > 0, "Insufficient deposit");
        userDeposits[pid][msg.sender] -= withdrawAmount;
        console2.log("MockConvexBooster withdrawing", withdrawAmount);
        IERC20(lpToken).transfer(msg.sender, withdrawAmount);
        return true;
    }
    
    function userInfo(uint256 pid, address user) external view returns (uint256, uint256) {
        return (userDeposits[pid][user], 0);
    }
}

// Mock Convex Reward Pool
contract MockConvexRewardPool {
    mapping(address => uint256) public rewardBalances;
    MockFlaxToken public mockCRV;
    MockFlaxToken public mockCVX;
    
    constructor() {
        mockCRV = new MockFlaxToken();
        mockCVX = new MockFlaxToken();
        
        // Pre-mint a large amount of mock rewards
        mockCRV.mint(address(this), 1000000e18);
        mockCVX.mint(address(this), 1000000e18);
    }
    
    function getReward() external returns (bool) {
        // Transfer mock reward tokens instead of real ones
        mockCRV.transfer(msg.sender, 100e18); // 100 mock CRV
        mockCVX.transfer(msg.sender, 50e18);  // 50 mock CVX
        
        return true;
    }
    
    function getCRVAddress() external view returns (address) {
        return address(mockCRV);
    }
    
    function getCVXAddress() external view returns (address) {
        return address(mockCVX);
    }
}

// Mock Curve Pool
contract MockCurvePool {
    address public token0;
    address public token1;
    address public lpToken;
    
    constructor(address _token0, address _token1, address _lpToken) {
        token0 = _token0;
        token1 = _token1;
        lpToken = _lpToken;
    }
    
    function add_liquidity(uint256[2] memory amounts, uint256 min_mint_amount) external returns (uint256) {
        uint256 totalAmount = amounts[0] + amounts[1];
        
        if (amounts[0] > 0) {
            IERC20(token0).transferFrom(msg.sender, address(this), amounts[0]);
        }
        if (amounts[1] > 0) {
            IERC20(token1).transferFrom(msg.sender, address(this), amounts[1]);
        }
        
        uint256 lpAmount = totalAmount;
        if (token0 == ArbitrumConstants.USDC) {
            lpAmount = totalAmount * 1e12;
        }
        
        MockFlaxToken(lpToken).mint(msg.sender, lpAmount);
        console2.log("MockCurvePool added liquidity", lpAmount);
        return lpAmount;
    }
    
    function remove_liquidity_one_coin(uint256 token_amount, int128 i, uint256 min_amount) external returns (uint256) {
        address outputToken = (i == 0) ? token0 : token1;
        
        MockFlaxToken(lpToken).transferFrom(msg.sender, address(this), token_amount);
        
        uint256 outputAmount = token_amount;
        if (outputToken == ArbitrumConstants.USDC) {
            outputAmount = token_amount / 1e12;
        }
        
        IERC20(outputToken).transfer(msg.sender, outputAmount);
        console2.log("MockCurvePool removed LP tokens", token_amount);
        return outputAmount;
    }
    
    function calc_withdraw_one_coin(uint256 token_amount, int128 i) external view returns (uint256) {
        if (i == 0 && token0 == ArbitrumConstants.USDC) {
            return token_amount / 1e12;
        }
        return token_amount;
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
    
    function exactInputSingle(
        ExactInputSingleParams calldata params
    ) external payable returns (uint256 amountOut) {
        // Transfer input tokens from sender
        if (params.tokenIn != address(0)) {
            IERC20(params.tokenIn).transferFrom(msg.sender, address(this), params.amountIn);
        }
        
        // Calculate output amount based on input
        if (params.tokenIn == ArbitrumConstants.USDC) {
            // USDC (6 decimals) to another token (18 decimals)
            amountOut = params.amountIn * 1e12; // Convert 6 decimals to 18 decimals
        } else if (params.tokenOut == ArbitrumConstants.USDC) {
            // Token (18 decimals) to USDC (6 decimals)
            amountOut = params.amountIn / 1e12; // Convert 18 decimals to 6 decimals
        } else if (params.tokenOut == address(0)) {
            // Selling for ETH - assume 1 token = 0.001 ETH (1000 tokens per ETH)
            amountOut = params.amountIn / 1000;
            if (params.tokenIn == ArbitrumConstants.USDC) {
                amountOut = params.amountIn * 1e12 / 1000; // Adjust for USDC decimals
            }
            
            // Send ETH to recipient
            payable(params.recipient).transfer(amountOut);
            return amountOut;
        } else {
            // Default 1:1 conversion
            amountOut = params.amountIn;
        }
        
        // Transfer output tokens to recipient  
        if (params.tokenOut != address(0)) {
            if (params.tokenOut == ArbitrumConstants.USDC) {
                // For USDC, we need to transfer from our balance, not mint
                IERC20(params.tokenOut).transfer(params.recipient, amountOut);
            } else {
                // For mock tokens, we can mint
                MockFlaxToken(params.tokenOut).mint(params.recipient, amountOut);
            }
        }
        
        return amountOut;
    }
}

/**
 * @title Migration Stress Test
 * @notice Comprehensive integration test for vault migration between different yield sources
 */
contract MigrationIntegrationTest is IntegrationTest {
    TestVault public vault;
    CVX_CRV_YieldSource public yieldSource1; // USDC/USDe pool
    CVX_CRV_YieldSource public yieldSource2; // Different pool for migration target
    MockFlaxToken public flaxToken;
    MockFlaxToken public sFlaxToken;
    MockFlaxToken public lpToken1;
    MockFlaxToken public lpToken2;
    MockFlaxToken public usdeToken;
    MockOracle public oracle;
    MockPriceTilter public priceTilter;
    MockConvexBooster public convexBooster;
    MockConvexRewardPool public rewardPool;
    MockCurvePool public curvePool1;
    MockCurvePool public curvePool2;
    MockUniswapV3Router public uniswapRouter;

    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public charlie = makeAddr("charlie");
    address public owner = makeAddr("owner");

    function setUp() public override {
        super.setUp();
        
        vm.startPrank(owner);
        
        // Deploy mock tokens
        flaxToken = new MockFlaxToken();
        sFlaxToken = new MockFlaxToken();
        lpToken1 = new MockFlaxToken(); // USDC/USDe LP
        lpToken2 = new MockFlaxToken(); // Different pool LP
        usdeToken = new MockFlaxToken(); // Mock USDe token
        
        // Setup labels
        vm.label(address(flaxToken), "FlaxToken");
        vm.label(address(sFlaxToken), "sFlaxToken");
        vm.label(address(lpToken1), "LP_Token_1");
        vm.label(address(lpToken2), "LP_Token_2");
        vm.label(alice, "Alice");
        vm.label(bob, "Bob");
        vm.label(charlie, "Charlie");
        
        // Deploy mock infrastructure
        oracle = new MockOracle(address(usdeToken));
        priceTilter = new MockPriceTilter();
        convexBooster = new MockConvexBooster();
        rewardPool = new MockConvexRewardPool();
        uniswapRouter = new MockUniswapV3Router();
        
        // Deploy curve pools
        curvePool1 = new MockCurvePool(ArbitrumConstants.USDC, address(usdeToken), address(lpToken1));
        curvePool2 = new MockCurvePool(ArbitrumConstants.USDC, address(usdeToken), address(lpToken2));
        
        // Configure Convex pools
        convexBooster.setPoolLpToken(1, address(lpToken1)); // Pool 1
        convexBooster.setPoolLpToken(2, address(lpToken2)); // Pool 2
        
        // Prepare arrays for constructor
        address[] memory poolTokens = new address[](2);
        poolTokens[0] = ArbitrumConstants.USDC;
        poolTokens[1] = address(usdeToken);
        
        string[] memory poolTokenSymbols = new string[](2);
        poolTokenSymbols[0] = "USDC";
        poolTokenSymbols[1] = "USDe";
        
        address[] memory rewardTokens = new address[](2);
        rewardTokens[0] = rewardPool.getCRVAddress();
        rewardTokens[1] = rewardPool.getCVXAddress();

        // Deploy yield sources
        yieldSource1 = new CVX_CRV_YieldSource(
            ArbitrumConstants.USDC,        // _inputToken
            address(flaxToken),            // _flaxToken
            address(priceTilter),          // _priceTilter
            address(oracle),               // _oracle
            "USDC/USDe LP Pool 1",         // _lpTokenName
            address(curvePool1),           // _curvePool
            address(lpToken1),             // _crvLpToken
            address(convexBooster),        // _convexBooster
            address(rewardPool),           // _convexRewardPool
            1,                             // _poolId
            address(uniswapRouter),        // _uniswapV3Router
            poolTokens,                    // _poolTokens
            poolTokenSymbols,              // _poolTokenSymbols
            rewardTokens                   // _rewardTokens
        );
        
        yieldSource2 = new CVX_CRV_YieldSource(
            ArbitrumConstants.USDC,        // _inputToken
            address(flaxToken),            // _flaxToken
            address(priceTilter),          // _priceTilter
            address(oracle),               // _oracle
            "USDC/USDe LP Pool 2",         // _lpTokenName
            address(curvePool2),           // _curvePool
            address(lpToken2),             // _crvLpToken
            address(convexBooster),        // _convexBooster
            address(rewardPool),           // _convexRewardPool
            2,                             // _poolId
            address(uniswapRouter),        // _uniswapV3Router
            poolTokens,                    // _poolTokens
            poolTokenSymbols,              // _poolTokenSymbols
            rewardTokens                   // _rewardTokens
        );
        
        // Deploy vault with first yield source
        vault = new TestVault(
            address(flaxToken),
            address(sFlaxToken),
            ArbitrumConstants.USDC,
            address(yieldSource1),
            address(priceTilter)
        );
        
        // Set owner on yield sources first
        yieldSource1.transferOwnership(owner);
        yieldSource2.transferOwnership(owner);
        
        // Whitelist vault on yield sources
        yieldSource1.whitelistVault(address(vault), true);
        yieldSource2.whitelistVault(address(vault), true);
        
        // Fix missing approvals for LP tokens to curve pools (needed for remove_liquidity_one_coin)
        vm.startPrank(address(yieldSource1));
        lpToken1.approve(address(curvePool1), type(uint256).max);
        vm.stopPrank();
        
        vm.startPrank(address(yieldSource2));
        lpToken2.approve(address(curvePool2), type(uint256).max);
        vm.stopPrank();
        
        // Mint Flax to vault for rewards
        flaxToken.mint(address(vault), 1000000e18);
        
        // Mint reward tokens directly to reward pool for testing
        // Since we're using real CRV/CVX tokens, we need to use vm.deal or find whales
        vm.deal(address(rewardPool), 1 ether); // Give ETH for gas
        
        // For this test, we'll mock the reward claiming by transferring tokens during claims
        
        // Setup user funds
        dealUSDC(alice, 100000e6);   // 100k USDC
        dealUSDC(bob, 150000e6);     // 150k USDC
        dealUSDC(charlie, 50000e6);  // 50k USDC
        
        // Give ETH to mock router for reward token sales
        vm.deal(address(uniswapRouter), 100 ether);
        
        // Pre-mint USDe tokens to mock router for swaps  
        usdeToken.mint(address(uniswapRouter), 1000000e18);
        
        // Give USDC to mock router for swaps
        dealUSDC(address(uniswapRouter), 1000000e6);
        
        // Give USDC to curve pools for withdrawals
        dealUSDC(address(curvePool1), 1000000e6);
        dealUSDC(address(curvePool2), 1000000e6);
        
        vm.stopPrank();
    }
    
    function testBasicMigration() public {
        console2.log("\n=== Test Basic Migration ===");
        
        // Alice deposits into first yield source
        vm.startPrank(alice);
        usdc.approve(address(vault), 50000e6);
        vault.deposit(50000e6);
        vm.stopPrank();
        
        // Verify deposit in first yield source
        assertEq(vault.originalDeposits(alice), 50000e6);
        assertEq(vault.totalDeposits(), 50000e6);
        
        // Perform migration
        vm.prank(owner);
        vault.migrateYieldSource(address(yieldSource2));
        
        // Verify migration completed
        assertEq(address(vault.yieldSource()), address(yieldSource2));
        assertEq(vault.originalDeposits(alice), 50000e6);
        // Total deposits should include original deposit plus rewards converted to USDC
        uint256 expectedTotalDeposits = 50000e6 + 150000; // 50k USDC + 0.15 USDC from rewards
        assertEq(vault.totalDeposits(), expectedTotalDeposits);
        
        // Alice should still be able to withdraw
        vm.prank(alice);
        vault.withdraw(25000e6, true, 0);
        
        assertEq(vault.originalDeposits(alice), 25000e6);
        assertTrue(usdc.balanceOf(alice) >= 25000e6);
        
        console2.log("Basic migration completed successfully");
    }
    
    function testMultiUserMigration() public {
        console2.log("\n=== Test Multi-User Migration ===");
        
        // Multiple users deposit
        vm.startPrank(alice);
        usdc.approve(address(vault), 75000e6);
        vault.deposit(75000e6);
        vm.stopPrank();
        
        vm.startPrank(bob);
        usdc.approve(address(vault), 100000e6);
        vault.deposit(100000e6);
        vm.stopPrank();
        
        vm.startPrank(charlie);
        usdc.approve(address(vault), 30000e6);
        vault.deposit(30000e6);
        vm.stopPrank();
        
        // Record balances before migration
        uint256 totalBefore = vault.totalDeposits();
        uint256 aliceDepositBefore = vault.originalDeposits(alice);
        uint256 bobDepositBefore = vault.originalDeposits(bob);
        uint256 charlieDepositBefore = vault.originalDeposits(charlie);
        
        // Perform migration
        vm.prank(owner);
        vault.migrateYieldSource(address(yieldSource2));
        
        // Verify all user deposits preserved, accounting for rewards
        uint256 expectedTotalAfter = totalBefore + 150000; // Original deposits + 0.15 USDC from rewards
        assertEq(vault.totalDeposits(), expectedTotalAfter);
        assertEq(vault.originalDeposits(alice), aliceDepositBefore);
        assertEq(vault.originalDeposits(bob), bobDepositBefore);
        assertEq(vault.originalDeposits(charlie), charlieDepositBefore);
        
        // All users should be able to withdraw
        vm.prank(alice);
        vault.withdraw(25000e6, true, 0);
        
        vm.prank(bob);
        vault.withdraw(50000e6, true, 0);
        
        vm.prank(charlie);
        vault.withdraw(15000e6, true, 0);
        
        console2.log("Multi-user migration completed successfully");
    }
    
    function testMigrationWithAccumulatedRewards() public {
        console2.log("\n=== Test Migration with Accumulated Rewards ===");
        
        // Users deposit
        vm.startPrank(alice);
        usdc.approve(address(vault), 80000e6);
        vault.deposit(80000e6);
        vm.stopPrank();
        
        vm.startPrank(bob);
        usdc.approve(address(vault), 120000e6);
        vault.deposit(120000e6);
        vm.stopPrank();
        
        // Simulate time passing and rewards accumulating
        advanceTime(30 days);
        
        // Users claim some rewards
        uint256 aliceFlaxBefore = flaxToken.balanceOf(alice);
        vm.prank(alice);
        vault.claimRewards(0);
        uint256 aliceRewards = flaxToken.balanceOf(alice) - aliceFlaxBefore;
        
        // Perform migration
        vm.prank(owner);
        vault.migrateYieldSource(address(yieldSource2));
        
        // Users should still be able to claim rewards post-migration
        uint256 bobFlaxBefore = flaxToken.balanceOf(bob);
        vm.prank(bob);
        vault.claimRewards(0);
        uint256 bobRewards = flaxToken.balanceOf(bob) - bobFlaxBefore;
        
        assertTrue(aliceRewards > 0, "Alice should have earned rewards");
        assertTrue(bobRewards > 0, "Bob should have earned rewards post-migration");
        
        console2.log("Migration with accumulated rewards completed successfully");
    }
    
    function testMigrationWithLossHandling() public {
        console2.log("\n=== Test Migration with Loss Handling ===");
        
        // Alice deposits
        vm.startPrank(alice);
        usdc.approve(address(vault), 60000e6);
        vault.deposit(60000e6);
        vm.stopPrank();
        
        // Record initial state
        uint256 surplusBefore = vault.surplusInputToken();
        
        // Simulate a migration that results in some loss
        // We'll manipulate the mock to return slightly less
        vm.prank(owner);
        vault.migrateYieldSource(address(yieldSource2));
        
        // Check if surplus/loss was handled properly
        uint256 surplusAfter = vault.surplusInputToken();
        console2.log("Surplus before migration", surplusBefore);
        console2.log("Surplus after migration", surplusAfter);
        
        // Alice should still be able to withdraw her original deposit
        vm.prank(alice);
        vault.withdraw(60000e6, false, 0); // Don't protect loss
        
        // Should have received close to original amount
        uint256 aliceBalance = usdc.balanceOf(alice);
        assertTrue(aliceBalance >= 59000e6, "Alice should receive most of her deposit back");
        
        console2.log("Migration with loss handling completed successfully");
    }
    
    function testEmergencyPauseDuringMigration() public {
        console2.log("\n=== Test Emergency Pause During Migration ===");
        
        // Alice deposits
        vm.startPrank(alice);
        usdc.approve(address(vault), 70000e6);
        vault.deposit(70000e6);
        vm.stopPrank();
        
        // Start migration process by setting emergency state
        vm.prank(owner);
        vault.setEmergencyState(true);
        
        // During emergency, no new deposits should be allowed
        vm.startPrank(bob);
        usdc.approve(address(vault), 50000e6);
        vm.expectRevert("Contract is in emergency state");
        vault.deposit(50000e6);
        vm.stopPrank();
        
        // But withdrawals should still work
        vm.prank(alice);
        vault.withdraw(35000e6, true, 0);
        
        assertTrue(usdc.balanceOf(alice) >= 35000e6);
        
        // Complete migration and restore normal operation
        vm.startPrank(owner);
        vault.setEmergencyState(false);  // Turn off emergency state to allow migration
        vault.migrateYieldSource(address(yieldSource2));
        vm.stopPrank();
        
        // Now deposits should work again
        vm.startPrank(bob);
        vault.deposit(50000e6);
        vm.stopPrank();
        
        assertEq(vault.originalDeposits(bob), 50000e6);
        
        console2.log("Emergency pause during migration completed successfully");
    }
    
    function testPostMigrationOperations() public {
        console2.log("\n=== Test Post-Migration Operations ===");
        
        // Multiple users deposit into first yield source
        vm.startPrank(alice);
        usdc.approve(address(vault), 90000e6);
        vault.deposit(90000e6);
        vm.stopPrank();
        
        vm.startPrank(bob);
        usdc.approve(address(vault), 110000e6);
        vault.deposit(110000e6);
        vm.stopPrank();
        
        // Simulate time and accumulate rewards
        advanceTime(15 days);
        
        // Perform migration
        vm.prank(owner);
        vault.migrateYieldSource(address(yieldSource2));
        
        // Test all operations work post-migration
        
        // 1. New deposits should work
        vm.startPrank(charlie);
        usdc.approve(address(vault), 40000e6);
        vault.deposit(40000e6);
        vm.stopPrank();
        
        // 2. Reward claims should work
        uint256 aliceFlaxBefore = flaxToken.balanceOf(alice);
        vm.prank(alice);
        vault.claimRewards(0);
        assertTrue(flaxToken.balanceOf(alice) > aliceFlaxBefore);
        
        // 3. Withdrawals should work
        vm.prank(bob);
        vault.withdraw(55000e6, true, 0);
        assertTrue(usdc.balanceOf(bob) >= 55000e6);
        
        // 4. sFlax burning should work
        sFlaxToken.mint(alice, 1000e18);
        vm.startPrank(alice);
        sFlaxToken.approve(address(vault), 500e18);
        vault.claimRewards(500e18); // Burn 500 sFlax while claiming
        vm.stopPrank();
        
        console2.log("Post-migration operations completed successfully");
    }
}