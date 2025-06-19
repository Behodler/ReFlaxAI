// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {Vault} from "../src/vault/Vault.sol";
import {MockERC20, MockYieldSource, MockPriceTilter} from "./mocks/Mocks.sol";
import {IERC20} from "@oz_reflax/token/ERC20/IERC20.sol";

contract VaultRebaseMultiplierTest is Test {
    Vault vault;
    MockERC20 inputToken;
    MockERC20 flaxToken;
    MockERC20 sFlaxToken;
    MockYieldSource yieldSource;
    address priceTilter;
    address user;
    address owner;

    // Constants
    uint256 constant INITIAL_DEPOSIT = 1000 * 1e18;
    uint256 constant DEPOSIT_AMOUNT = 100 * 1e18;
    uint256 constant REBASE_MULTIPLIER_NORMAL = 1e18;
    uint256 constant REBASE_MULTIPLIER_DISABLED = 0;

    event RebaseMultiplierUpdated(uint256 oldMultiplier, uint256 newMultiplier);
    event VaultPermanentlyDisabled();
    event EmergencyWithdrawal(address indexed token, address indexed recipient, uint256 amount);

    function setUp() public {
        owner = address(this);
        user = address(0x1234);
        inputToken = new MockERC20();
        flaxToken = new MockERC20();
        sFlaxToken = new MockERC20();
        yieldSource = new MockYieldSource(address(inputToken));
        priceTilter = address(new MockPriceTilter());

        vault = new Vault(
            address(flaxToken),
            address(sFlaxToken),
            address(inputToken),
            address(yieldSource),
            priceTilter
        );

        // Setup initial state
        inputToken.mint(user, INITIAL_DEPOSIT);
        inputToken.mint(address(yieldSource), INITIAL_DEPOSIT); // For withdrawals
        flaxToken.mint(address(vault), 1000000 * 1e18); // Ensure vault has Flax
    }

    function testInitialRebaseMultiplier() public view {
        assertEq(vault.rebaseMultiplier(), REBASE_MULTIPLIER_NORMAL, "Initial rebase multiplier should be 1e18");
    }

    function testEffectiveDepositsWithNormalMultiplier() public {
        // User deposits
        vm.startPrank(user);
        inputToken.approve(address(vault), DEPOSIT_AMOUNT);
        vault.deposit(DEPOSIT_AMOUNT);
        vm.stopPrank();

        // Check effective deposits equal original deposits when multiplier is normal
        assertEq(vault.getEffectiveDeposit(user), DEPOSIT_AMOUNT, "Effective deposit should equal original deposit");
        assertEq(vault.getEffectiveTotalDeposits(), DEPOSIT_AMOUNT, "Effective total should equal total deposits");
        assertEq(vault.originalDeposits(user), DEPOSIT_AMOUNT, "Original deposit should be tracked");
        assertEq(vault.totalDeposits(), DEPOSIT_AMOUNT, "Total deposits should be tracked");
    }

    function testEmergencyWithdrawalSetsRebaseToZero() public {
        // Setup: User deposits
        vm.startPrank(user);
        inputToken.approve(address(vault), DEPOSIT_AMOUNT);
        vault.deposit(DEPOSIT_AMOUNT);
        vm.stopPrank();

        // Enable emergency state
        vault.setEmergencyState(true);
        
        // Execute emergency withdrawal from yield source
        vm.expectEmit(true, true, true, true);
        emit RebaseMultiplierUpdated(REBASE_MULTIPLIER_NORMAL, REBASE_MULTIPLIER_DISABLED);
        vm.expectEmit(true, true, true, true);
        emit VaultPermanentlyDisabled();
        
        vault.emergencyWithdrawFromYieldSource(address(inputToken), owner);

        // Verify rebase multiplier is set to 0
        assertEq(vault.rebaseMultiplier(), REBASE_MULTIPLIER_DISABLED, "Rebase multiplier should be 0 after emergency");
        
        // Verify effective deposits are now 0
        assertEq(vault.getEffectiveDeposit(user), 0, "Effective deposit should be 0 after emergency");
        assertEq(vault.getEffectiveTotalDeposits(), 0, "Effective total should be 0 after emergency");
        
        // Original deposits remain unchanged (for historical tracking)
        assertEq(vault.originalDeposits(user), DEPOSIT_AMOUNT, "Original deposit should remain unchanged");
    }

    function testDepositFailsWhenPermanentlyDisabled() public {
        // Setup: User deposits first to have funds in vault
        vm.startPrank(user);
        inputToken.approve(address(vault), DEPOSIT_AMOUNT);
        vault.deposit(DEPOSIT_AMOUNT);
        vm.stopPrank();
        
        // Emergency withdrawal to disable vault
        vault.setEmergencyState(true);
        vault.emergencyWithdrawFromYieldSource(address(inputToken), owner);
        
        // Disable emergency state to test the permanent disable check
        vault.setEmergencyState(false);
        
        // Attempt to deposit should fail
        vm.startPrank(user);
        inputToken.approve(address(vault), DEPOSIT_AMOUNT);
        vm.expectRevert("Vault permanently disabled");
        vault.deposit(DEPOSIT_AMOUNT);
        vm.stopPrank();
    }

    function testWithdrawFailsWhenPermanentlyDisabled() public {
        // Setup: User deposits first
        vm.startPrank(user);
        inputToken.approve(address(vault), DEPOSIT_AMOUNT);
        vault.deposit(DEPOSIT_AMOUNT);
        vm.stopPrank();
        
        // Emergency withdrawal to disable vault
        vault.setEmergencyState(true);
        vault.emergencyWithdrawFromYieldSource(address(inputToken), owner);
        
        // Attempt to withdraw should fail
        vm.startPrank(user);
        vm.expectRevert("Vault permanently disabled");
        vault.withdraw(DEPOSIT_AMOUNT, false, 0);
        vm.stopPrank();
    }

    function testClaimRewardsFailsWhenPermanentlyDisabled() public {
        // Setup: User deposits first to have funds in vault
        vm.startPrank(user);
        inputToken.approve(address(vault), DEPOSIT_AMOUNT);
        vault.deposit(DEPOSIT_AMOUNT);
        vm.stopPrank();
        
        // Emergency withdrawal to disable vault
        vault.setEmergencyState(true);
        vault.emergencyWithdrawFromYieldSource(address(inputToken), owner);
        
        // Disable emergency state to test the permanent disable check
        vault.setEmergencyState(false);
        
        // Attempt to claim rewards should fail
        vm.expectRevert("Vault permanently disabled");
        vault.claimRewards(0);
    }

    function testMigrateYieldSourceFailsWhenPermanentlyDisabled() public {
        // Setup: User deposits first to have funds in vault
        vm.startPrank(user);
        inputToken.approve(address(vault), DEPOSIT_AMOUNT);
        vault.deposit(DEPOSIT_AMOUNT);
        vm.stopPrank();
        
        // Emergency withdrawal to disable vault
        vault.setEmergencyState(true);
        vault.emergencyWithdrawFromYieldSource(address(inputToken), owner);
        
        // Disable emergency state to test the permanent disable check
        vault.setEmergencyState(false);
        
        // Attempt to migrate should fail
        address newYieldSource = address(new MockYieldSource(address(inputToken)));
        vm.expectRevert("Vault permanently disabled");
        vault.migrateYieldSource(newYieldSource);
    }

    function testEffectiveDepositCalculation() public {
        // Test various deposit amounts and multiplier values
        uint256[] memory deposits = new uint256[](3);
        deposits[0] = 100 * 1e18;
        deposits[1] = 1 * 1e18;
        deposits[2] = 999999 * 1e18;

        for (uint i = 0; i < deposits.length; i++) {
            address testUser = address(uint160(0x2000 + i));
            inputToken.mint(testUser, deposits[i]);
            
            vm.startPrank(testUser);
            inputToken.approve(address(vault), deposits[i]);
            vault.deposit(deposits[i]);
            vm.stopPrank();
            
            // With normal multiplier (1e18), effective = original
            assertEq(vault.getEffectiveDeposit(testUser), deposits[i], "Effective should equal original");
        }
        
        // After emergency (multiplier = 0), all effective deposits = 0
        vault.setEmergencyState(true);
        vault.emergencyWithdrawFromYieldSource(address(inputToken), owner);
        
        for (uint i = 0; i < deposits.length; i++) {
            address testUser = address(uint160(0x2000 + i));
            assertEq(vault.getEffectiveDeposit(testUser), 0, "All effective deposits should be 0");
        }
    }

    function testWithdrawUsesEffectiveDeposits() public {
        // User deposits
        vm.startPrank(user);
        inputToken.approve(address(vault), DEPOSIT_AMOUNT);
        vault.deposit(DEPOSIT_AMOUNT);
        
        // Should be able to withdraw based on effective deposit
        uint256 halfAmount = DEPOSIT_AMOUNT / 2;
        yieldSource.setReturnValues(halfAmount, 0);
        
        vault.withdraw(halfAmount, false, 0);
        assertEq(vault.getEffectiveDeposit(user), DEPOSIT_AMOUNT - halfAmount, "Effective deposit should decrease");
        vm.stopPrank();
    }

    function testWithdrawFailsWhenExceedingEffectiveDeposit() public {
        // User deposits
        vm.startPrank(user);
        inputToken.approve(address(vault), DEPOSIT_AMOUNT);
        vault.deposit(DEPOSIT_AMOUNT);
        
        // Try to withdraw more than deposited
        vm.expectRevert("Insufficient effective deposit");
        vault.withdraw(DEPOSIT_AMOUNT + 1, false, 0);
        vm.stopPrank();
    }

    function testEmergencyWithdrawOnlyInEmergencyState() public {
        // Try emergency withdrawal without emergency state
        vm.expectRevert("Not in emergency state");
        vault.emergencyWithdrawFromYieldSource(address(inputToken), owner);
    }

    function testEmergencyWithdrawOnlyAffectsInputToken() public {
        // Setup: User deposits
        vm.startPrank(user);
        inputToken.approve(address(vault), DEPOSIT_AMOUNT);
        vault.deposit(DEPOSIT_AMOUNT);
        vm.stopPrank();
        
        // Enable emergency state
        vault.setEmergencyState(true);
        
        // Emergency withdraw a different token shouldn't affect rebase
        MockERC20 otherToken = new MockERC20();
        otherToken.mint(address(vault), 1000 * 1e18);
        
        uint256 rebaseBefore = vault.rebaseMultiplier();
        vault.emergencyWithdrawFromYieldSource(address(otherToken), owner);
        
        // Rebase multiplier should not change for non-input tokens
        assertEq(vault.rebaseMultiplier(), rebaseBefore, "Rebase should not change for non-input tokens");
    }

    function testEmergencyWithdrawOnlyWhenDepositsExist() public {
        // Enable emergency state with no deposits
        vault.setEmergencyState(true);
        
        uint256 rebaseBefore = vault.rebaseMultiplier();
        vault.emergencyWithdrawFromYieldSource(address(inputToken), owner);
        
        // Rebase multiplier should not change when no deposits
        assertEq(vault.rebaseMultiplier(), rebaseBefore, "Rebase should not change when no deposits");
    }
}