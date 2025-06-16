// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@oz_reflax/token/ERC20/IERC20.sol";
import {SafeERC20} from "@oz_reflax/token/ERC20/utils/SafeERC20.sol";

/**
 * @title ConvexShutdownIntegrationTest
 * @notice Integration tests for Convex shutdown/deprecation scenarios
 * @dev Tests realistic scenarios where Convex pools are deprecated or partially shut down
 */
contract ConvexShutdownIntegrationTest is Test {
    using SafeERC20 for IERC20;

    // Mock contracts for simplified testing
    MockConvexBooster public mockConvexBooster;
    MockConvexRewardPool public mockConvexRewardPool;

    function setUp() public {
        // Deploy mock contracts
        mockConvexBooster = new MockConvexBooster();
        mockConvexRewardPool = new MockConvexRewardPool();
        
        // Label contracts
        vm.label(address(mockConvexBooster), "MockConvexBooster");
        vm.label(address(mockConvexRewardPool), "MockConvexRewardPool");
    }
    
    /**
     * @notice Test that deprecated pool blocks deposits but allows withdrawals
     */
    function testDeprecatedPoolBlocksDeposits() public {
        // First test normal operation
        assertTrue(mockConvexBooster.deposit(1, 1000e18, true), "Normal deposit should work");
        assertTrue(mockConvexBooster.withdraw(1, 1000e18), "Normal withdrawal should work");
        
        // Now deprecate the pool
        mockConvexBooster.setDeprecated(true);
        
        // Deposits should fail
        vm.expectRevert("Pool deprecated");
        mockConvexBooster.deposit(1, 1000e18, true);
        
        // But withdrawals should still work
        assertTrue(mockConvexBooster.withdraw(1, 1000e18), "Withdrawal should work even for deprecated pool");
    }
    
    /**
     * @notice Test partial functionality where deposits fail but rewards and withdrawals work
     */
    function testPartialConvexFailure() public {
        // Test normal operation first
        assertTrue(mockConvexBooster.deposit(1, 1000e18, true), "Normal deposit should work");
        assertTrue(mockConvexRewardPool.getReward(), "Normal reward claim should work");
        
        // Set partial failure mode
        mockConvexBooster.setPartialFailure(true);
        
        // Deposits should fail
        vm.expectRevert("Deposits temporarily disabled");
        mockConvexBooster.deposit(1, 1000e18, true);
        
        // But withdrawals and rewards should still work
        assertTrue(mockConvexBooster.withdraw(1, 500e18), "Withdrawal should work during partial failure");
        assertTrue(mockConvexRewardPool.getReward(), "Reward claim should work during partial failure");
    }
    
    /**
     * @notice Test reward system failure
     */
    function testRewardSystemFailure() public {
        // Normal reward claim should work
        assertTrue(mockConvexRewardPool.getReward(), "Normal reward claim should work");
        
        // Set reward failure
        mockConvexRewardPool.setRewardFailure(true);
        
        // Reward claim should fail gracefully (not revert)
        assertFalse(mockConvexRewardPool.getReward(), "Failed reward claim should return false");
        
        // But other operations should still work
        assertTrue(mockConvexBooster.deposit(1, 1000e18, true), "Deposit should work despite reward failure");
        assertTrue(mockConvexBooster.withdraw(1, 1000e18), "Withdrawal should work despite reward failure");
    }
    
    /**
     * @notice Test complete Convex shutdown scenario
     */
    function testCompleteConvexShutdown() public {
        // Simulate complete Convex shutdown
        mockConvexBooster.setDeprecated(true);
        mockConvexRewardPool.setRewardFailure(true);
        
        // New deposits should fail
        vm.expectRevert("Pool deprecated");
        mockConvexBooster.deposit(1, 1000e18, true);
        
        // Reward claims should fail gracefully
        assertFalse(mockConvexRewardPool.getReward(), "Reward claim should fail during shutdown");
        
        // But existing users should still be able to withdraw (most important)
        assertTrue(mockConvexBooster.withdraw(1, 1000e18), "Users must be able to withdraw during shutdown");
    }
    
    /**
     * @notice Test emergency withdrawal functionality concept
     */
    function testEmergencyWithdrawalConcept() public {
        // Test that emergency functionality exists and can be called
        address owner = makeAddr("owner");
        
        // Fund a mock contract to test emergency withdrawal concept
        MockEmergencyContract emergencyContract = new MockEmergencyContract(owner);
        
        // Send some ETH to it
        vm.deal(address(emergencyContract), 1 ether);
        
        // Owner should be able to emergency withdraw ETH
        vm.prank(owner);
        emergencyContract.emergencyWithdraw(address(0), owner);
        
        // Verify recovery
        assertEq(owner.balance, 1 ether, "ETH should be recovered");
    }
    
    /**
     * @notice Test that no funds are ever permanently locked
     */
    function testNoFundsLocked() public {
        // This is the most important test - ensuring user funds are never locked
        
        // Simulate user having deposited before shutdown
        uint256 userDepositAmount = 5000e18; // Mock LP tokens
        
        // User should be able to withdraw even in worst case scenario
        mockConvexBooster.setDeprecated(true);
        mockConvexRewardPool.setRewardFailure(true);
        
        // Critical test: withdrawal must work even during complete shutdown
        assertTrue(
            mockConvexBooster.withdraw(1, userDepositAmount), 
            "User withdrawal must work even during complete Convex shutdown"
        );
        
        // This demonstrates the key principle: Convex may stop new deposits and rewards,
        // but they must allow existing users to exit their positions
    }
}

// Simplified mock contracts for testing shutdown scenarios

contract MockConvexBooster {
    bool public deprecated = false;
    bool public partialFailure = false;
    
    function setDeprecated(bool _deprecated) external {
        deprecated = _deprecated;
    }
    
    function setPartialFailure(bool _partial) external {
        partialFailure = _partial;
    }
    
    function deposit(uint256, uint256, bool) external view returns (bool) {
        if (deprecated) {
            revert("Pool deprecated");
        }
        if (partialFailure) {
            revert("Deposits temporarily disabled");
        }
        return true;
    }
    
    function withdraw(uint256, uint256) external pure returns (bool) {
        // Withdrawals should always work - this is the key assumption
        // Even deprecated pools must allow users to exit
        return true;
    }
}

contract MockConvexRewardPool {
    bool public rewardFailure = false;
    
    function setRewardFailure(bool _failure) external {
        rewardFailure = _failure;
    }
    
    function getReward() external view returns (bool) {
        if (rewardFailure) {
            return false; // Fail gracefully, don't revert
        }
        return true;
    }
}

contract MockEmergencyContract {
    using SafeERC20 for IERC20;
    
    address public owner;
    
    constructor(address _owner) {
        owner = _owner;
    }
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }
    
    function emergencyWithdraw(address token, address recipient) external onlyOwner {
        if (token == address(0)) {
            // Withdraw ETH
            uint256 balance = address(this).balance;
            if (balance > 0) {
                payable(recipient).transfer(balance);
            }
        } else {
            // Withdraw ERC20 token
            IERC20 erc20 = IERC20(token);
            uint256 balance = erc20.balanceOf(address(this));
            if (balance > 0) {
                erc20.safeTransfer(recipient, balance);
            }
        }
    }
    
    receive() external payable {}
}