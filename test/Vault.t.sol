// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {Vault} from "../src/vault/Vault.sol";
import {MockERC20, MockYieldSource, MockPriceTilter} from "./mocks/Mocks.sol";
import {IERC20} from "@oz_reflax/token/ERC20/IERC20.sol";
import {IPriceTilter} from "../src/priceTilting/IPriceTilter.sol";
import {SafeERC20} from "@oz_reflax/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@oz_reflax/access/Ownable.sol";

// Additional mock for testing migration with rewards
contract MockYieldSourceWithRewards {
    using SafeERC20 for IERC20;

    IERC20 public inputToken;
    uint256 public totalDeposited;
    uint256 private _withdrawInputAmount;
    uint256 private _flaxValue;
    uint256 private _claimAndSellReturn;

    constructor(address _inputToken) {
        inputToken = IERC20(_inputToken);
    }

    function deposit(uint256 amount) external returns (uint256) {
        inputToken.safeTransferFrom(msg.sender, address(this), amount);
        totalDeposited += amount;
        return amount;
    }

    function withdraw(uint256 amount) external returns (uint256 inputTokenAmount, uint256 flaxValue) {
        require(totalDeposited >= amount, "Insufficient deposited amount");
        totalDeposited -= amount;
        inputTokenAmount = _withdrawInputAmount;
        flaxValue = _flaxValue;
        inputToken.safeTransfer(msg.sender, inputTokenAmount);
    }

    function claimRewards() external returns (uint256) {
        return _flaxValue;
    }

    function claimAndSellForInputToken() external returns (uint256 inputTokenAmount) {
        if (_claimAndSellReturn > 0) {
            inputToken.safeTransfer(msg.sender, _claimAndSellReturn);
        }
        return _claimAndSellReturn;
    }

    function setReturnValues(uint256 inputTokenAmount, uint256 flaxValue) external {
        _withdrawInputAmount = inputTokenAmount;
        _flaxValue = flaxValue;
    }
    
    function setClaimAndSellReturn(uint256 amount) external {
        _claimAndSellReturn = amount;
    }
}

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
    event EmergencyStateChanged(bool state);
    event EmergencyWithdrawal(address indexed token, address indexed recipient, uint256 amount);
    event YieldSourceMigrated(address indexed oldYieldSource, address indexed newYieldSource);

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
        assertEq(inputToken.balanceOf(address(yieldSource)), INITIAL_DEPOSIT + DEPOSIT_AMOUNT, "YieldSource balance incorrect");
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

    function testSetEmergencyState() public {
        // Test that only owner can set emergency state
        vm.expectRevert();
        vm.prank(user);
        vault.setEmergencyState(true);

        // Test owner can set emergency state
        vm.expectEmit(false, false, false, true);
        emit EmergencyStateChanged(true);
        
        vm.prank(vault.owner());
        vault.setEmergencyState(true);
        
        assertTrue(vault.emergencyState(), "Emergency state should be true");

        // Test setting back to false
        vm.expectEmit(false, false, false, true);
        emit EmergencyStateChanged(false);
        
        vm.prank(vault.owner());
        vault.setEmergencyState(false);
        
        assertFalse(vault.emergencyState(), "Emergency state should be false");
    }

    function testEmergencyStateBlocksOperations() public {
        // Set emergency state
        vm.prank(vault.owner());
        vault.setEmergencyState(true);

        // Test deposit blocked
        vm.expectRevert("Contract is in emergency state");
        vm.prank(user);
        vault.deposit(DEPOSIT_AMOUNT);

        // Test claimRewards blocked
        vm.expectRevert("Contract is in emergency state");
        vm.prank(user);
        vault.claimRewards(0);

        // Test migrateYieldSource blocked
        MockYieldSource newYieldSource = new MockYieldSource(address(inputToken));
        vm.prank(vault.owner());
        vm.expectRevert("Contract is in emergency state");
        vault.migrateYieldSource(address(newYieldSource));

        // Test withdraw still works (not blocked by emergency state)
        // First deposit while not in emergency state
        vm.prank(vault.owner());
        vault.setEmergencyState(false);
        
        vm.prank(user);
        vault.deposit(DEPOSIT_AMOUNT);
        
        vm.prank(vault.owner());
        vault.setEmergencyState(true);
        
        yieldSource.setReturnValues(DEPOSIT_AMOUNT, 0);
        inputToken.mint(address(yieldSource), DEPOSIT_AMOUNT);
        
        vm.prank(user);
        vault.withdraw(DEPOSIT_AMOUNT, false, 0);
    }

    function testEmergencyWithdrawTokens() public {
        // Setup: mint some tokens to vault
        MockERC20 otherToken = new MockERC20();
        uint256 amount = 500 * 1e18;
        otherToken.mint(address(vault), amount);

        // Test that only owner can call
        vm.expectRevert();
        vm.prank(user);
        vault.emergencyWithdraw(address(otherToken), user);

        // Test successful emergency withdrawal
        address recipient = address(0x9999);
        
        vm.expectEmit(true, true, false, true);
        emit EmergencyWithdrawal(address(otherToken), recipient, amount);
        
        vm.prank(vault.owner());
        vault.emergencyWithdraw(address(otherToken), recipient);
        
        assertEq(otherToken.balanceOf(recipient), amount, "Recipient should have received tokens");
        assertEq(otherToken.balanceOf(address(vault)), 0, "Vault should have no tokens left");

        // Test withdrawal with no balance
        vm.prank(vault.owner());
        vault.emergencyWithdraw(address(otherToken), recipient); // Should not revert
    }

    function testEmergencyWithdrawETH() public {
        // Send ETH to vault
        uint256 ethAmount = 5 ether;
        deal(address(vault), ethAmount);

        // Test that only owner can call
        vm.expectRevert();
        vm.prank(user);
        vault.emergencyWithdrawETH(payable(user));

        // Test successful ETH withdrawal
        address payable recipient = payable(address(0x9999));
        uint256 recipientBalanceBefore = recipient.balance;
        
        vm.expectEmit(true, true, false, true);
        emit EmergencyWithdrawal(address(0), recipient, ethAmount);
        
        vm.prank(vault.owner());
        vault.emergencyWithdrawETH(recipient);
        
        assertEq(recipient.balance, recipientBalanceBefore + ethAmount, "Recipient should have received ETH");
        assertEq(address(vault).balance, 0, "Vault should have no ETH left");

        // Test withdrawal with no balance
        vm.prank(vault.owner());
        vault.emergencyWithdrawETH(recipient); // Should not revert
    }

    function testEmergencyWithdrawFromYieldSource() public {
        // First, make a deposit to have funds in yield source
        vm.prank(user);
        vault.deposit(DEPOSIT_AMOUNT);

        // Test that it requires emergency state
        address recipient = address(0x9999);
        vm.prank(vault.owner());
        vm.expectRevert("Not in emergency state");
        vault.emergencyWithdrawFromYieldSource(address(inputToken), recipient);

        // Set emergency state
        vm.prank(vault.owner());
        vault.setEmergencyState(true);

        // Test that only owner can call
        vm.expectRevert();
        vm.prank(user);
        vault.emergencyWithdrawFromYieldSource(address(inputToken), recipient);

        // Setup yield source to return funds
        yieldSource.setReturnValues(DEPOSIT_AMOUNT, 0);
        inputToken.mint(address(yieldSource), DEPOSIT_AMOUNT);

        // Test successful emergency withdrawal from yield source
        vm.expectEmit(true, true, false, true);
        emit EmergencyWithdrawal(address(inputToken), recipient, DEPOSIT_AMOUNT);
        
        vm.prank(vault.owner());
        vault.emergencyWithdrawFromYieldSource(address(inputToken), recipient);
        
        assertEq(inputToken.balanceOf(recipient), DEPOSIT_AMOUNT, "Recipient should have received input tokens");
        assertEq(vault.totalDeposits(), 0, "Total deposits should be zero");
        assertEq(vault.surplusInputToken(), DEPOSIT_AMOUNT, "Surplus should equal withdrawn amount");

        // Test emergency withdrawal of non-input token
        MockERC20 otherToken = new MockERC20();
        otherToken.mint(address(vault), 100 * 1e18);
        
        vm.expectEmit(true, true, false, true);
        emit EmergencyWithdrawal(address(otherToken), recipient, 100 * 1e18);
        
        vm.prank(vault.owner());
        vault.emergencyWithdrawFromYieldSource(address(otherToken), recipient);
        
        assertEq(otherToken.balanceOf(recipient), 100 * 1e18, "Recipient should have received other tokens");
    }

    function testReceiveETH() public {
        // Test that vault can receive ETH
        uint256 ethAmount = 1 ether;
        uint256 vaultBalanceBefore = address(vault).balance;
        
        (bool success,) = address(vault).call{value: ethAmount}("");
        assertTrue(success, "ETH transfer should succeed");
        
        assertEq(address(vault).balance, vaultBalanceBefore + ethAmount, "Vault should have received ETH");
    }

    function testMigrateYieldSource() public {
        // Create new yield source for migration
        MockYieldSource newYieldSource = new MockYieldSource(address(inputToken));
        
        // Setup initial deposit
        vm.prank(user);
        vault.deposit(DEPOSIT_AMOUNT);
        
        // Test that only owner can migrate
        vm.expectRevert();
        vm.prank(user);
        vault.migrateYieldSource(address(newYieldSource));
        
        // Setup old yield source to return funds during migration
        yieldSource.setReturnValues(DEPOSIT_AMOUNT, 0);
        inputToken.mint(address(yieldSource), DEPOSIT_AMOUNT);
        
        // Test successful migration
        vm.expectEmit(true, true, false, false);
        emit YieldSourceMigrated(address(yieldSource), address(newYieldSource));
        
        vm.prank(vault.owner());
        vault.migrateYieldSource(address(newYieldSource));
        
        assertEq(vault.yieldSource(), address(newYieldSource), "Yield source should be updated");
        assertEq(vault.totalDeposits(), DEPOSIT_AMOUNT, "Total deposits should be preserved");
        assertEq(vault.surplusInputToken(), 0, "Surplus should be zero after migration");
        assertEq(newYieldSource.totalDeposited(), DEPOSIT_AMOUNT, "New yield source should have deposits");
    }

    function testMigrateYieldSourceWithRewards() public {
        // Create new yield source for migration
        MockYieldSource newYieldSource = new MockYieldSource(address(inputToken));
        
        // Setup initial deposit
        vm.prank(user);
        vault.deposit(DEPOSIT_AMOUNT);
        
        // Setup old yield source to return deposit amount plus rewards sold for input tokens
        uint256 rewardTokensAmount = 20 * 1e18;
        yieldSource.setReturnValues(DEPOSIT_AMOUNT, 0);
        inputToken.mint(address(yieldSource), DEPOSIT_AMOUNT);
        
        // Mock the claimAndSellForInputToken to return some amount
        MockYieldSourceWithRewards yieldSourceWithRewards = new MockYieldSourceWithRewards(address(inputToken));
        yieldSourceWithRewards.setReturnValues(DEPOSIT_AMOUNT, 0);
        yieldSourceWithRewards.setClaimAndSellReturn(rewardTokensAmount);
        inputToken.mint(address(yieldSourceWithRewards), DEPOSIT_AMOUNT + rewardTokensAmount);
        
        // Update vault to use the new mock
        vm.prank(vault.owner());
        vault.migrateYieldSource(address(yieldSourceWithRewards));
        
        // Now deposit again and test migration with rewards
        vm.prank(user);
        vault.deposit(DEPOSIT_AMOUNT);
        
        // Migrate to final yield source
        vm.prank(vault.owner());
        vault.migrateYieldSource(address(newYieldSource));
        
        assertEq(vault.yieldSource(), address(newYieldSource), "Yield source should be updated");
        assertEq(vault.totalDeposits(), DEPOSIT_AMOUNT + rewardTokensAmount, "Total deposits should include rewards");
        assertEq(newYieldSource.totalDeposited(), DEPOSIT_AMOUNT + rewardTokensAmount, "New yield source should have all funds");
    }

    function testMigrateYieldSourceWithLoss() public {
        // Create new yield source for migration
        MockYieldSource newYieldSource = new MockYieldSource(address(inputToken));
        
        // Setup initial deposit
        vm.prank(user);
        vault.deposit(DEPOSIT_AMOUNT);
        
        // Setup old yield source to return less than deposited (simulate loss)
        uint256 lossAmount = 10 * 1e18;
        uint256 receivedAmount = DEPOSIT_AMOUNT - lossAmount;
        yieldSource.setReturnValues(receivedAmount, 0);
        inputToken.mint(address(yieldSource), receivedAmount);
        
        // Migrate
        vm.prank(vault.owner());
        vault.migrateYieldSource(address(newYieldSource));
        
        assertEq(vault.yieldSource(), address(newYieldSource), "Yield source should be updated");
        assertEq(vault.totalDeposits(), receivedAmount, "Total deposits should reflect loss");
        assertEq(newYieldSource.totalDeposited(), receivedAmount, "New yield source should have reduced amount");
    }

    function testMigrateYieldSourceBlockedInEmergencyState() public {
        // Create new yield source for migration
        MockYieldSource newYieldSource = new MockYieldSource(address(inputToken));
        
        // Set emergency state
        vm.prank(vault.owner());
        vault.setEmergencyState(true);
        
        // Test migration is blocked
        vm.prank(vault.owner());
        vm.expectRevert("Contract is in emergency state");
        vault.migrateYieldSource(address(newYieldSource));
    }
}