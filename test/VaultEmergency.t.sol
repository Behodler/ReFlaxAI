// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {Vault} from "../src/vault/Vault.sol";
import {MockERC20, MockYieldSource, MockPriceTilter} from "./mocks/Mocks.sol";
import {IERC20} from "@oz_reflax/token/ERC20/IERC20.sol";

contract VaultEmergencyTest is Test {
    Vault vault;
    MockERC20 inputToken;
    MockERC20 flaxToken;
    MockERC20 sFlaxToken;
    MockERC20 randomToken;
    MockYieldSource yieldSource;
    address priceTilter;
    address user;
    address owner;
    address recipient;

    // Constants
    uint256 constant INITIAL_BALANCE = 10000 * 1e18;
    uint256 constant DEPOSIT_AMOUNT = 1000 * 1e18;
    uint256 constant ETH_AMOUNT = 5 ether;

    event EmergencyStateChanged(bool state);
    event EmergencyWithdrawal(address indexed token, address indexed recipient, uint256 amount);
    event RebaseMultiplierUpdated(uint256 oldMultiplier, uint256 newMultiplier);
    event VaultPermanentlyDisabled();

    function setUp() public {
        owner = address(this);
        user = address(0x1234);
        recipient = address(0x5678);
        
        inputToken = new MockERC20();
        flaxToken = new MockERC20();
        sFlaxToken = new MockERC20();
        randomToken = new MockERC20();
        yieldSource = new MockYieldSource(address(inputToken));
        priceTilter = address(new MockPriceTilter());

        vault = new Vault(
            address(flaxToken),
            address(sFlaxToken),
            address(inputToken),
            address(yieldSource),
            priceTilter
        );

        // Setup balances
        inputToken.mint(user, INITIAL_BALANCE);
        inputToken.mint(address(yieldSource), INITIAL_BALANCE);
        flaxToken.mint(address(vault), INITIAL_BALANCE);
        randomToken.mint(address(vault), INITIAL_BALANCE);
        
        // Send ETH to vault
        vm.deal(address(vault), ETH_AMOUNT);
    }

    function testSetEmergencyState() public {
        assertFalse(vault.emergencyState(), "Emergency state should be false initially");
        
        vm.expectEmit(true, true, true, true);
        emit EmergencyStateChanged(true);
        vault.setEmergencyState(true);
        
        assertTrue(vault.emergencyState(), "Emergency state should be true");
        
        vm.expectEmit(true, true, true, true);
        emit EmergencyStateChanged(false);
        vault.setEmergencyState(false);
        
        assertFalse(vault.emergencyState(), "Emergency state should be false again");
    }

    function testOnlyOwnerCanSetEmergencyState() public {
        vm.prank(user);
        vm.expectRevert();
        vault.setEmergencyState(true);
    }

    function testEmergencyStateBlocksDeposits() public {
        vault.setEmergencyState(true);
        
        vm.startPrank(user);
        inputToken.approve(address(vault), DEPOSIT_AMOUNT);
        vm.expectRevert("Contract is in emergency state");
        vault.deposit(DEPOSIT_AMOUNT);
        vm.stopPrank();
    }

    function testEmergencyStateBlocksClaims() public {
        vault.setEmergencyState(true);
        
        vm.expectRevert("Contract is in emergency state");
        vault.claimRewards(0);
    }

    function testEmergencyStateBlocksMigration() public {
        vault.setEmergencyState(true);
        
        address newYieldSource = address(new MockYieldSource(address(inputToken)));
        vm.expectRevert("Contract is in emergency state");
        vault.migrateYieldSource(newYieldSource);
    }

    function testEmergencyStateAllowsWithdrawals() public {
        // User deposits first
        vm.startPrank(user);
        inputToken.approve(address(vault), DEPOSIT_AMOUNT);
        vault.deposit(DEPOSIT_AMOUNT);
        vm.stopPrank();
        
        // Enable emergency state
        vault.setEmergencyState(true);
        
        // User can still withdraw
        vm.startPrank(user);
        yieldSource.setReturnValues(DEPOSIT_AMOUNT, 0);
        vault.withdraw(DEPOSIT_AMOUNT, false, 0);
        vm.stopPrank();
        
        assertEq(vault.getEffectiveDeposit(user), 0, "User should have withdrawn all");
    }

    function testEmergencyWithdrawERC20() public {
        uint256 vaultBalance = randomToken.balanceOf(address(vault));
        uint256 recipientBalanceBefore = randomToken.balanceOf(recipient);
        
        vm.expectEmit(true, true, true, true);
        emit EmergencyWithdrawal(address(randomToken), recipient, vaultBalance);
        vault.emergencyWithdraw(address(randomToken), recipient);
        
        assertEq(randomToken.balanceOf(address(vault)), 0, "Vault should have no tokens");
        assertEq(randomToken.balanceOf(recipient), recipientBalanceBefore + vaultBalance, "Recipient should receive tokens");
    }

    function testEmergencyWithdrawETH() public {
        uint256 vaultETHBalance = address(vault).balance;
        uint256 recipientETHBefore = recipient.balance;
        
        vm.expectEmit(true, true, true, true);
        emit EmergencyWithdrawal(address(0), recipient, vaultETHBalance);
        vault.emergencyWithdrawETH(payable(recipient));
        
        assertEq(address(vault).balance, 0, "Vault should have no ETH");
        assertEq(recipient.balance, recipientETHBefore + vaultETHBalance, "Recipient should receive ETH");
    }

    function testOnlyOwnerCanEmergencyWithdraw() public {
        vm.startPrank(user);
        vm.expectRevert();
        vault.emergencyWithdraw(address(randomToken), recipient);
        
        vm.expectRevert();
        vault.emergencyWithdrawETH(payable(recipient));
        
        vm.expectRevert();
        vault.emergencyWithdrawFromYieldSource(address(inputToken), recipient);
        vm.stopPrank();
    }

    function testEmergencyWithdrawInvalidToken() public {
        vm.expectRevert("Invalid token address");
        vault.emergencyWithdraw(address(0), recipient);
    }

    function testEmergencyWithdrawFromYieldSourceFullFlow() public {
        // User deposits
        vm.startPrank(user);
        inputToken.approve(address(vault), DEPOSIT_AMOUNT);
        vault.deposit(DEPOSIT_AMOUNT);
        vm.stopPrank();
        
        // Enable emergency state
        vault.setEmergencyState(true);
        
        // Setup yield source to return tokens on withdrawal
        yieldSource.setReturnValues(DEPOSIT_AMOUNT, 0);
        
        // Record balances before
        uint256 recipientBalanceBefore = inputToken.balanceOf(recipient);
        uint256 vaultSurplusBefore = vault.surplusInputToken();
        
        // Execute emergency withdrawal
        vm.expectEmit(true, true, true, true);
        emit RebaseMultiplierUpdated(1e18, 0);
        vm.expectEmit(true, true, true, true);
        emit VaultPermanentlyDisabled();
        
        vault.emergencyWithdrawFromYieldSource(address(inputToken), recipient);
        
        // Verify state changes
        assertEq(vault.rebaseMultiplier(), 0, "Rebase multiplier should be 0");
        assertEq(vault.getEffectiveDeposit(user), 0, "User effective deposit should be 0");
        assertEq(vault.getEffectiveTotalDeposits(), 0, "Total effective deposits should be 0");
        
        // Verify tokens were transferred
        assertTrue(inputToken.balanceOf(recipient) > recipientBalanceBefore, "Recipient should receive tokens");
        
        // Surplus should have increased from yield source withdrawal
        assertTrue(vault.surplusInputToken() > vaultSurplusBefore, "Surplus should increase from withdrawal");
    }

    function testEmergencyWithdrawFromYieldSourceNonInputToken() public {
        // Enable emergency state
        vault.setEmergencyState(true);
        
        // Add some random tokens to vault
        randomToken.mint(address(vault), 1000 * 1e18);
        
        uint256 rebaseBefore = vault.rebaseMultiplier();
        uint256 balanceBefore = randomToken.balanceOf(recipient);
        
        // Withdraw non-input token
        vault.emergencyWithdrawFromYieldSource(address(randomToken), recipient);
        
        // Rebase should not change for non-input tokens
        assertEq(vault.rebaseMultiplier(), rebaseBefore, "Rebase should not change");
        assertTrue(randomToken.balanceOf(recipient) > balanceBefore, "Recipient should receive tokens");
    }

    function testEmergencyWithdrawZeroBalance() public {
        // Create a token with no balance in vault
        MockERC20 emptyToken = new MockERC20();
        
        // Should not revert even with zero balance
        vault.emergencyWithdraw(address(emptyToken), recipient);
        
        // No event should be emitted for zero transfer
        assertEq(emptyToken.balanceOf(recipient), 0, "No tokens should be transferred");
    }

    function testEmergencyWithdrawETHZeroBalance() public {
        // Deploy new vault with no ETH
        Vault emptyVault = new Vault(
            address(flaxToken),
            address(sFlaxToken),
            address(inputToken),
            address(yieldSource),
            priceTilter
        );
        
        uint256 recipientETHBefore = recipient.balance;
        
        // Should not revert even with zero balance
        emptyVault.emergencyWithdrawETH(payable(recipient));
        
        assertEq(recipient.balance, recipientETHBefore, "No ETH should be transferred");
    }

    function testReceiveETH() public {
        uint256 vaultETHBefore = address(vault).balance;
        uint256 sendAmount = 1 ether;
        
        // Send ETH to vault
        vm.deal(user, sendAmount);
        vm.prank(user);
        (bool success,) = address(vault).call{value: sendAmount}("");
        
        assertTrue(success, "ETH transfer should succeed");
        assertEq(address(vault).balance, vaultETHBefore + sendAmount, "Vault should receive ETH");
    }

    function testCompleteEmergencyScenario() public {
        // 1. Multiple users deposit
        address user2 = address(0x2345);
        inputToken.mint(user2, INITIAL_BALANCE);
        
        vm.startPrank(user);
        inputToken.approve(address(vault), DEPOSIT_AMOUNT);
        vault.deposit(DEPOSIT_AMOUNT);
        vm.stopPrank();
        
        vm.startPrank(user2);
        inputToken.approve(address(vault), DEPOSIT_AMOUNT * 2);
        vault.deposit(DEPOSIT_AMOUNT * 2);
        vm.stopPrank();
        
        // 2. Emergency state triggered
        vault.setEmergencyState(true);
        
        // 3. Execute emergency withdrawal from yield source
        vault.emergencyWithdrawFromYieldSource(address(inputToken), owner);
        
        // 4. Verify vault is permanently disabled
        assertEq(vault.rebaseMultiplier(), 0, "Vault should be permanently disabled");
        assertEq(vault.getEffectiveDeposit(user), 0, "User1 effective deposit should be 0");
        assertEq(vault.getEffectiveDeposit(user2), 0, "User2 effective deposit should be 0");
        
        // 5. All operations should fail (disable emergency state to test permanent disable check)
        vault.setEmergencyState(false);
        
        vm.startPrank(user);
        inputToken.approve(address(vault), DEPOSIT_AMOUNT);
        vm.expectRevert("Vault permanently disabled");
        vault.deposit(DEPOSIT_AMOUNT);
        
        vm.expectRevert("Vault permanently disabled");
        vault.withdraw(1, false, 0);
        
        vm.expectRevert("Vault permanently disabled");
        vault.claimRewards(0);
        vm.stopPrank();
        
        // 6. Emergency withdrawals of other assets still work
        vault.emergencyWithdraw(address(flaxToken), recipient);
        vault.emergencyWithdrawETH(payable(recipient));
    }
}