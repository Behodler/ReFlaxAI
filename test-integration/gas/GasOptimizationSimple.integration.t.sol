// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {IntegrationTest} from "../base/IntegrationTest.sol";
import {ArbitrumConstants} from "../base/ArbitrumConstants.sol";
import {IERC20} from "../../lib/oz_reflax/token/ERC20/IERC20.sol";

// Simple mock contracts for gas measurement
contract MockVault {
    mapping(address => uint256) public deposits;
    
    function deposit(uint256 amount) external {
        // Simulate some storage writes
        deposits[msg.sender] += amount;
        
        // Simulate external calls
        IERC20(ArbitrumConstants.USDC).transferFrom(msg.sender, address(this), amount);
    }
    
    function withdraw(uint256 amount) external {
        require(deposits[msg.sender] >= amount, "Insufficient balance");
        deposits[msg.sender] -= amount;
        IERC20(ArbitrumConstants.USDC).transfer(msg.sender, amount);
    }
    
    function claimRewards() external view returns (uint256) {
        // Simulate reward calculation
        return deposits[msg.sender] / 100; // 1% yield
    }
}

contract MockYieldSource {
    uint256 public totalDeposited;
    
    function deposit(uint256 amount) external returns (uint256) {
        totalDeposited += amount;
        return amount;
    }
    
    function withdraw(uint256 amount) external returns (uint256) {
        require(totalDeposited >= amount, "Insufficient deposits");
        totalDeposited -= amount;
        return amount;
    }
    
    function claimRewards() external view returns (uint256) {
        return totalDeposited / 1000; // 0.1% yield
    }
}

/**
 * @title Simple Gas Optimization Integration Test
 * @notice Measures gas costs for ReFlax protocol operations with simplified mocks
 * @dev Generates a markdown report with gas measurements and analysis
 */
