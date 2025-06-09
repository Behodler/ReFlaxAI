// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";

// Import core contracts
import "../../src/vault/Vault.sol";
import "../../src/yieldSource/CVX_CRV_YieldSource.sol";
import "../../src/priceTilting/PriceTilterTWAP.sol";
import "../../src/priceTilting/TWAPOracle.sol";

// Import interfaces
import "../../src/interfaces/IUniswapV3Router.sol";
import "../../lib/UniswapReFlax/core/interfaces/IUniswapV2Pair.sol";
import "../../lib/UniswapReFlax/periphery/interfaces/IUniswapV2Router02.sol";
import "../../src/yieldSource/AYieldSource.sol";

// Import mocks
import "../mocks/Mocks.sol";

/// @title BaseIntegration
/// @notice Base contract for integration tests providing complete system setup
abstract contract BaseIntegration is Test {
    // Core contracts
    Vault public vault;
    CVX_CRV_YieldSource public yieldSource;
    PriceTilterTWAP public priceTilter;
    TWAPOracle public oracle;
    
    // Mock tokens
    IntegrationMockERC20 public inputToken;
    IntegrationMockERC20 public poolToken1;
    IntegrationMockERC20 public poolToken2;
    IntegrationMockERC20 public lpToken;
    IntegrationMockERC20 public crvToken;
    IntegrationMockERC20 public cvxToken;
    IntegrationMockERC20 public flaxToken;
    IntegrationMockERC20 public sFlaxToken;
    
    // Mock external protocols
    MockCurvePool public curvePool;
    EnhancedMockConvexBooster public convexBooster;
    MockConvexRewardPool public convexRewardPool;
    MockUniswapV3Router public uniswapV3Router;
    IntegrationMockUniswapV2Router public uniswapV2Router;
    MockUniswapV2Factory public uniswapV2Factory;
    MockUniswapV2Pair public flaxEthPair;
    address public weth = address(0x1234); // Mock WETH address
    
    // Test users
    address public alice = address(0x1);
    address public bob = address(0x2);
    address public charlie = address(0x3);
    address public owner = address(this);
    
    // Constants
    uint256 constant INITIAL_FLAX_SUPPLY = 1_000_000e18;
    uint256 constant INITIAL_ETH_LIQUIDITY = 100 ether;
    uint256 constant INITIAL_FLAX_LIQUIDITY = 100_000e18;
    uint256 constant CONVEX_PID = 1;
    
    function setUp() public virtual {
        // Deploy mock tokens
        _deployMockTokens();
        
        // Deploy mock external protocols
        _deployMockProtocols();
        
        // Deploy core contracts
        _deployCore();
        
        // Configure system
        _configureSystem();
        
        // Fund contracts
        _fundContracts();
        
        // Label addresses for better test output
        _labelAddresses();
    }
    
    function _deployMockTokens() internal {
        inputToken = new IntegrationMockERC20("USD Coin", "USDC", 6);
        poolToken1 = inputToken; // Use same token instance since both are USDC
        poolToken2 = new IntegrationMockERC20("Tether", "USDT", 6);
        lpToken = new IntegrationMockERC20("Curve LP", "crvLP", 18);
        crvToken = new IntegrationMockERC20("Curve", "CRV", 18);
        cvxToken = new IntegrationMockERC20("Convex", "CVX", 18);
        flaxToken = new IntegrationMockERC20("Flax", "FLAX", 18);
        sFlaxToken = new IntegrationMockERC20("Staked Flax", "sFLAX", 18);
    }
    
    function _deployMockProtocols() internal {
        // Deploy Curve pool
        curvePool = new MockCurvePool(address(lpToken));
        
        // Deploy Convex booster and reward pool
        convexBooster = new EnhancedMockConvexBooster();
        convexBooster.setLPToken(address(lpToken));
        convexRewardPool = new MockConvexRewardPool(address(crvToken));
        convexBooster.setRewardPool(address(convexRewardPool));
        
        // Deploy Uniswap V3 router
        uniswapV3Router = new MockUniswapV3Router();
        
        // Deploy Uniswap V2 factory, router and Flax/ETH pair
        uniswapV2Factory = new MockUniswapV2Factory();
        uniswapV2Router = new IntegrationMockUniswapV2Router();
        flaxEthPair = new MockUniswapV2Pair(address(flaxToken), weth);
        
        // Register pair in factory
        uniswapV2Factory.setPair(address(flaxToken), weth, address(flaxEthPair));
        
        // Initialize Flax/ETH pair with liquidity
        flaxToken.mint(address(flaxEthPair), INITIAL_FLAX_LIQUIDITY);
        vm.deal(address(flaxEthPair), INITIAL_ETH_LIQUIDITY);
        flaxEthPair.updateReserves(uint112(INITIAL_FLAX_LIQUIDITY), uint112(INITIAL_ETH_LIQUIDITY), 1);
        
        // Create and register additional pairs needed by YieldSource
        // USDC/ETH pair (input token)
        MockUniswapV2Pair usdcEthPair = new MockUniswapV2Pair(address(inputToken), weth);
        uniswapV2Factory.setPair(address(inputToken), weth, address(usdcEthPair));
        inputToken.mint(address(usdcEthPair), 1_000_000e6); // 1M USDC
        vm.deal(address(usdcEthPair), 1000 ether); // 1000 ETH
        usdcEthPair.updateReserves(uint112(1_000_000e6), uint112(1000 ether), 1);
        
        // USDT/ETH pair (pool token 2)
        MockUniswapV2Pair usdtEthPair = new MockUniswapV2Pair(address(poolToken2), weth);
        uniswapV2Factory.setPair(address(poolToken2), weth, address(usdtEthPair));
        poolToken2.mint(address(usdtEthPair), 1_000_000e6); // 1M USDT
        vm.deal(address(usdtEthPair), 1000 ether); // 1000 ETH
        usdtEthPair.updateReserves(uint112(1_000_000e6), uint112(1000 ether), 1);
        
        // CRV/ETH pair (reward token)
        MockUniswapV2Pair crvEthPair = new MockUniswapV2Pair(address(crvToken), weth);
        uniswapV2Factory.setPair(address(crvToken), weth, address(crvEthPair));
        crvToken.mint(address(crvEthPair), 2_000_000e18); // 2M CRV
        vm.deal(address(crvEthPair), 1000 ether); // 1000 ETH
        crvEthPair.updateReserves(uint112(2_000_000e18), uint112(1000 ether), 1);
        
        // CVX/ETH pair (reward token)
        MockUniswapV2Pair cvxEthPair = new MockUniswapV2Pair(address(cvxToken), weth);
        uniswapV2Factory.setPair(address(cvxToken), weth, address(cvxEthPair));
        cvxToken.mint(address(cvxEthPair), 3_000_000e18); // 3M CVX
        vm.deal(address(cvxEthPair), 1000 ether); // 1000 ETH
        cvxEthPair.updateReserves(uint112(3_000_000e18), uint112(1000 ether), 1);
        
        // USDC/USDT pair for direct swaps in YieldSource
        MockUniswapV2Pair usdcUsdtPair = new MockUniswapV2Pair(address(inputToken), address(poolToken2));
        uniswapV2Factory.setPair(address(inputToken), address(poolToken2), address(usdcUsdtPair));
        inputToken.mint(address(usdcUsdtPair), 1_000_000e6); // 1M USDC
        poolToken2.mint(address(usdcUsdtPair), 1_000_000e6); // 1M USDT
        // Initialize with timestamp 1 to allow cumulative price calculation
        usdcUsdtPair.updateReserves(uint112(1_000_000e6), uint112(1_000_000e6), 1);
    }
    
    function _deployCore() internal {
        // Deploy oracle
        oracle = new TWAPOracle(address(uniswapV2Factory), weth);
        
        // Deploy price tilter  
        priceTilter = new PriceTilterTWAP(
            address(uniswapV2Factory),
            address(uniswapV2Router),
            address(flaxToken),
            address(oracle)
        );
        priceTilter.setPriceTiltRatio(8000); // 80% tilt ratio
        
        // Deploy yield source
        address[] memory poolTokenAddresses = new address[](2);
        poolTokenAddresses[0] = address(poolToken1);
        poolTokenAddresses[1] = address(poolToken2);
        
        string[] memory poolTokenSymbols = new string[](2);
        poolTokenSymbols[0] = "USDC";
        poolTokenSymbols[1] = "USDT";
        
        address[] memory rewardTokenAddresses = new address[](2);
        rewardTokenAddresses[0] = address(crvToken);
        rewardTokenAddresses[1] = address(cvxToken);
        
        yieldSource = new CVX_CRV_YieldSource(
            address(inputToken),
            address(flaxToken),
            address(priceTilter),
            address(oracle),
            "Curve USDC/USDT LP",
            address(curvePool),
            address(lpToken),
            address(convexBooster),
            address(convexRewardPool),
            CONVEX_PID,
            address(uniswapV3Router),
            poolTokenAddresses,
            poolTokenSymbols,
            rewardTokenAddresses
        );
        
        // Deploy vault (concrete implementation for testing)
        vault = new TestVault(
            address(flaxToken),
            address(sFlaxToken),
            address(inputToken),
            address(yieldSource),
            address(priceTilter)
        );
        vault.setFlaxPerSFlax(1e18); // 1:1 flax per sFlax ratio
    }
    
    function _configureSystem() internal {
        // Configure Curve pool with pool tokens
        address[] memory curvePoolTokens = new address[](2);
        curvePoolTokens[0] = address(poolToken1);
        curvePoolTokens[1] = address(poolToken2);
        curvePool.setPoolTokens(curvePoolTokens);
        
        // Approve Curve pool to spend tokens from YieldSource
        vm.startPrank(address(yieldSource));
        poolToken1.approve(address(curvePool), type(uint256).max);
        poolToken2.approve(address(curvePool), type(uint256).max);
        vm.stopPrank();
        
        // Initialize all required pairs in oracle by updating them
        oracle.update(address(flaxToken), weth);
        oracle.update(address(inputToken), weth);
        oracle.update(address(poolToken2), weth);
        oracle.update(address(crvToken), weth);
        oracle.update(address(cvxToken), weth);
        oracle.update(address(inputToken), address(poolToken2)); // USDC/USDT pair
        
        // Register Flax/ETH pair in price tilter
        // Note: PriceTilter doesn't have registerPair, pairs are registered via oracle
        
        // Whitelist the vault in the yield source
        yieldSource.whitelistVault(address(vault), true);
        
        // Set underlying weights for the Curve pool
        uint256[] memory weights = new uint256[](2);
        weights[0] = 5000; // 50% USDC
        weights[1] = 5000; // 50% USDT
        yieldSource.setUnderlyingWeights(address(curvePool), weights);
        
        // Configure Uniswap V3 router prices using specific return amounts
        uniswapV3Router.setSpecificReturnAmount(address(inputToken), address(poolToken1), 1e6, 1e6); // 1:1
        uniswapV3Router.setSpecificReturnAmount(address(inputToken), address(poolToken2), 1e6, 1e6); // 1:1
        uniswapV3Router.setSpecificReturnAmount(address(crvToken), address(0), 1e18, 0.0005 ether); // 1 CRV = 0.0005 ETH
        uniswapV3Router.setSpecificReturnAmount(address(cvxToken), address(0), 1e18, 0.0003 ether); // 1 CVX = 0.0003 ETH
    }
    
    function _fundContracts() internal {
        // Fund vault with Flax for rewards
        flaxToken.mint(address(vault), INITIAL_FLAX_SUPPLY);
        
        // Fund price tilter with initial ETH
        vm.deal(address(priceTilter), 10 ether);
        
        // Fund Uniswap routers for swaps
        vm.deal(address(uniswapV3Router), 100 ether);
        poolToken1.mint(address(uniswapV3Router), 1_000_000e6);
        poolToken2.mint(address(uniswapV3Router), 1_000_000e6);
    }
    
    function _labelAddresses() internal {
        vm.label(alice, "Alice");
        vm.label(bob, "Bob");
        vm.label(charlie, "Charlie");
        vm.label(address(vault), "Vault");
        vm.label(address(yieldSource), "YieldSource");
        vm.label(address(priceTilter), "PriceTilter");
        vm.label(address(oracle), "Oracle");
        vm.label(address(inputToken), "USDC");
        vm.label(address(flaxToken), "FLAX");
        vm.label(address(sFlaxToken), "sFLAX");
    }
    
    // Helper functions for tests
    
    function setupUser(address user, uint256 inputTokenBalance) public {
        inputToken.mint(user, inputTokenBalance);
        vm.prank(user);
        inputToken.approve(address(vault), type(uint256).max);
    }
    
    function setupUserWithSFlax(address user, uint256 inputTokenBalance, uint256 sFlaxBalance) public {
        setupUser(user, inputTokenBalance);
        sFlaxToken.mint(user, sFlaxBalance);
        vm.prank(user);
        sFlaxToken.approve(address(vault), type(uint256).max);
    }
    
    function executeDeposit(address user, uint256 amount) public {
        uint256 balanceBefore = inputToken.balanceOf(user);
        vm.prank(user);
        vault.deposit(amount);
        assertEq(inputToken.balanceOf(user), balanceBefore - amount, "User balance not decreased");
    }
    
    function executeWithdrawal(address user, uint256 amount, bool protectLoss) public {
        vm.prank(user);
        vault.withdraw(amount, protectLoss, 0); // No sFlax burn
    }
    
    function executeClaimReward(address user) public returns (uint256) {
        uint256 flaxBefore = flaxToken.balanceOf(user);
        vm.prank(user);
        vault.claimRewards(0); // No sFlax burn
        uint256 flaxAfter = flaxToken.balanceOf(user);
        return flaxAfter - flaxBefore;
    }
    
    function simulateRewardAccrual(uint256 crvAmount, uint256 cvxAmount) public {
        // Mint rewards to Convex reward pool to simulate accrual
        crvToken.mint(address(convexRewardPool), crvAmount);
        cvxToken.mint(address(convexRewardPool), cvxAmount);
    }
    
    function advanceTime(uint256 seconds_) public {
        vm.warp(block.timestamp + seconds_);
        // Update oracle after time advance
        oracle.update(address(flaxToken), weth);
    }
    
    // Assertion helpers
    
    function assertTokenBalance(address token, address holder, uint256 expected, string memory message) public {
        assertEq(IERC20(token).balanceOf(holder), expected, message);
    }
    
    function assertVaultState(
        uint256 expectedTotalDeposits,
        uint256 expectedSurplus,
        string memory message
    ) public {
        assertEq(vault.totalDeposits(), expectedTotalDeposits, string.concat(message, " - totalDeposits"));
        assertEq(vault.surplusInputToken(), expectedSurplus, string.concat(message, " - surplus"));
    }
    
    function assertUserDeposit(address user, uint256 expected, string memory message) public {
        assertEq(vault.originalDeposits(user), expected, message);
    }
    
    function assertApproxEq(uint256 actual, uint256 expected, uint256 tolerance, string memory message) public {
        uint256 diff = actual > expected ? actual - expected : expected - actual;
        assertTrue(diff <= tolerance, string.concat(message, " - difference exceeds tolerance"));
    }
}

