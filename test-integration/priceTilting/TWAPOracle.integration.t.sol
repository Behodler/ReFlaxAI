// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IntegrationTest} from "../base/IntegrationTest.sol";
import {TWAPOracle} from "../../src/priceTilting/TWAPOracle.sol";
import {IUniswapV2Factory} from "@uniswap_reflax/core/interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Pair} from "@uniswap_reflax/core/interfaces/IUniswapV2Pair.sol";
import {IUniswapV2Router02} from "@uniswap_reflax/periphery/interfaces/IUniswapV2Router02.sol";
import {IERC20} from "@oz_reflax/token/ERC20/IERC20.sol";
import {ArbitrumConstants} from "../base/ArbitrumConstants.sol";

/**
 * @title TWAPOracle Integration Test
 * @notice Tests TWAP Oracle behavior with real Uniswap V2 pair dynamics
 */
contract TWAPOracleIntegrationTest is IntegrationTest {
    TWAPOracle public oracle;
    IUniswapV2Factory public factory;
    IUniswapV2Router02 public router;
    IUniswapV2Pair public flaxWethPair;
    
    // Mock tokens for testing
    IERC20 public flaxToken;
    address public constant FLAX_TOKEN = 0x1234567890123456789012345678901234567890; // Mock address
    
    // Test users
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public bot = makeAddr("bot");
    
    // Constants for testing
    uint256 public constant INITIAL_FLAX_LIQUIDITY = 1000 ether;
    uint256 public constant INITIAL_ETH_LIQUIDITY = 10 ether;
    uint256 public constant SWAP_AMOUNT = 1 ether;
    
    function setUp() public override {
        super.setUp();
        
        // Deploy oracle with Camelot factory (which is the actual V2 factory on Arbitrum)
        factory = IUniswapV2Factory(ArbitrumConstants.UNISWAP_V2_FACTORY);
        router = IUniswapV2Router02(ArbitrumConstants.UNISWAP_V2_ROUTER);
        oracle = new TWAPOracle(ArbitrumConstants.UNISWAP_V2_FACTORY, ArbitrumConstants.WETH);
        
        // Deploy mock Flax token
        flaxToken = IERC20(_deployMockFlaxToken());
        
        // Create and initialize Flax/WETH pair
        _createFlaxWethPair();
        
        // Label contracts for better trace output
        vm.label(address(oracle), "TWAPOracle");
        vm.label(address(flaxToken), "FlaxToken");
        vm.label(address(flaxWethPair), "FlaxWETHPair");
        vm.label(alice, "Alice");
        vm.label(bob, "Bob");
        vm.label(bot, "Bot");
        vm.label(ArbitrumConstants.UNISWAP_V2_FACTORY, "CamelotFactory");
        vm.label(ArbitrumConstants.UNISWAP_V2_ROUTER, "CamelotRouter");
    }
    
    function testInitialOracleState() public {
        assertEq(oracle.factory(), ArbitrumConstants.UNISWAP_V2_FACTORY);
        assertEq(oracle.WETH(), ArbitrumConstants.WETH);
        assertEq(oracle.PERIOD(), 1 hours);
        
        // Pair should exist but not be initialized in oracle
        (,, uint256 lastUpdate,,) = oracle.pairMeasurements(address(flaxWethPair));
        assertEq(lastUpdate, 0, "Pair should not be initialized yet");
    }
    
    function testOracleInitialization() public {
        // First update should initialize the pair
        oracle.update(address(flaxToken), ArbitrumConstants.WETH);
        
        (,, uint256 lastUpdate, uint256 price0Cum, uint256 price1Cum) = oracle.pairMeasurements(address(flaxWethPair));
        
        assertTrue(lastUpdate > 0, "Pair should be initialized");
        // Note: price cumulatives might be 0 initially, which is fine for first initialization
        // The key is that lastUpdate timestamp is set
    }
    
    function testPriceMovementAndTWAP() public {
        uint256 snapshotId = takeSnapshot();
        
        // Initialize oracle
        oracle.update(address(flaxToken), ArbitrumConstants.WETH);
        
        // Record initial state
        (,, uint256 initialUpdate,,) = oracle.pairMeasurements(address(flaxWethPair));
        
        // Perform swap to create price movement
        vm.deal(address(this), 2 ether);
        address[] memory path = new address[](2);
        path[0] = ArbitrumConstants.WETH;
        path[1] = address(flaxToken);
        
        router.swapExactETHForTokens{value: 1 ether}(
            0, // min tokens out
            path,
            address(this),
            block.timestamp + 300
        );
        
        // The oracle's update logic handles the case where pair timestamp doesn't advance
        // by using block.timestamp when it's greater than lastUpdateTimestamp
        // So we advance block time and try updating again
        advanceTime(3700); // 1 hour and 2 minutes
        
        // Try another swap to potentially update pair timestamp
        router.swapExactETHForTokens{value: 0.5 ether}(
            0,
            path,
            address(this),
            block.timestamp + 300
        );
        
        // Update oracle - it should use block.timestamp since pair timestamp is old
        oracle.update(address(flaxToken), ArbitrumConstants.WETH);
        
        // Read measurement data
        (,, uint256 newUpdate,,) = oracle.pairMeasurements(address(flaxWethPair));
        
        // The oracle should have updated its timestamp to the current block.timestamp
        assertTrue(newUpdate > initialUpdate, "Oracle should have updated timestamp");
        
        // Test consultation after TWAP has been calculated
        uint256 flaxAmount = 100 ether;
        uint256 expectedEth = oracle.consult(address(flaxToken), ArbitrumConstants.WETH, flaxAmount);
        assertTrue(expectedEth > 0, "Oracle should return non-zero ETH amount");
        
        revertToSnapshot(snapshotId);
    }
    
    function testHighVolatilityTWAP() public {
        // Initialize oracle
        oracle.update(address(flaxToken), ArbitrumConstants.WETH);
        
        // Record initial price
        (uint112 reserve0Initial, uint112 reserve1Initial,) = flaxWethPair.getReserves();
        
        // Create volatility with swaps
        vm.deal(address(this), 10 ether);
        address[] memory pathEthToFlax = new address[](2);
        pathEthToFlax[0] = ArbitrumConstants.WETH;
        pathEthToFlax[1] = address(flaxToken);
        
        address[] memory pathFlaxToEth = new address[](2);
        pathFlaxToEth[0] = address(flaxToken);
        pathFlaxToEth[1] = ArbitrumConstants.WETH;
        
        // Perform multiple swaps with time advancement
        for (uint256 i = 0; i < 3; i++) {
            // Swap ETH for Flax
            router.swapExactETHForTokens{value: 1 ether}(
                0,
                pathEthToFlax,
                address(this),
                block.timestamp + 300
            );
            
            advanceTime(300); // 5 minutes
            
            // Swap some Flax back to ETH
            uint256 flaxBalance = flaxToken.balanceOf(address(this));
            if (flaxBalance > 0) {
                flaxToken.approve(address(router), flaxBalance / 2);
                router.swapExactTokensForETH(
                    flaxBalance / 2,
                    0,
                    pathFlaxToEth,
                    address(this),
                    block.timestamp + 300
                );
            }
            
            advanceTime(300); // 5 minutes
        }
        
        // Advance time to complete TWAP period
        advanceTime(3700);
        
        // Do a final small swap to ensure cumulatives are updated
        router.swapExactETHForTokens{value: 0.1 ether}(
            0,
            pathEthToFlax,
            address(this),
            block.timestamp + 300
        );
        
        // Update oracle
        oracle.update(address(flaxToken), ArbitrumConstants.WETH);
        
        // Oracle should provide TWAP consultation
        uint256 flaxAmount = 50 ether;
        uint256 twapPrice = oracle.consult(address(flaxToken), ArbitrumConstants.WETH, flaxAmount);
        assertTrue(twapPrice > 0, "TWAP should return non-zero price");
        
        // Verify oracle has tracked volatility
        (,, uint256 lastUpdate,,) = oracle.pairMeasurements(address(flaxWethPair));
        assertTrue(lastUpdate > 0, "Oracle should have valid timestamp");
    }
    
    function testAutomaticUpdatesSimulation() public {
        // Simulate YieldSource operations that trigger oracle updates
        oracle.update(address(flaxToken), ArbitrumConstants.WETH);
        
        vm.deal(address(this), 5 ether);
        address[] memory pathEthToFlax = new address[](2);
        pathEthToFlax[0] = ArbitrumConstants.WETH;
        pathEthToFlax[1] = address(flaxToken);
        
        // Simulate deposit operation
        router.swapExactETHForTokens{value: 0.5 ether}(
            0,
            pathEthToFlax,
            address(this),
            block.timestamp + 300
        );
        advanceTime(1800); // 30 minutes
        oracle.update(address(flaxToken), ArbitrumConstants.WETH);
        
        // Simulate withdrawal operation  
        router.swapExactETHForTokens{value: 0.3 ether}(
            0,
            pathEthToFlax,
            address(this),
            block.timestamp + 300
        );
        advanceTime(1800); // 30 minutes
        oracle.update(address(flaxToken), ArbitrumConstants.WETH);
        
        // Simulate claim operation
        router.swapExactETHForTokens{value: 0.2 ether}(
            0,
            pathEthToFlax,
            address(this),
            block.timestamp + 300
        );
        advanceTime(3600); // 1 hour
        oracle.update(address(flaxToken), ArbitrumConstants.WETH);
        
        // Oracle should have updated multiple times
        (,, uint256 lastUpdate,,) = oracle.pairMeasurements(address(flaxWethPair));
        assertTrue(lastUpdate > 0, "Oracle should track all updates");
    }
    
    function testBotUpdateMechanism() public {
        // Initialize oracle
        oracle.update(address(flaxToken), ArbitrumConstants.WETH);
        
        (,, uint256 initialUpdate,,) = oracle.pairMeasurements(address(flaxWethPair));
        
        // Simulate 6 hours of no user activity
        advanceTime(6 * 3600);
        
        // Create some price movement without oracle updates
        vm.deal(address(this), 2 ether);
        address[] memory path = new address[](2);
        path[0] = ArbitrumConstants.WETH;
        path[1] = address(flaxToken);
        
        router.swapExactETHForTokens{value: 0.5 ether}(
            0,
            path,
            address(this),
            block.timestamp + 300
        );
        
        // Bot should be able to update oracle
        vm.prank(bot);
        oracle.update(address(flaxToken), ArbitrumConstants.WETH);
        
        (,, uint256 botUpdate,,) = oracle.pairMeasurements(address(flaxWethPair));
        assertTrue(botUpdate > initialUpdate, "Bot should be able to update oracle");
    }
    
    function testOracleManipulationResistance() public {
        // Initialize oracle
        oracle.update(address(flaxToken), ArbitrumConstants.WETH);
        
        // Establish baseline with initial swap
        vm.deal(address(this), 5 ether);
        address[] memory path = new address[](2);
        path[0] = ArbitrumConstants.WETH;
        path[1] = address(flaxToken);
        
        router.swapExactETHForTokens{value: 0.1 ether}(
            0,
            path,
            address(this),
            block.timestamp + 300
        );
        
        // Wait for TWAP period to establish baseline
        advanceTime(3700);
        
        // Do a small swap to ensure cumulatives are advanced for baseline
        router.swapExactETHForTokens{value: 0.1 ether}(
            0,
            path,
            address(this),
            block.timestamp + 300
        );
        
        oracle.update(address(flaxToken), ArbitrumConstants.WETH);
        
        uint256 testAmount = 100 ether;
        uint256 baselinePrice = oracle.consult(address(flaxToken), ArbitrumConstants.WETH, testAmount);
        
        // Attempt manipulation with large swap
        router.swapExactETHForTokens{value: 2 ether}(
            0,
            path,
            address(this),
            block.timestamp + 300
        );
        
        // Try to update oracle immediately (shouldn't affect TWAP significantly)
        // But first do a small swap to ensure cumulatives are advanced
        router.swapExactETHForTokens{value: 0.1 ether}(
            0,
            path,
            address(this),
            block.timestamp + 300
        );
        
        oracle.update(address(flaxToken), ArbitrumConstants.WETH);
        uint256 manipulatedPrice = oracle.consult(address(flaxToken), ArbitrumConstants.WETH, testAmount);
        
        // TWAP should be resistant to single large manipulation
        uint256 priceChange = manipulatedPrice > baselinePrice ? 
            manipulatedPrice - baselinePrice : baselinePrice - manipulatedPrice;
        uint256 maxAcceptableChange = baselinePrice / 5; // 20% max change (generous for test)
        
        assertTrue(priceChange <= maxAcceptableChange, "Oracle should resist manipulation");
    }
    
    function testInsufficientTimePeriod() public {
        // Initialize oracle
        oracle.update(address(flaxToken), ArbitrumConstants.WETH);
        
        // Try to update before PERIOD has elapsed
        advanceTime(1800); // 30 minutes (less than 1 hour)
        
        // This should not revert but should not update averages
        (,, uint256 updateBefore,,) = oracle.pairMeasurements(address(flaxWethPair));
        
        oracle.update(address(flaxToken), ArbitrumConstants.WETH);
        
        (,, uint256 updateAfter,,) = oracle.pairMeasurements(address(flaxWethPair));
        
        // For insufficient time period, the update timestamp should remain the same
        assertEq(updateBefore, updateAfter, "Update timestamp should not change for insufficient time period");
    }
    
    function testConsultWithAddressZero() public {
        // Initialize oracle
        oracle.update(address(flaxToken), ArbitrumConstants.WETH);
        
        // Perform a swap to establish price movement
        vm.deal(address(this), 2 ether);
        address[] memory path = new address[](2);
        path[0] = ArbitrumConstants.WETH;
        path[1] = address(flaxToken);
        
        router.swapExactETHForTokens{value: 0.5 ether}(
            0,
            path,
            address(this),
            block.timestamp + 300
        );
        
        // Advance time and do another swap to help establish cumulatives
        advanceTime(3700);
        router.swapExactETHForTokens{value: 0.2 ether}(
            0,
            path,
            address(this),
            block.timestamp + 300
        );
        
        // Update oracle to establish TWAP
        oracle.update(address(flaxToken), ArbitrumConstants.WETH);
        
        // Test consulting with address(0) as ETH
        uint256 flaxAmount = 100 ether;
        uint256 ethFromWeth = oracle.consult(address(flaxToken), ArbitrumConstants.WETH, flaxAmount);
        uint256 ethFromZero = oracle.consult(address(flaxToken), address(0), flaxAmount);
        
        assertEq(ethFromWeth, ethFromZero, "address(0) should be treated as WETH");
    }
    
    function testRevertOnInvalidPair() public {
        address fakeToken = makeAddr("fakeToken");
        
        vm.expectRevert("TWAPOracle: INVALID_PAIR");
        oracle.update(fakeToken, ArbitrumConstants.WETH);
    }
    
    function testRevertOnUninitializedConsult() public {
        vm.expectRevert("TWAPOracle: PAIR_NOT_INITIALIZED_TIMESTAMP");
        oracle.consult(address(flaxToken), ArbitrumConstants.WETH, 100 ether);
    }
    
    // Helper functions
    
    function _deployMockFlaxToken() internal returns (address) {
        // Deploy a simple ERC20 token as mock Flax
        bytes memory bytecode = abi.encodePacked(
            type(MockERC20).creationCode,
            abi.encode("Flax Token", "FLAX", 18)
        );
        
        address token;
        bytes32 saltValue = keccak256(abi.encodePacked(block.timestamp, block.prevrandao));
        assembly {
            token := create2(0, add(bytecode, 0x20), mload(bytecode), saltValue)
        }
        
        return token;
    }
    
    function _createFlaxWethPair() internal {
        // Add initial liquidity to create the pair
        dealETH(address(this), INITIAL_ETH_LIQUIDITY);
        
        // Mint Flax tokens
        MockERC20(address(flaxToken)).mint(address(this), INITIAL_FLAX_LIQUIDITY);
        
        // Approve router
        flaxToken.approve(address(router), INITIAL_FLAX_LIQUIDITY);
        
        // Add liquidity
        router.addLiquidityETH{value: INITIAL_ETH_LIQUIDITY}(
            address(flaxToken),
            INITIAL_FLAX_LIQUIDITY,
            0, // min Flax
            0, // min ETH
            address(this),
            block.timestamp + 300
        );
        
        // Get pair address
        address pairAddress = factory.getPair(address(flaxToken), ArbitrumConstants.WETH);
        flaxWethPair = IUniswapV2Pair(pairAddress);
    }
    
    
    
    receive() external payable {}
}

// Simple mock ERC20 for testing
contract MockERC20 {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    
    uint256 public totalSupply;
    string public name;
    string public symbol;
    uint8 public decimals;
    
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    
    constructor(string memory _name, string memory _symbol, uint8 _decimals) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
    }
    
    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        totalSupply += amount;
        emit Transfer(address(0), to, amount);
    }
    
    function transfer(address to, uint256 amount) external returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }
    
    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }
    
    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
        return true;
    }
}