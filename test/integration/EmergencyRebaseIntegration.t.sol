// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {BaseIntegration} from "./BaseIntegration.t.sol";
import {Vault} from "../../src/vault/Vault.sol";
import {CVX_CRV_YieldSource} from "../../src/yieldSource/CVX_CRV_YieldSource.sol";
import {PriceTilterTWAP} from "../../src/priceTilting/PriceTilterTWAP.sol";
import {TWAPOracle} from "../../src/priceTilting/TWAPOracle.sol";
import {IERC20} from "@oz_reflax/token/ERC20/IERC20.sol";

contract EmergencyRebaseIntegrationTest is BaseIntegration {
    address constant USER1 = address(0x1234);
    address constant USER2 = address(0x5678);
    address constant USER3 = address(0x9ABC);
    address constant EMERGENCY_RECIPIENT = address(0xEEEE);
    
    uint256 constant DEPOSIT_AMOUNT_1 = 1000e6; // 1000 USDC
    uint256 constant DEPOSIT_AMOUNT_2 = 2000e6; // 2000 USDC
    uint256 constant DEPOSIT_AMOUNT_3 = 1500e6; // 1500 USDC
    
    event RebaseMultiplierUpdated(uint256 oldMultiplier, uint256 newMultiplier);
    event VaultPermanentlyDisabled();
    event EmergencyStateChanged(bool state);
    event EmergencyWithdrawal(address indexed token, address indexed recipient, uint256 amount);

    function setUp() public override {
        super.setUp();
        
        // Fund users with USDC
        deal(address(inputToken), USER1, 10000e6);
        deal(address(inputToken), USER2, 10000e6);
        deal(address(inputToken), USER3, 10000e6);
        
        // Fund vault with Flax for rewards
        deal(address(flaxToken), address(vault), 1000000e18);
    }

    function testEmergencyScenarioWithMultipleUsers() public {
        // Step 1: Multiple users deposit
        vm.startPrank(USER1);
        IERC20(address(inputToken)).approve(address(vault), DEPOSIT_AMOUNT_1);
        vault.deposit(DEPOSIT_AMOUNT_1);
        vm.stopPrank();
        
        vm.startPrank(USER2);
        IERC20(address(inputToken)).approve(address(vault), DEPOSIT_AMOUNT_2);
        vault.deposit(DEPOSIT_AMOUNT_2);
        vm.stopPrank();
        
        vm.startPrank(USER3);
        IERC20(address(inputToken)).approve(address(vault), DEPOSIT_AMOUNT_3);
        vault.deposit(DEPOSIT_AMOUNT_3);
        vm.stopPrank();
        
        // Verify deposits
        uint256 totalDeposits = DEPOSIT_AMOUNT_1 + DEPOSIT_AMOUNT_2 + DEPOSIT_AMOUNT_3;
        assertEq(vault.getEffectiveDeposit(USER1), DEPOSIT_AMOUNT_1, "User1 deposit incorrect");
        assertEq(vault.getEffectiveDeposit(USER2), DEPOSIT_AMOUNT_2, "User2 deposit incorrect");
        assertEq(vault.getEffectiveDeposit(USER3), DEPOSIT_AMOUNT_3, "User3 deposit incorrect");
        assertEq(vault.getEffectiveTotalDeposits(), totalDeposits, "Total deposits incorrect");
        
        // Step 2: Simulate some time passing and yield generation
        vm.warp(block.timestamp + 7 days);
        
        // Step 3: Emergency situation occurs
        vm.startPrank(owner);
        
        // Enable emergency state
        vm.expectEmit(true, true, true, true);
        emit EmergencyStateChanged(true);
        vault.setEmergencyState(true);
        
        // Execute emergency withdrawal from yield source
        vm.expectEmit(true, true, true, true);
        emit RebaseMultiplierUpdated(1e18, 0);
        vm.expectEmit(true, true, true, true);
        emit VaultPermanentlyDisabled();
        
        vault.emergencyWithdrawFromYieldSource(address(inputToken), EMERGENCY_RECIPIENT);
        vm.stopPrank();
        
        // Step 4: Verify all user deposits are effectively zeroed
        assertEq(vault.rebaseMultiplier(), 0, "Rebase multiplier should be 0");
        assertEq(vault.getEffectiveDeposit(USER1), 0, "User1 effective deposit should be 0");
        assertEq(vault.getEffectiveDeposit(USER2), 0, "User2 effective deposit should be 0");
        assertEq(vault.getEffectiveDeposit(USER3), 0, "User3 effective deposit should be 0");
        assertEq(vault.getEffectiveTotalDeposits(), 0, "Total effective deposits should be 0");
        
        // Original deposits remain for historical tracking
        assertEq(vault.originalDeposits(USER1), DEPOSIT_AMOUNT_1, "User1 original deposit preserved");
        assertEq(vault.originalDeposits(USER2), DEPOSIT_AMOUNT_2, "User2 original deposit preserved");
        assertEq(vault.originalDeposits(USER3), DEPOSIT_AMOUNT_3, "User3 original deposit preserved");
        
        // Step 5: Verify vault is permanently disabled
        vm.startPrank(USER1);
        IERC20(address(inputToken)).approve(address(vault), 1000e6);
        vm.expectRevert("Vault permanently disabled");
        vault.deposit(1000e6);
        
        vm.expectRevert("Vault permanently disabled");
        vault.withdraw(1, false, 0);
        
        vm.expectRevert("Vault permanently disabled");
        vault.claimRewards(0);
        vm.stopPrank();
        
        // Emergency recipient should have received funds
        assertTrue(IERC20(address(inputToken)).balanceOf(EMERGENCY_RECIPIENT) > 0, "Emergency recipient should have received USDC");
    }

    function testEmergencyAfterPartialWithdrawals() public {
        // Users deposit
        vm.startPrank(USER1);
        IERC20(address(inputToken)).approve(address(vault), DEPOSIT_AMOUNT_1);
        vault.deposit(DEPOSIT_AMOUNT_1);
        vm.stopPrank();
        
        vm.startPrank(USER2);
        IERC20(address(inputToken)).approve(address(vault), DEPOSIT_AMOUNT_2);
        vault.deposit(DEPOSIT_AMOUNT_2);
        vm.stopPrank();
        
        // User1 partially withdraws
        uint256 withdrawAmount = DEPOSIT_AMOUNT_1 / 2;
        vm.prank(USER1);
        vault.withdraw(withdrawAmount, false, 0);
        
        // Verify deposits after withdrawal
        assertEq(vault.getEffectiveDeposit(USER1), DEPOSIT_AMOUNT_1 - withdrawAmount, "User1 deposit after withdrawal");
        assertEq(vault.getEffectiveDeposit(USER2), DEPOSIT_AMOUNT_2, "User2 deposit unchanged");
        
        // Emergency withdrawal
        vm.startPrank(owner);
        vault.setEmergencyState(true);
        vault.emergencyWithdrawFromYieldSource(address(inputToken), EMERGENCY_RECIPIENT);
        vm.stopPrank();
        
        // All effective deposits should be zero
        assertEq(vault.getEffectiveDeposit(USER1), 0, "User1 effective deposit should be 0");
        assertEq(vault.getEffectiveDeposit(USER2), 0, "User2 effective deposit should be 0");
    }

    function testEmergencyWithOtherTokens() public {
        // User deposits USDC
        vm.startPrank(USER1);
        IERC20(address(inputToken)).approve(address(vault), DEPOSIT_AMOUNT_1);
        vault.deposit(DEPOSIT_AMOUNT_1);
        vm.stopPrank();
        
        // Add some Flax tokens to vault (simulating accumulated rewards)
        uint256 flaxBalance = 5000e18;
        deal(address(flaxToken), address(vault), flaxBalance);
        
        // Emergency state
        vm.prank(owner);
        vault.setEmergencyState(true);
        
        // Emergency withdraw USDC (this sets rebase to 0)
        vm.prank(owner);
        vault.emergencyWithdrawFromYieldSource(address(inputToken), EMERGENCY_RECIPIENT);
        
        assertEq(vault.rebaseMultiplier(), 0, "Rebase should be 0");
        
        // Emergency withdraw Flax (should not affect rebase further)
        uint256 rebaseBefore = vault.rebaseMultiplier();
        vm.prank(owner);
        vault.emergencyWithdraw(address(flaxToken), EMERGENCY_RECIPIENT);
        
        assertEq(vault.rebaseMultiplier(), rebaseBefore, "Rebase should not change for non-input tokens");
        assertEq(IERC20(address(flaxToken)).balanceOf(EMERGENCY_RECIPIENT), flaxBalance, "Flax should be transferred");
    }

    function testNormalOperationsBeforeEmergency() public {
        // User1 deposits
        vm.startPrank(USER1);
        IERC20(address(inputToken)).approve(address(vault), DEPOSIT_AMOUNT_1);
        vault.deposit(DEPOSIT_AMOUNT_1);
        
        // User1 claims rewards
        vault.claimRewards(0);
        
        // User1 partially withdraws
        vault.withdraw(DEPOSIT_AMOUNT_1 / 2, false, 0);
        vm.stopPrank();
        
        // User2 deposits
        vm.startPrank(USER2);
        IERC20(address(inputToken)).approve(address(vault), DEPOSIT_AMOUNT_2);
        vault.deposit(DEPOSIT_AMOUNT_2);
        vm.stopPrank();
        
        // Calculate expected totals
        uint256 expectedTotal = (DEPOSIT_AMOUNT_1 / 2) + DEPOSIT_AMOUNT_2;
        assertEq(vault.getEffectiveTotalDeposits(), expectedTotal, "Total deposits before emergency");
        
        // Emergency occurs
        vm.startPrank(owner);
        vault.setEmergencyState(true);
        vault.emergencyWithdrawFromYieldSource(address(inputToken), EMERGENCY_RECIPIENT);
        vm.stopPrank();
        
        // All effective deposits zeroed
        assertEq(vault.getEffectiveTotalDeposits(), 0, "Total effective deposits should be 0");
        assertEq(vault.getEffectiveDeposit(USER1), 0, "User1 effective deposit should be 0");
        assertEq(vault.getEffectiveDeposit(USER2), 0, "User2 effective deposit should be 0");
    }

    function testEmergencyStateWithoutInputTokenWithdrawal() public {
        // User deposits
        vm.startPrank(USER1);
        IERC20(address(inputToken)).approve(address(vault), DEPOSIT_AMOUNT_1);
        vault.deposit(DEPOSIT_AMOUNT_1);
        vm.stopPrank();
        
        // Set emergency state
        vm.prank(owner);
        vault.setEmergencyState(true);
        
        // Verify rebase is still normal
        assertEq(vault.rebaseMultiplier(), 1e18, "Rebase should still be 1e18");
        assertEq(vault.getEffectiveDeposit(USER1), DEPOSIT_AMOUNT_1, "Effective deposit should be unchanged");
        
        // User can still withdraw during emergency (before permanent disable)
        vm.prank(USER1);
        vault.withdraw(DEPOSIT_AMOUNT_1 / 2, false, 0);
        
        assertEq(vault.getEffectiveDeposit(USER1), DEPOSIT_AMOUNT_1 / 2, "Withdrawal should work in emergency state");
        
        // Now permanently disable by withdrawing input token
        vm.prank(owner);
        vault.emergencyWithdrawFromYieldSource(address(inputToken), EMERGENCY_RECIPIENT);
        
        // Now withdrawals should fail
        vm.prank(USER1);
        vm.expectRevert("Vault permanently disabled");
        vault.withdraw(1, false, 0);
    }

    function testSurplusHandlingDuringEmergency() public {
        // Setup: Create surplus by having yield source return extra
        vm.startPrank(USER1);
        IERC20(address(inputToken)).approve(address(vault), DEPOSIT_AMOUNT_1);
        vault.deposit(DEPOSIT_AMOUNT_1);
        
        // Withdraw with surplus
        vault.withdraw(DEPOSIT_AMOUNT_1 / 2, false, 0);
        vm.stopPrank();
        
        uint256 surplusBefore = vault.surplusInputToken();
        assertTrue(surplusBefore > 0, "Should have surplus from withdrawal");
        
        // Emergency withdrawal
        vm.startPrank(owner);
        vault.setEmergencyState(true);
        vault.emergencyWithdrawFromYieldSource(address(inputToken), EMERGENCY_RECIPIENT);
        vm.stopPrank();
        
        // Surplus should be included in emergency withdrawal
        uint256 surplusAfter = vault.surplusInputToken();
        assertTrue(surplusAfter > surplusBefore, "Surplus should increase from yield source withdrawal");
        
        // Verify vault is disabled
        assertEq(vault.rebaseMultiplier(), 0, "Vault should be permanently disabled");
    }
}