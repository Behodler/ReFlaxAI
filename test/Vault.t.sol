// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {Vault} from "../src/vault/Vault.sol";
import {MockERC20, MockYieldSource, MockPriceTilter} from "./mocks/Mocks.sol";
import {IERC20} from "@oz_reflax/contracts/token/ERC20/IERC20.sol";
import {IPriceTilter} from "../src/priceTilting/IPriceTilter.sol";

contract VaultTest is Test {
    Vault vault;
    MockERC20 inputToken;
    MockERC20 flaxToken;
    MockERC20 sFlaxToken;
    MockYieldSource yieldSource;
    address priceTilter;
    address user;

    // Constants
    uint256 constant INITIAL_DEPOSIT = 1000 * 1e18;
    uint256 constant DEPOSIT_AMOUNT = 100 * 1e18;
    uint256 constant WITHDRAW_AMOUNT = 100 * 1e18;
    uint256 constant SFLAX_AMOUNT = 50 * 1e18;
    uint256 constant FLAX_VALUE = 10 * 1e18;

    event Deposited(address indexed user, uint256 amount);
    event RewardsClaimed(address indexed user, uint256 flaxAmount);
    event SFlaxBurned(address indexed user, uint256 sFlaxAmount, uint256 flaxRewarded);
    event Withdrawn(address indexed user, uint256 amount);

    function setUp() public {
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

        // Mint tokens to user, Vault, and yieldSource
        inputToken.mint(user, INITIAL_DEPOSIT);
        inputToken.mint(address(yieldSource), INITIAL_DEPOSIT);
        sFlaxToken.mint(user, INITIAL_DEPOSIT);
        flaxToken.mint(address(vault), INITIAL_DEPOSIT);

        // Approve Vault to spend user's tokens
        vm.startPrank(user);
        inputToken.approve(address(vault), type(uint256).max);
        sFlaxToken.approve(address(vault), type(uint256).max);
        vm.stopPrank();

        // Set Vault parameters
        vm.prank(vault.owner());
        vault.setFlaxPerSFlax(1e17); // 0.1 flax per sFlax
    }

    function testDeposit() public {
        vm.startPrank(user);

        vm.expectEmit(true, false, false, true);
        emit Deposited(user, DEPOSIT_AMOUNT);

        vault.deposit(DEPOSIT_AMOUNT);

        assertEq(inputToken.balanceOf(user), 900 * 1e18, "User balance incorrect");
        assertEq(inputToken.balanceOf(address(vault)), DEPOSIT_AMOUNT, "Vault balance incorrect");
        assertEq(yieldSource.totalDeposited(), DEPOSIT_AMOUNT, "YieldSource deposit incorrect");
        assertEq(vault.originalDeposits(user), DEPOSIT_AMOUNT, "originalDeposits incorrect");
        assertEq(vault.totalDeposits(), DEPOSIT_AMOUNT, "totalDeposits incorrect");

        vm.stopPrank();
    }

    function testClaimRewards() public {
        vm.startPrank(user);

        // Case 1: Positive sFlaxAmount
        uint256 sFlaxAmount = 100 * 1e18;
        uint256 flaxValue = 50 * 1e18;
        yieldSource.setReturnValues(0, flaxValue);
        uint256 expectedFlaxBoost = (sFlaxAmount * vault.flaxPerSFlax()) / 1e18; // 100 * 0.1 = 10 * 1e18
        uint256 expectedTotalFlax = flaxValue + expectedFlaxBoost;

        vm.expectEmit(true, false, false, true);
        emit SFlaxBurned(user, sFlaxAmount, expectedFlaxBoost);
        vm.expectEmit(true, false, false, true);
        emit RewardsClaimed(user, expectedTotalFlax);

        vault.claimRewards(sFlaxAmount);

        assertEq(sFlaxToken.balanceOf(user), 900 * 1e18, "sFlax balance incorrect");
        assertEq(flaxToken.balanceOf(user), expectedTotalFlax, "User flax balance incorrect");
        assertEq(flaxToken.balanceOf(address(vault)), 1000 * 1e18 - expectedTotalFlax, "Vault flax balance incorrect");

        // Case 2: Zero sFlaxAmount
        sFlaxAmount = 0;
        flaxValue = 20 * 1e18;
        yieldSource.setReturnValues(0, flaxValue);
        expectedTotalFlax = flaxValue;

        vm.expectEmit(true, false, false, true);
        emit RewardsClaimed(user, expectedTotalFlax);

        vault.claimRewards(sFlaxAmount);

        assertEq(sFlaxToken.balanceOf(user), 900 * 1e18, "sFlax balance unchanged");
        assertEq(flaxToken.balanceOf(user), 80 * 1e18, "User flax balance incorrect after zero");
        assertEq(flaxToken.balanceOf(address(vault)), 920 * 1e18, "Vault flax balance incorrect after zero");

        vm.stopPrank();
    }

    function testWithdrawStandard() public {
        // Deposit to enable withdrawal
        vm.prank(user);
        vault.deposit(WITHDRAW_AMOUNT);

        // Configure yieldSource
        yieldSource.setReturnValues(WITHDRAW_AMOUNT, FLAX_VALUE);
        inputToken.mint(address(yieldSource), WITHDRAW_AMOUNT);

        // Record initial balances
        uint256 userInputBalanceBefore = inputToken.balanceOf(user);
        uint256 userSFlaxBalanceBefore = sFlaxToken.balanceOf(user);
        uint256 vaultTotalDepositsBefore = vault.totalDeposits();

        // Expect events in correct order
        vm.expectEmit(true, false, false, true);
        emit SFlaxBurned(user, SFLAX_AMOUNT, SFLAX_AMOUNT * vault.flaxPerSFlax() / 1e18);
        vm.expectEmit(true, false, false, true);
        emit RewardsClaimed(user, FLAX_VALUE + (SFLAX_AMOUNT * vault.flaxPerSFlax() / 1e18));
        vm.expectEmit(true, false, false, true);
        emit Withdrawn(user, WITHDRAW_AMOUNT);

        // Perform withdrawal
        vm.prank(user);
        vault.withdraw(WITHDRAW_AMOUNT, false, SFLAX_AMOUNT);

        // Check balances
        assertEq(inputToken.balanceOf(user), userInputBalanceBefore + WITHDRAW_AMOUNT, "Incorrect user inputToken balance");
        assertEq(sFlaxToken.balanceOf(user), userSFlaxBalanceBefore - SFLAX_AMOUNT, "Incorrect user sFlax balance");
        assertEq(vault.totalDeposits(), vaultTotalDepositsBefore - WITHDRAW_AMOUNT, "Incorrect totalDeposits");
        assertEq(vault.surplusInputToken(), 0, "Surplus should be zero");
    }

    function testWithdrawWithSurplus() public {
        // Deposit to enable withdrawal
        vm.prank(user);
        vault.deposit(WITHDRAW_AMOUNT);

        // Configure yieldSource
        uint256 surplusAmount = WITHDRAW_AMOUNT + 10 * 1e18;
        yieldSource.setReturnValues(surplusAmount, FLAX_VALUE);
        inputToken.mint(address(yieldSource), surplusAmount);

        // Record initial balances
        uint256 userInputBalanceBefore = inputToken.balanceOf(user);
        uint256 vaultTotalDepositsBefore = vault.totalDeposits();

        // Expect events
        vm.expectEmit(true, false, false, true);
        emit RewardsClaimed(user, FLAX_VALUE);
        vm.expectEmit(true, false, false, true);
        emit Withdrawn(user, WITHDRAW_AMOUNT);

        // Perform withdrawal
        vm.prank(user);
        vault.withdraw(WITHDRAW_AMOUNT, false, 0);

        // Check balances
        assertEq(inputToken.balanceOf(user), userInputBalanceBefore + WITHDRAW_AMOUNT, "Incorrect user inputToken balance");
        assertEq(vault.surplusInputToken(), surplusAmount - WITHDRAW_AMOUNT, "Incorrect surplusInputToken");
        assertEq(vault.totalDeposits(), vaultTotalDepositsBefore - WITHDRAW_AMOUNT, "Incorrect totalDeposits");
    }

    function testWithdrawWithShortfall() public {
        // Deposit to enable withdrawal
        vm.prank(user);
        vault.deposit(WITHDRAW_AMOUNT);

        // Configure yieldSource
        uint256 shortfallAmount = WITHDRAW_AMOUNT - 10 * 1e18;
        yieldSource.setReturnValues(shortfallAmount, FLAX_VALUE);
        inputToken.mint(address(yieldSource), shortfallAmount);

        // Test with protectLoss = true
        vm.expectRevert("Shortfall exceeds surplus");
        vm.prank(user);
        vault.withdraw(WITHDRAW_AMOUNT, true, 0);

        // Test with protectLoss = false
        uint256 userInputBalanceBefore = inputToken.balanceOf(user);
        uint256 userFlaxBalanceBefore = flaxToken.balanceOf(user);
        uint256 vaultTotalDepositsBefore = vault.totalDeposits();

        // Expect events
        vm.expectEmit(true, false, false, true);
        emit RewardsClaimed(user, FLAX_VALUE);
        vm.expectEmit(true, false, false, true);
        emit Withdrawn(user, shortfallAmount); // Updated to match new contract

        // Perform withdrawal
        vm.prank(user);
        vault.withdraw(WITHDRAW_AMOUNT, false, 0);

        // Check balances
        assertEq(inputToken.balanceOf(user), userInputBalanceBefore + shortfallAmount, "Incorrect user inputToken balance");
        assertEq(flaxToken.balanceOf(user), userFlaxBalanceBefore + FLAX_VALUE, "Incorrect user flax balance");
        assertEq(vault.totalDeposits(), vaultTotalDepositsBefore - WITHDRAW_AMOUNT, "Incorrect totalDeposits");
        assertEq(vault.surplusInputToken(), 0, "Surplus should be zero");
    }
}