// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

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
        assertEq(vault.getEffectiveDeposit(user), DEPOSIT_AMOUNT, "effectiveDeposit incorrect");
        assertEq(vault.getEffectiveTotalDeposits(), DEPOSIT_AMOUNT, "effectiveTotalDeposits incorrect");

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
        assertEq(vault.getEffectiveDeposit(user), 0, "Effective deposit should be zero after full withdrawal");
        assertEq(vault.getEffectiveTotalDeposits(), 0, "Effective total deposits should be zero");
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
        assertEq(vault.getEffectiveTotalDeposits(), 0, "Effective total deposits should be zero");
        assertEq(vault.rebaseMultiplier(), 0, "Rebase multiplier should be zero");
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

    function testPermanentlyDisabledVault() public {
        // Make a deposit first
        vm.prank(user);
        vault.deposit(DEPOSIT_AMOUNT);
        
        // Set emergency state and trigger emergency withdrawal
        vm.prank(vault.owner());
        vault.setEmergencyState(true);
        
        // Setup yield source to return funds
        yieldSource.setReturnValues(DEPOSIT_AMOUNT, 0);
        inputToken.mint(address(yieldSource), DEPOSIT_AMOUNT);
        
        // Emergency withdraw input token
        vm.prank(vault.owner());
        vault.emergencyWithdrawFromYieldSource(address(inputToken), vault.owner());
        
        // Verify vault is permanently disabled
        assertEq(vault.rebaseMultiplier(), 0, "Rebase multiplier should be 0");
        assertEq(vault.getEffectiveDeposit(user), 0, "User effective deposit should be 0");
        assertEq(vault.getEffectiveTotalDeposits(), 0, "Total effective deposits should be 0");
        
        // Disable emergency state to test permanent disable check
        vm.prank(vault.owner());
        vault.setEmergencyState(false);
        
        // Test all operations fail when permanently disabled
        vm.startPrank(user);
        
        // Deposit should fail
        inputToken.approve(address(vault), DEPOSIT_AMOUNT);
        vm.expectRevert("Vault permanently disabled");
        vault.deposit(DEPOSIT_AMOUNT);
        
        // Withdraw should fail
        vm.expectRevert("Vault permanently disabled");
        vault.withdraw(1, false, 0);
        
        // Claim rewards should fail
        vm.expectRevert("Vault permanently disabled");
        vault.claimRewards(0);
        
        vm.stopPrank();
        
        // Migration should also fail
        MockYieldSource newYieldSource = new MockYieldSource(address(inputToken));
        vm.prank(vault.owner());
        vm.expectRevert("Vault permanently disabled");
        vault.migrateYieldSource(address(newYieldSource));
    }

    function testEffectiveDepositsTracking() public {
        // Test multiple users with different deposits
        address user2 = address(0x5678);
        address user3 = address(0x9ABC);
        
        inputToken.mint(user2, INITIAL_DEPOSIT);
        inputToken.mint(user3, INITIAL_DEPOSIT);
        
        // User 1 deposits 100
        vm.startPrank(user);
        inputToken.approve(address(vault), DEPOSIT_AMOUNT);
        vault.deposit(DEPOSIT_AMOUNT);
        vm.stopPrank();
        
        // User 2 deposits 200
        vm.startPrank(user2);
        inputToken.approve(address(vault), 200 * 1e18);
        vault.deposit(200 * 1e18);
        vm.stopPrank();
        
        // User 3 deposits 300
        vm.startPrank(user3);
        inputToken.approve(address(vault), 300 * 1e18);
        vault.deposit(300 * 1e18);
        vm.stopPrank();
        
        // Verify effective deposits
        assertEq(vault.getEffectiveDeposit(user), 100 * 1e18, "User1 effective deposit");
        assertEq(vault.getEffectiveDeposit(user2), 200 * 1e18, "User2 effective deposit");
        assertEq(vault.getEffectiveDeposit(user3), 300 * 1e18, "User3 effective deposit");
        assertEq(vault.getEffectiveTotalDeposits(), 600 * 1e18, "Total effective deposits");
        
        // User 2 partially withdraws
        yieldSource.setReturnValues(50 * 1e18, 0);
        inputToken.mint(address(yieldSource), 50 * 1e18);
        vm.prank(user2);
        vault.withdraw(50 * 1e18, false, 0);
        
        // Verify updated effective deposits
        assertEq(vault.getEffectiveDeposit(user2), 150 * 1e18, "User2 effective deposit after partial withdrawal");
        assertEq(vault.getEffectiveTotalDeposits(), 550 * 1e18, "Total effective deposits after withdrawal");
    }

    // ====== MUTATION TESTING - SURVIVING MUTANT KILLERS ======

    function testConstructorAcceptsValidAddresses() public {
        // This test verifies constructor works with valid addresses
        // Mutations that change constructor logic would break this
        Vault newVault = new Vault(
            address(flaxToken),
            address(sFlaxToken),
            address(inputToken),
            address(yieldSource),
            priceTilter
        );
        
        // Verify all addresses are set correctly
        assertEq(address(newVault.flaxToken()), address(flaxToken), "FlaxToken should be set");
        assertEq(address(newVault.sFlaxToken()), address(sFlaxToken), "sFlaxToken should be set");
        assertEq(address(newVault.inputToken()), address(inputToken), "InputToken should be set");
        assertEq(newVault.yieldSource(), address(yieldSource), "YieldSource should be set");
        assertEq(newVault.priceTilter(), priceTilter, "PriceTilter should be set");
        assertEq(newVault.rebaseMultiplier(), 1e18, "RebaseMultiplier should be 1e18");
        assertFalse(newVault.emergencyState(), "EmergencyState should be false");
    }

    function testConstructorSetsOwnerCorrectly() public {
        // This test kills Mutation #3: DeleteExpressionMutation on _transferOwnership
        address expectedOwner = address(this);
        
        Vault newVault = new Vault(
            address(flaxToken),
            address(sFlaxToken),
            address(inputToken),
            address(yieldSource),
            priceTilter
        );
        
        assertEq(newVault.owner(), expectedOwner, "Owner should be set to deployer");
        assertNotEq(newVault.owner(), address(0), "Owner should not be zero address");
    }

    function testOnlyOwnerCanSetFlaxPerSFlax() public {
        // This test kills Mutation #4 & #5: DeleteExpressionMutation on _checkOwner and IfStatementMutation
        uint256 newRate = 2e17; // 0.2 flax per sFlax
        
        // Non-owner should fail
        vm.expectRevert();
        vm.prank(user);
        vault.setFlaxPerSFlax(newRate);
        
        // Owner should succeed
        vm.prank(vault.owner());
        vault.setFlaxPerSFlax(newRate);
        
        assertEq(vault.flaxPerSFlax(), newRate, "FlaxPerSFlax should be updated");
    }

    function testOnlyOwnerCanSetEmergencyState() public {
        // This test kills access control mutations
        // Non-owner should fail
        vm.expectRevert();
        vm.prank(user);
        vault.setEmergencyState(true);
        
        // Owner should succeed
        vm.prank(vault.owner());
        vault.setEmergencyState(true);
        
        assertTrue(vault.emergencyState(), "Emergency state should be set");
    }

    function testOnlyOwnerCanCallEmergencyWithdraw() public {
        // This test kills access control mutations on emergency functions
        MockERC20 testToken = new MockERC20();
        testToken.mint(address(vault), 100e18);
        
        // Non-owner should fail
        vm.expectRevert();
        vm.prank(user);
        vault.emergencyWithdraw(address(testToken), user);
        
        // Owner should succeed
        vm.prank(vault.owner());
        vault.emergencyWithdraw(address(testToken), vault.owner());
    }

    function testOnlyOwnerCanCallEmergencyWithdrawETH() public {
        // This test kills access control mutations on ETH emergency functions
        deal(address(vault), 1 ether);
        
        // Non-owner should fail
        vm.expectRevert();
        vm.prank(user);
        vault.emergencyWithdrawETH(payable(user));
        
        // Owner should succeed - send to user address which can receive ETH
        vm.prank(vault.owner());
        vault.emergencyWithdrawETH(payable(user));
        
        assertEq(user.balance, 1 ether, "User should have received ETH");
        assertEq(address(vault).balance, 0, "Vault should have no ETH left");
    }

    function testOnlyOwnerCanMigrateYieldSource() public {
        // This test kills access control mutations on migration
        MockYieldSource newYieldSource = new MockYieldSource(address(inputToken));
        
        // Non-owner should fail
        vm.expectRevert();
        vm.prank(user);
        vault.migrateYieldSource(address(newYieldSource));
        
        // Setup and owner should succeed
        yieldSource.setReturnValues(0, 0);
        vm.prank(vault.owner());
        vault.migrateYieldSource(address(newYieldSource));
    }

    function testDepositRejectsZeroAmount() public {
        // This test kills mutations that remove amount validation
        vm.expectRevert("Deposit amount must be greater than 0");
        vm.prank(user);
        vault.deposit(0);
    }

    function testWithdrawRejectsInsufficientBalance() public {
        // This test kills mutations that remove balance validation
        vm.expectRevert("Insufficient effective deposit");
        vm.prank(user);
        vault.withdraw(100 * 1e18, false, 0); // User hasn't deposited anything
    }

    function testShortfallProtectionWorks() public {
        // This test kills mutations that remove protectLoss validation
        vm.prank(user);
        vault.deposit(DEPOSIT_AMOUNT);
        
        // Configure shortfall scenario
        uint256 shortfallAmount = DEPOSIT_AMOUNT - 10 * 1e18;
        yieldSource.setReturnValues(shortfallAmount, 0);
        inputToken.mint(address(yieldSource), shortfallAmount);
        
        // Should revert with protectLoss=true
        vm.expectRevert("Shortfall exceeds surplus");
        vm.prank(user);
        vault.withdraw(DEPOSIT_AMOUNT, true, 0);
    }

    function testBoundaryConditions() public {
        // Test edge cases that mutations might bypass
        vm.startPrank(user);
        
        // Deposit exactly 1 wei
        vault.deposit(1);
        assertEq(vault.originalDeposits(user), 1, "Should handle 1 wei deposit");
        
        // Withdraw exactly what was deposited
        yieldSource.setReturnValues(1, 0);
        inputToken.mint(address(yieldSource), 1);
        vault.withdraw(1, false, 0);
        assertEq(vault.originalDeposits(user), 0, "Should handle 1 wei withdrawal");
        
        vm.stopPrank();
    }

    function testRequireStatementValidation() public {
        // Test all require statements work correctly
        vm.startPrank(user);
        
        // Test deposit with insufficient allowance
        inputToken.approve(address(vault), 0);
        vm.expectRevert();
        vault.deposit(DEPOSIT_AMOUNT);
        
        // Fix allowance
        inputToken.approve(address(vault), type(uint256).max);
        
        // Test withdraw without protectLoss
        vault.deposit(DEPOSIT_AMOUNT);
        yieldSource.setReturnValues(DEPOSIT_AMOUNT - 1, 0); // Shortfall
        inputToken.mint(address(yieldSource), DEPOSIT_AMOUNT - 1);
        
        // Should succeed with protectLoss=false
        vault.withdraw(DEPOSIT_AMOUNT, false, 0);
        
        vm.stopPrank();
    }
}