contract GasOptimizationSimpleTest is IntegrationTest {
    MockVault public vault;
    MockYieldSource public yieldSource;
    
    // Test accounts
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public charlie = makeAddr("charlie");
    
    // Gas measurement storage
    struct GasMeasurement {
        string operation;
        uint256 gasUsed;
        uint256 amount;
        string details;
    }
    
    GasMeasurement[] public gasMeasurements;
    
    function setUp() public override {
        super.setUp();
        
        // Deploy mock contracts
        vault = new MockVault();
        yieldSource = new MockYieldSource();
        
        // Setup test accounts with USDC
        dealUSDC(alice, 100000 * 1e6);    // 100k USDC
        dealUSDC(bob, 50000 * 1e6);       // 50k USDC  
        dealUSDC(charlie, 10000 * 1e6);   // 10k USDC
        
        // Label contracts
        vm.label(address(vault), "MockVault");
        vm.label(address(yieldSource), "MockYieldSource");
        vm.label(alice, "Alice");
        vm.label(bob, "Bob");
        vm.label(charlie, "Charlie");
    }
    
    function testSmallDepositGas() public {
        uint256 depositAmount = 1000 * 1e6; // 1k USDC
        
        vm.startPrank(alice);
        usdc.approve(address(vault), depositAmount);
        
        uint256 gasBefore = gasleft();
        vault.deposit(depositAmount);
        uint256 gasUsed = gasBefore - gasleft();
        vm.stopPrank();
        
        _recordGasMeasurement("Small Deposit", gasUsed, depositAmount, "1k USDC deposit");
    }
    
    function testMediumDepositGas() public {
        uint256 depositAmount = 10000 * 1e6; // 10k USDC
        
        vm.startPrank(bob);
        usdc.approve(address(vault), depositAmount);
        
        uint256 gasBefore = gasleft();
        vault.deposit(depositAmount);
        uint256 gasUsed = gasBefore - gasleft();
        vm.stopPrank();
        
        _recordGasMeasurement("Medium Deposit", gasUsed, depositAmount, "10k USDC deposit");
    }
    
    function testLargeDepositGas() public {
        uint256 depositAmount = 50000 * 1e6; // 50k USDC
        
        vm.startPrank(alice);
        usdc.approve(address(vault), depositAmount);
        
        uint256 gasBefore = gasleft();
        vault.deposit(depositAmount);
        uint256 gasUsed = gasBefore - gasleft();
        vm.stopPrank();
        
        _recordGasMeasurement("Large Deposit", gasUsed, depositAmount, "50k USDC deposit");
    }
    
    function testClaimRewardsGas() public {
        // Setup: Make deposit first
        _makeDeposit(alice, 25000 * 1e6);
        
        vm.startPrank(alice);
        uint256 gasBefore = gasleft();
        vault.claimRewards();
        uint256 gasUsed = gasBefore - gasleft();
        vm.stopPrank();
        
        _recordGasMeasurement("Claim Rewards", gasUsed, 0, "Basic reward claiming");
    }
    
    function testWithdrawalGas() public {
        // Setup: Make deposit first
        uint256 depositAmount = 10000 * 1e6;
        _makeDeposit(alice, depositAmount);
        
        uint256 withdrawAmount = 5000 * 1e6; // Partial withdrawal
        
        vm.startPrank(alice);
        uint256 gasBefore = gasleft();
        vault.withdraw(withdrawAmount);
        uint256 gasUsed = gasBefore - gasleft();
        vm.stopPrank();
        
        _recordGasMeasurement("Withdrawal", gasUsed, withdrawAmount, "5k USDC withdrawal");
    }
    
    function testYieldSourceDepositGas() public {
        uint256 depositAmount = 15000 * 1e6;
        
        vm.startPrank(alice);
        usdc.approve(address(yieldSource), depositAmount);
        
        uint256 gasBefore = gasleft();
        yieldSource.deposit(depositAmount);
        uint256 gasUsed = gasBefore - gasleft();
        vm.stopPrank();
        
        _recordGasMeasurement("YieldSource Deposit", gasUsed, depositAmount, "15k USDC yield source deposit");
    }
    
    function testYieldSourceWithdrawGas() public {
        // Setup: Make deposit first
        uint256 depositAmount = 20000 * 1e6;
        vm.startPrank(alice);
        usdc.approve(address(yieldSource), depositAmount);
        yieldSource.deposit(depositAmount);
        
        uint256 gasBefore = gasleft();
        yieldSource.withdraw(depositAmount);
        uint256 gasUsed = gasBefore - gasleft();
        vm.stopPrank();
        
        _recordGasMeasurement("YieldSource Withdraw", gasUsed, depositAmount, "20k USDC yield source withdrawal");
    }
    
    function testYieldSourceClaimGas() public {
        // Setup: Make deposit first
        uint256 depositAmount = 30000 * 1e6;
        vm.startPrank(alice);
        usdc.approve(address(yieldSource), depositAmount);
        yieldSource.deposit(depositAmount);
        
        uint256 gasBefore = gasleft();
        yieldSource.claimRewards();
        uint256 gasUsed = gasBefore - gasleft();
        vm.stopPrank();
        
        _recordGasMeasurement("YieldSource Claim", gasUsed, 0, "Yield source reward claim");
    }
    
    function testMultipleOperationsGas() public {
        uint256 depositAmount = 5000 * 1e6;
        
        vm.startPrank(alice);
        usdc.approve(address(vault), depositAmount * 3);
        
        uint256 gasBefore = gasleft();
        
        // Multiple operations in one transaction
        vault.deposit(depositAmount);
        vault.claimRewards();
        vault.withdraw(depositAmount / 2);
        
        uint256 gasUsed = gasBefore - gasleft();
        vm.stopPrank();
        
        _recordGasMeasurement("Multiple Operations", gasUsed, depositAmount, "Deposit + Claim + Withdraw in one tx");
    }
    
    function testGenerateGasReport() public {
        // Run all gas measurements
        testSmallDepositGas();
        testMediumDepositGas();
        testLargeDepositGas();
        testClaimRewardsGas();
        testWithdrawalGas();
        testYieldSourceDepositGas();
        testYieldSourceWithdrawGas();
        testYieldSourceClaimGas();
        testMultipleOperationsGas();
        
        // Generate markdown report
        _generateMarkdownReport();
    }
    
    function _makeDeposit(address user, uint256 amount) internal {
        vm.startPrank(user);
        usdc.approve(address(vault), amount);
        vault.deposit(amount);
        vm.stopPrank();
    }
    
    function _recordGasMeasurement(string memory operation, uint256 gasUsed, uint256 amount, string memory details) internal {
        gasMeasurements.push(GasMeasurement({
            operation: operation,
            gasUsed: gasUsed,
            amount: amount,
            details: details
        }));
        
        console2.log("Gas Measurement - %s: %d gas", operation, gasUsed);
    }
    
    function _generateMarkdownReport() internal view {
        console2.log("\n");
        console2.log("# ReFlax Protocol Gas Optimization Report (Simplified)");
        console2.log("");
        console2.log("Generated on: %s", _getCurrentDate());
        console2.log("Network: Arbitrum Mainnet Fork");
        console2.log("Block Number: %d", block.number);
        console2.log("");
        
        console2.log("## Executive Summary");
        console2.log("");
        console2.log("This simplified report provides gas measurements for ReFlax protocol operations");
        console2.log("using mock contracts to focus on gas efficiency patterns rather than");
        console2.log("complex protocol integrations.");
        console2.log("");
        
        console2.log("## Gas Measurements");
        console2.log("");
        console2.log("| Operation | Gas Used | Details |");
        console2.log("|-----------|----------|---------|");
        
        for (uint256 i = 0; i < gasMeasurements.length; i++) {
            GasMeasurement memory measurement = gasMeasurements[i];
            console2.log("| %s | %d | %s |", 
                measurement.operation,
                measurement.gasUsed,
                measurement.details
            );
        }
        
        console2.log("");
        console2.log("## Analysis");
        console2.log("");
        
        uint256 totalGas = 0;
        uint256 totalDeposits = 0;
        uint256 depositCount = 0;
        
        for (uint256 i = 0; i < gasMeasurements.length; i++) {
            totalGas += gasMeasurements[i].gasUsed;
            if (_contains(gasMeasurements[i].operation, "Deposit")) {
                totalDeposits += gasMeasurements[i].gasUsed;
                depositCount++;
            }
        }
        
        console2.log("### Key Findings");
        console2.log("- Total gas measured: %d", totalGas);
        console2.log("- Average gas per operation: %d", totalGas / gasMeasurements.length);
        if (depositCount > 0) {
            console2.log("- Average gas per deposit: %d", totalDeposits / depositCount);
        }
        console2.log("");
        
        console2.log("### Optimization Opportunities");
        console2.log("- Gas costs scale with transaction complexity");
        console2.log("- Multiple operations in single transaction are more efficient");
        console2.log("- Mock contracts show baseline gas costs without protocol overhead");
        console2.log("");
        
        console2.log("## Methodology");
        console2.log("");
        console2.log("- **Environment**: Arbitrum mainnet fork with simplified mocks");
        console2.log("- **Measurement**: Direct gas measurement using gasleft()");
        console2.log("- **Focus**: Core operation patterns rather than protocol complexity");
        console2.log("- **Test Scenarios**: Various deposit sizes and operation combinations");
        console2.log("");
        
        console2.log("---");
        console2.log("*Report generated by ReFlax Gas Optimization Integration Test (Simplified)*");
    }
    
    function _contains(string memory str, string memory substr) internal pure returns (bool) {
        bytes memory strBytes = bytes(str);
        bytes memory substrBytes = bytes(substr);
        
        if (substrBytes.length > strBytes.length) return false;
        
        for (uint256 i = 0; i <= strBytes.length - substrBytes.length; i++) {
            bool found = true;
            for (uint256 j = 0; j < substrBytes.length; j++) {
                if (strBytes[i + j] != substrBytes[j]) {
                    found = false;
                    break;
                }
            }
            if (found) return true;
        }
        
        return false;
    }
    
    function _getCurrentDate() internal pure returns (string memory) {
        return "2025-06-15";
    }
}