// Concrete Vault implementation for testing
contract TestVault is Vault {
    constructor(
        address _flaxToken,
        address _sFlaxToken,
        address _inputToken,
        address _yieldSource,
        address _priceTilter
    ) Vault(_flaxToken, _sFlaxToken, _inputToken, _yieldSource, _priceTilter) {}
    
    function canWithdraw(address) public pure returns (bool) {
        return true;
    }
}

// Enhanced mocks for integration tests

// Mock ERC20 with configurable properties
contract IntegrationMockERC20 is MockERC20 {
    constructor(string memory _name, string memory _symbol, uint8 _decimals) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
    }
}

// Mock Uniswap V2 Router for Integration Tests
contract IntegrationMockUniswapV2Router is IUniswapV2Router02 {
    function factory() external pure returns (address) {
        return address(0);
    }
    
    function WETH() external pure returns (address) {
        return address(0);
    }
    
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity) {
        // Simple mock: accept tokens and ETH, return same amounts
        IERC20(token).transferFrom(msg.sender, address(this), amountTokenDesired);
        return (amountTokenDesired, msg.value, amountTokenDesired + msg.value);
    }
    
    // Implement other required functions with minimal logic
    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountToken, uint amountETH) {
        return (0, 0);
    }
    
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity) {
        return (amountADesired, amountBDesired, amountADesired + amountBDesired);
    }
    
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB) {
        return (0, 0);
    }
    
    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountA, uint amountB) {
        return (0, 0);
    }
    
    function removeLiquidityETHWithPermit(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountToken, uint amountETH) {
        return (0, 0);
    }
    
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts) {
        amounts = new uint[](path.length);
        amounts[0] = amountIn;
        amounts[path.length - 1] = amountIn;
        return amounts;
    }
    
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts) {
        amounts = new uint[](path.length);
        return amounts;
    }
    
    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts) {
        amounts = new uint[](path.length);
        return amounts;
    }
    
    function swapTokensForExactETH(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts) {
        amounts = new uint[](path.length);
        return amounts;
    }
    
    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts) {
        amounts = new uint[](path.length);
        return amounts;
    }
    
    function swapETHForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts) {
        amounts = new uint[](path.length);
        return amounts;
    }
    
    function quote(uint amountA, uint reserveA, uint reserveB) external pure returns (uint amountB) {
        return (amountA * reserveB) / reserveA;
    }
    
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) external pure returns (uint amountOut) {
        uint amountInWithFee = amountIn * 997;
        uint numerator = amountInWithFee * reserveOut;
        uint denominator = (reserveIn * 1000) + amountInWithFee;
        return numerator / denominator;
    }
    
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) external pure returns (uint amountIn) {
        uint numerator = reserveIn * amountOut * 1000;
        uint denominator = (reserveOut - amountOut) * 997;
        return (numerator / denominator) + 1;
    }
    
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts) {
        amounts = new uint[](path.length);
        amounts[0] = amountIn;
        amounts[path.length - 1] = amountIn;
        return amounts;
    }
    
    function getAmountsIn(uint amountOut, address[] calldata path) external view returns (uint[] memory amounts) {
        amounts = new uint[](path.length);
        return amounts;
    }
    
    // Implement required functions from IUniswapV2Router01
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountETH) {
        return 0;
    }
    
    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountETH) {
        return 0;
    }
    
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external {}
    
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable {}
    
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external {}
    
    receive() external payable {}
}

