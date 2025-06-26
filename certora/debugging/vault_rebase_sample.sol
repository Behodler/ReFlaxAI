// Sample implementation of Vault.sol with rebase multiplier for emergency withdrawals
// This shows the key changes needed to implement the rebase solution

pragma solidity ^0.8.20;

contract Vault is Ownable, ReentrancyGuard {
    // ... existing state variables ...
    
    /// @notice Rebase multiplier for handling emergency withdrawals (18 decimals, 1e18 = 1.0)
    /// @dev When set to 0, all user deposits become effectively 0 and vault is disabled
    uint256 public rebaseMultiplier = 1e18;
    
    // ... existing events ...
    
    /// @notice Emitted when rebase multiplier changes
    event RebaseMultiplierUpdated(uint256 oldMultiplier, uint256 newMultiplier);
    
    /// @notice Emitted when vault is permanently disabled
    event VaultPermanentlyDisabled();
    
    // ... existing modifiers ...
    
    /// @notice Prevents operations when vault is permanently disabled (rebase = 0)
    modifier notPermanentlyDisabled() {
        require(rebaseMultiplier > 0, "Vault permanently disabled");
        _;
    }
    
    // ... constructor unchanged ...
    
    /// @notice Get a user's effective deposit amount after applying rebase multiplier
    /// @param user The user address
    /// @return The effective deposit amount
    function getEffectiveDeposit(address user) public view returns (uint256) {
        return (originalDeposits[user] * rebaseMultiplier) / 1e18;
    }
    
    /// @notice Get the effective total deposits after applying rebase multiplier
    /// @return The effective total deposits
    function getEffectiveTotalDeposits() public view returns (uint256) {
        return (totalDeposits * rebaseMultiplier) / 1e18;
    }
    
    /// @notice Deposits input tokens into the yield source
    /// @param amount The amount of input tokens to deposit
    function deposit(uint256 amount) external nonReentrant notInEmergencyState notPermanentlyDisabled {
        require(amount > 0, "Amount must be greater than 0");
        
        inputToken.safeTransferFrom(msg.sender, address(this), amount);
        
        // Forward tokens to yield source
        inputToken.safeTransfer(yieldSource, amount);
        uint256 yieldTokens = IYieldsSource(yieldSource).deposit(amount);
        
        // Update user and total deposits (raw amounts, rebase will be applied on reads)
        originalDeposits[msg.sender] += amount;
        totalDeposits += amount;
        
        emit Deposited(msg.sender, amount);
    }
    
    /// @notice Withdraws tokens from the vault
    /// @param amount The amount to withdraw from user's effective deposit
    /// @param protectLoss If true, reverts when shortfall exceeds surplus
    /// @param sFlaxAmount Amount of sFlax to burn for bonus rewards
    function withdraw(uint256 amount, bool protectLoss, uint256 sFlaxAmount) external nonReentrant notPermanentlyDisabled {
        require(canWithdraw(), "Withdrawal not allowed");
        require(getEffectiveDeposit(msg.sender) >= amount, "Insufficient effective deposit");
        
        // Calculate the raw amount to withdraw from yield source
        // If rebase multiplier is 1e18, this equals amount
        // If rebase multiplier is different, we need to adjust
        uint256 rawAmountToWithdraw = (amount * 1e18) / rebaseMultiplier;
        require(originalDeposits[msg.sender] >= rawAmountToWithdraw, "Insufficient raw deposit");
        
        uint256 balanceBefore = inputToken.balanceOf(address(this));
        (uint256 received, uint256 flaxValue) = IYieldsSource(yieldSource).withdraw(rawAmountToWithdraw);
        uint256 balanceAfter = inputToken.balanceOf(address(this));
        require(balanceAfter >= balanceBefore + received, "Balance mismatch");

        uint256 totalFlax = flaxValue;

        if (sFlaxAmount > 0 && flaxPerSFlax > 0) {
            uint256 flaxBoost = (sFlaxAmount * flaxPerSFlax) / 1e18;
            sFlaxToken.safeTransferFrom(msg.sender, address(this), sFlaxAmount);
            IBurnableERC20(address(sFlaxToken)).burn(sFlaxAmount);
            totalFlax += flaxBoost;
            emit SFlaxBurned(msg.sender, sFlaxAmount, flaxBoost);
        }

        if (totalFlax > 0) {
            flaxToken.safeTransfer(msg.sender, totalFlax);
            emit RewardsClaimed(msg.sender, totalFlax);
        }

        // Update raw deposits
        originalDeposits[msg.sender] -= rawAmountToWithdraw;
        totalDeposits -= rawAmountToWithdraw;

        // Handle surplus/shortfall based on received vs amount (effective amount user should get)
        if (received > amount) {
            surplusInputToken += received - amount;
            inputToken.safeTransfer(msg.sender, amount);
        } else if (received < amount) {
            uint256 shortfall = amount - received;
            if (surplusInputToken >= shortfall) {
                surplusInputToken -= shortfall;
                inputToken.safeTransfer(msg.sender, amount);
            } else if (protectLoss) {
                revert("Shortfall exceeds surplus");
            } else {
                inputToken.safeTransfer(msg.sender, received);
                emit Withdrawn(msg.sender, amount); // Note: user receives less than requested
                return;
            }
        } else {
            inputToken.safeTransfer(msg.sender, amount);
        }

        emit Withdrawn(msg.sender, amount);
    }
    
    /// @notice Claims accumulated rewards from the yield source
    /// @param sFlaxAmount Amount of sFlax to burn for bonus rewards
    function claimRewards(uint256 sFlaxAmount) external nonReentrant notInEmergencyState notPermanentlyDisabled {
        // ... unchanged from original ...
    }
    
    /// @notice Migrates all funds to a new yield source
    /// @param newYieldSource Address of the new yield source contract
    function migrateYieldSource(address newYieldSource) external onlyOwner nonReentrant notInEmergencyState notPermanentlyDisabled {
        // ... unchanged from original ...
    }
    
    /// @notice Emergency function to withdraw from yield source and recover tokens
    /// @param token Address of the token to withdraw
    /// @param recipient Address to receive the tokens
    /// @dev Sets rebase multiplier to 0, permanently disabling the vault
    function emergencyWithdrawFromYieldSource(address token, address recipient) external onlyOwner {
        require(emergencyState, "Not in emergency state");
        
        // First withdraw all funds from yield source if it's the input token
        if (token == address(inputToken) && totalDeposits > 0) {
            (uint256 received, ) = IYieldsSource(yieldSource).withdraw(totalDeposits);
            
            // Set rebase multiplier to 0 - this makes all user deposits effectively 0
            uint256 oldMultiplier = rebaseMultiplier;
            rebaseMultiplier = 0;
            
            surplusInputToken += received;
            
            emit RebaseMultiplierUpdated(oldMultiplier, 0);
            emit VaultPermanentlyDisabled();
        }
        
        // Now withdraw the token from this contract
        IERC20 tokenContract = IERC20(token);
        uint256 balance = tokenContract.balanceOf(address(this));
        
        if (balance > 0) {
            tokenContract.safeTransfer(recipient, balance);
            emit EmergencyWithdrawal(token, recipient, balance);
        }
    }
    
    // ... rest of contract unchanged ...
}