// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IntegrationTest} from "../base/IntegrationTest.sol";
import {ArbitrumConstants} from "../base/ArbitrumConstants.sol";
import {IERC20} from "@oz_reflax/token/ERC20/IERC20.sol";
import {console2} from "forge-std/console2.sol";

// Mock ERC20 with comprehensive functionality
contract MockERC20Simple {
    string public name;
    string public symbol;
    uint8 public decimals;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    constructor(string memory _name, string memory _symbol, uint8 _decimals) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
    }

    function mint(address to, uint256 amount) external {
        totalSupply += amount;
        balanceOf[to] += amount;
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
        if (allowance[from][msg.sender] != type(uint256).max) {
            allowance[from][msg.sender] -= amount;
        }
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
        return true;
    }

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

// Simplified yield source that focuses on slippage protection testing
contract SimpleSlippageYieldSource {
    address public inputToken;
    address public flaxToken;
    
    uint256 public minSlippageBps = 100; // 1% default
    uint256 public totalDeposited;
    
    mapping(address => bool) public whitelistedVaults;
    
    event MinSlippageBpsUpdated(uint256 newSlippageBps);
    
    modifier onlyWhitelistedVault() {
        require(whitelistedVaults[msg.sender], "Not whitelisted");
        _;
    }
    
    constructor(address _inputToken, address _flaxToken) {
        inputToken = _inputToken;
        flaxToken = _flaxToken;
    }
    
    function whitelistVault(address vault, bool status) external {
        whitelistedVaults[vault] = status;
    }
    
    function setMinSlippageBps(uint256 newSlippageBps) external {
        require(newSlippageBps <= 10000, "Slippage too high");
        minSlippageBps = newSlippageBps;
        emit MinSlippageBpsUpdated(newSlippageBps);
    }
    
    function deposit(uint256 amount) external onlyWhitelistedVault returns (uint256) {
        IERC20(inputToken).transferFrom(msg.sender, address(this), amount);
        
        // Simulate realistic slippage based on deposit size
        uint256 slippageBps = _calculateSlippage(amount);
        
        // Check slippage protection
        require(slippageBps <= minSlippageBps, "Slippage exceeds tolerance");
        
        totalDeposited += amount;
        
        console2.log("Deposit successful - Amount:", amount, "Slippage (bps):", slippageBps);
        return amount;
    }
    
    function withdraw(uint256 amount) external onlyWhitelistedVault returns (uint256) {
        require(totalDeposited >= amount, "Insufficient deposits");
        
        // Simulate small withdrawal slippage
        uint256 actualReceived = amount * 9990 / 10000; // 0.1% slippage
        totalDeposited -= amount;
        
        IERC20(inputToken).transfer(msg.sender, actualReceived);
        return actualReceived;
    }
    
    function _calculateSlippage(uint256 amount) internal pure returns (uint256) {
        // Simulate realistic slippage: small deposits have low slippage, large ones have higher
        if (amount > 10000e6) {        // > 10k USDC
            return 150;                // 1.5% slippage
        } else if (amount > 5000e6) {  // > 5k USDC  
            return 80;                 // 0.8% slippage
        } else if (amount > 1000e6) {  // > 1k USDC
            return 50;                 // 0.5% slippage
        } else {
            return 20;                 // 0.2% slippage for small amounts
        }
    }
}

/**
 * @title Simple Slippage Protection Integration Test
 * @notice Focused test of slippage protection with minimal complexity
 */
contract SlippageProtectionSimpleIntegrationTest is IntegrationTest {
    SimpleSlippageYieldSource public yieldSource;
    MockERC20Simple public flaxToken;
    
    address public alice = address(0x1111);
    
    function setUp() public override {
        super.setUp();
        
        console2.log("Setting up Simple Slippage Protection Integration Test...");
        
        // Deploy Flax token
        flaxToken = new MockERC20Simple("Flax Token", "FLAX", 18);
        vm.label(address(flaxToken), "FlaxToken");
        
        // Deploy simplified yield source
        yieldSource = new SimpleSlippageYieldSource(
            ArbitrumConstants.USDC,
            address(flaxToken)
        );
        vm.label(address(yieldSource), "YieldSource");
        
        // Whitelist ourselves for testing
        yieldSource.whitelistVault(address(this), true);
        
        // Setup user with USDC
        dealUSDC(alice, 100_000e6); // 100k USDC
        
        console2.log("Setup complete");
    }
    
    function testDepositWithAcceptableSlippage() public {
        console2.log("\n=== Testing Deposit with Acceptable Slippage ===");
        
        // Set reasonable slippage tolerance
        yieldSource.setMinSlippageBps(100); // 1%
        
        // Transfer USDC to this contract for testing
        vm.prank(alice);
        usdc.transfer(address(this), 1000e6);
        
        // Approve and deposit
        usdc.approve(address(yieldSource), 1000e6);
        
        uint256 result = yieldSource.deposit(1000e6);
        assertTrue(result > 0, "Deposit should succeed");
        
        console2.log("Deposit succeeded with acceptable slippage");
    }
    
    function testDepositRejectsExcessiveSlippage() public {
        console2.log("\n=== Testing Deposit Rejects Excessive Slippage ===");
        
        // Set very tight slippage tolerance
        yieldSource.setMinSlippageBps(50); // 0.5%
        
        // Transfer large amount to trigger higher slippage
        vm.prank(alice);
        usdc.transfer(address(this), 15000e6); // 15k USDC
        
        // Approve
        usdc.approve(address(yieldSource), 15000e6);
        
        // This large deposit should exceed slippage tolerance (1.5% > 0.5%)
        vm.expectRevert("Slippage exceeds tolerance");
        yieldSource.deposit(15000e6);
        
        console2.log("Large deposit correctly rejected due to excessive slippage");
        
        // Verify we can deposit with higher tolerance
        yieldSource.setMinSlippageBps(200); // 2%
        uint256 result = yieldSource.deposit(10000e6);
        assertTrue(result > 0, "Should succeed with higher tolerance");
        
        console2.log("Deposit succeeded with adjusted tolerance");
    }
    
    function testSlippageScaling() public {
        console2.log("\n=== Testing Slippage Scaling ===");
        
        // Set tight tolerance that allows small/medium deposits but blocks large ones
        yieldSource.setMinSlippageBps(70); // 0.7%
        
        // Test small deposit (should have low slippage: 0.2%)
        vm.prank(alice);
        usdc.transfer(address(this), 20000e6);
        usdc.approve(address(yieldSource), 20000e6);
        
        uint256 result1 = yieldSource.deposit(500e6); // Small amount -> 0.2% slippage
        assertTrue(result1 > 0, "Small deposit should succeed");
        
        uint256 result2 = yieldSource.deposit(2000e6); // Medium amount -> 0.5% slippage
        assertTrue(result2 > 0, "Medium deposit should succeed");
        
        // Large deposit should fail with 0.7% tolerance (simulates 0.8% slippage for >5k)
        vm.expectRevert("Slippage exceeds tolerance");
        yieldSource.deposit(6000e6); // This amount is > 5k, triggering 0.8% slippage which exceeds 0.7% limit
        
        console2.log("Slippage scaling working correctly");
    }
}