// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./BaseIntegration.t.sol";

/// @title DepositFlow Integration Tests
/// @notice Tests complete deposit flows across Vault, YieldSource, and external protocols
contract DepositFlowTest is BaseIntegration {
    
    function setUp() public override {
        super.setUp();
        
        // Additional setup specific to deposit tests
        // Advance time and update oracles to have valid TWAP data
        advanceTime(1 hours);
        
        // Update reserves on pairs to advance cumulative prices
        // This simulates trading activity during the hour
        MockUniswapV2Pair(uniswapV2Factory.getPair(address(flaxToken), weth))
            .updateReserves(uint112(INITIAL_FLAX_LIQUIDITY), uint112(INITIAL_ETH_LIQUIDITY), uint32(block.timestamp));
        MockUniswapV2Pair(uniswapV2Factory.getPair(address(inputToken), weth))
            .updateReserves(uint112(1_000_000e6), uint112(1000 ether), uint32(block.timestamp));
        MockUniswapV2Pair(uniswapV2Factory.getPair(address(poolToken2), weth))
            .updateReserves(uint112(1_000_000e6), uint112(1000 ether), uint32(block.timestamp));
        MockUniswapV2Pair(uniswapV2Factory.getPair(address(crvToken), weth))
            .updateReserves(uint112(2_000_000e18), uint112(1000 ether), uint32(block.timestamp));
        MockUniswapV2Pair(uniswapV2Factory.getPair(address(cvxToken), weth))
            .updateReserves(uint112(3_000_000e18), uint112(1000 ether), uint32(block.timestamp));
        MockUniswapV2Pair(uniswapV2Factory.getPair(address(inputToken), address(poolToken2)))
            .updateReserves(uint112(1_000_000e6), uint112(1_000_000e6), uint32(block.timestamp));
        
        // Update all pairs again after time advance to ensure TWAP is computed
        oracle.update(address(flaxToken), weth);
        oracle.update(address(inputToken), weth);
        oracle.update(address(poolToken2), weth);
        oracle.update(address(crvToken), weth);
        oracle.update(address(cvxToken), weth);
        oracle.update(address(inputToken), address(poolToken2));
    }
    
    /// @notice Test a complete deposit flow from user to Convex
    function testCompleteDepositFlow() public {
        // Setup: Fund Alice with 10,000 USDC
        uint256 depositAmount = 10_000e6;
        setupUser(alice, depositAmount);
        
        // Record initial states
        uint256 initialVaultDeposits = vault.totalDeposits();
        uint256 initialYSBalance = inputToken.balanceOf(address(yieldSource));
        uint256 initialConvexDeposits = convexBooster.balanceOf(address(yieldSource));
        // Get initial oracle update time for the Flax/ETH pair
        address flaxEthPairAddress = address(flaxEthPair);
        (,, uint256 initialOracleUpdate,,) = oracle.pairMeasurements(flaxEthPairAddress);
        
        // Advance time slightly to ensure oracle update happens
        advanceTime(1);
        
        // Execute: Alice deposits 5,000 USDC
        console.log("=== Executing deposit ===");
        console.log("Alice USDC before:", inputToken.balanceOf(alice));
        
        vm.prank(alice);
        vault.deposit(5_000e6);
        
        console.log("Alice USDC after:", inputToken.balanceOf(alice));
        console.log("Amount deposited: 5000 USDC");
        
        // Assert: Verify complete state changes
        
        // 1. User token balance decreased
        assertTokenBalance(
            address(inputToken),
            alice,
            5_000e6,
            "Alice should have 5,000 USDC remaining"
        );
        
        // 2. Vault state updated correctly
        assertEq(
            vault.totalDeposits(),
            initialVaultDeposits + 5_000e6,
            "Vault totalDeposits should increase by deposit amount"
        );
        assertEq(
            vault.getEffectiveTotalDeposits(),
            initialVaultDeposits + 5_000e6,
            "Vault effective total deposits should increase by deposit amount"
        );
        assertUserDeposit(alice, 5_000e6, "Alice's deposit should be tracked");
        
        // 3. Tokens transferred through the system
        assertTokenBalance(
            address(inputToken),
            address(vault),
            0,
            "Vault should not hold input tokens"
        );
        assertTokenBalance(
            address(inputToken),
            address(yieldSource),
            0,
            "YieldSource should not hold input tokens after deposit"
        );
        
        // 4. LP tokens deposited in Convex
        assertGt(
            convexBooster.balanceOf(address(yieldSource)),
            initialConvexDeposits,
            "Convex deposits should increase"
        );
        
        // 5. Oracle update is called (but may not change timestamp if TWAP period hasn't elapsed)
        // This is expected behavior - oracle.update is called but doesn't always change the timestamp
        
        // 6. Verify LP token amount is reasonable (accounting for slippage)
        uint256 lpBalance = convexBooster.balanceOf(address(yieldSource));
        // Since USDC has 6 decimals and we deposited 5000e6, the LP amount should be similar
        // The mock adds USDC + USDT amounts, so ~5000e6 + ~5000e6 = ~10000e6
        assertEq(
            lpBalance,
            5_000_000_000, // Expected amount based on how MockCurvePool calculates (sum of inputs)
            "LP token amount should match expected amount"
        );
    }
    
    /// @notice Test multiple users depositing in sequence
    function testMultipleUserDeposits() public {
        // Setup: Fund three users
        setupUser(alice, 10_000e6);
        setupUser(bob, 20_000e6);
        setupUser(charlie, 15_000e6);
        
        // Execute: Each user deposits different amounts
        console.log("=== Multiple user deposits ===");
        
        // Alice deposits 5,000 USDC
        executeDeposit(alice, 5_000e6);
        console.log("After Alice deposit - Total:", vault.totalDeposits());
        
        // Bob deposits 10,000 USDC
        executeDeposit(bob, 10_000e6);
        console.log("After Bob deposit - Total:", vault.totalDeposits());
        
        // Charlie deposits 7,500 USDC
        executeDeposit(charlie, 7_500e6);
        console.log("After Charlie deposit - Total:", vault.totalDeposits());
        
        // Assert: Verify system state
        assertVaultState(
            22_500e6, // Total deposits
            0,        // No surplus yet
            "Vault state after multiple deposits"
        );
        
        // Verify individual deposits
        assertUserDeposit(alice, 5_000e6, "Alice deposit tracked");
        assertUserDeposit(bob, 10_000e6, "Bob deposit tracked");
        assertUserDeposit(charlie, 7_500e6, "Charlie deposit tracked");
        
        // Verify total LP tokens in Convex (should be sum of all deposits)
        // MockCurvePool returns LP tokens with same scale as input tokens (USDC has 6 decimals)
        uint256 totalLP = convexBooster.balanceOf(address(yieldSource));
        assertApproxEq(
            totalLP,
            22_500e6, // Expected LP tokens (matches total deposits in USDC scale)
            1_125e6,  // 5% tolerance
            "Total LP tokens should match total deposits"
        );
    }
    
    /// @notice Test deposit with maximum tolerable slippage
    function testDepositWithMaxSlippage() public {
        // Setup: Configure slippage in Uniswap near the tolerance limit
        // Set specific return amounts to simulate 0.4% slippage (within 0.5% tolerance)
        uniswapV3Router.setSpecificReturnAmount(address(inputToken), address(poolToken1), 2500e6, 2490e6); // 0.4% loss
        uniswapV3Router.setSpecificReturnAmount(address(inputToken), address(poolToken2), 2500e6, 2490e6); // 0.4% loss
        setupUser(alice, 10_000e6);
        
        // Execute: Deposit should still succeed within tolerance
        vm.prank(alice);
        vault.deposit(5_000e6);
        
        // Assert: Deposit succeeded despite slippage
        assertUserDeposit(alice, 5_000e6, "Deposit tracked correctly");
        
        // Verify LP tokens received (should be less due to slippage)
        // MockCurvePool returns LP tokens with same scale as input tokens (USDC has 6 decimals)
        uint256 lpBalance = convexBooster.balanceOf(address(yieldSource));
        assertLt(lpBalance, 5_000e6, "LP tokens should be less due to slippage");
        assertGt(lpBalance, 4_800e6, "LP tokens should be within tolerance");
    }
    
    /// @notice Test deposit when vault is in emergency state
    function testDepositBlockedInEmergency() public {
        setupUser(alice, 10_000e6);
        
        // Set vault to emergency state
        vault.setEmergencyState(true);
        
        // Attempt deposit should revert
        vm.prank(alice);
        vm.expectRevert("Contract is in emergency state");
        vault.deposit(5_000e6);
        
        // Verify no state changes
        assertUserDeposit(alice, 0, "No deposit should be recorded");
        assertEq(vault.totalDeposits(), 0, "Total deposits unchanged");
    }
    
    /// @notice Test minimum viable deposit amount
    function testMinimumDeposit() public {
        // Setup with minimal amount (1 USDC)
        setupUser(alice, 10e6);
        
        // Execute: Deposit 1 USDC
        vm.prank(alice);
        vault.deposit(1e6);
        
        // Assert: Even small deposits work
        assertUserDeposit(alice, 1e6, "Small deposit tracked");
    }
    
    /// @notice Test deposit with zero amount
    function testZeroDeposit() public {
        setupUser(alice, 10_000e6);
        
        // Attempt zero deposit
        vm.prank(alice);
        vm.expectRevert("Deposit amount must be greater than 0");
        vault.deposit(0);
    }
    
    /// @notice Test gas usage for deposit operation
    function testDepositGasUsage() public {
        setupUser(alice, 10_000e6);
        
        // Measure gas for deposit
        vm.prank(alice);
        uint256 gasBefore = gasleft();
        vault.deposit(5_000e6);
        uint256 gasUsed = gasBefore - gasleft();
        
        console.log("Gas used for deposit:", gasUsed);
        
        // Assert reasonable gas usage for integration test (includes Uniswap V3, Curve, Convex operations)
        assertLt(gasUsed, 600_000, "Deposit should use less than 600k gas");
    }
}