// Enhanced MockConvexBooster with more functionality
contract EnhancedMockConvexBooster {
    mapping(address => uint256) public balances;
    address public rewardPool;
    address public lpToken;
    
    function setRewardPool(address _rewardPool) external {
        rewardPool = _rewardPool;
    }
    
    function setLPToken(address _lpToken) external {
        lpToken = _lpToken;
    }
    
    function deposit(uint256 pid, uint256 amount, bool stake) external returns (bool) {
        // Transfer LP tokens from sender
        if (lpToken != address(0)) {
            IERC20(lpToken).transferFrom(msg.sender, address(this), amount);
        }
        balances[msg.sender] += amount;
        return true;
    }
    
    function withdraw(uint256 pid, uint256 amount) external returns (bool) {
        require(balances[msg.sender] >= amount, "Insufficient balance");
        balances[msg.sender] -= amount;
        // Transfer LP tokens back
        if (lpToken != address(0)) {
            IERC20(lpToken).transfer(msg.sender, amount);
        }
        return true;
    }
    
    function balanceOf(address account) external view returns (uint256) {
        return balances[account];
    }
    
    function poolInfo(uint256) external view returns (
        address lptoken,
        address token,
        address gauge,
        address crvRewards,
        address stash,
        bool shutdown
    ) {
        return (lpToken, address(0), address(0), rewardPool, address(0), false);
    }
}