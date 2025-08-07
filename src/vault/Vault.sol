// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IERC20} from "@oz_reflax/token/ERC20/IERC20.sol";
import {SafeERC20} from "@oz_reflax/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@oz_reflax/access/Ownable.sol";
import {ReentrancyGuard} from "@oz_reflax/utils/ReentrancyGuard.sol";
import {IPriceTilter} from "../priceTilting/IPriceTilter.sol";

/**
 * @title IYieldsSource
 * @notice Interface for yield source contracts that manage token deposits and reward generation
 */
interface IYieldsSource {
    /**
     * @notice Deposits tokens into the yield source
     * @param amount The amount of input tokens to deposit
     * @return The amount of yield-bearing tokens received
     */
    function deposit(uint256 amount) external returns (uint256);
    
    /**
     * @notice Withdraws tokens from the yield source
     * @param amount The amount to withdraw
     * @return inputTokenAmount The amount of input tokens received
     * @return flaxValue The value of rewards in Flax tokens
     */
    function withdraw(uint256 amount) external returns (uint256 inputTokenAmount, uint256 flaxValue);
    
    /**
     * @notice Claims accumulated rewards and converts them to Flax value
     * @return The value of claimed rewards in Flax tokens
     */
    function claimRewards() external returns (uint256);
    
    /**
     * @notice Claims rewards and sells them for input tokens
     * @return inputTokenAmount The amount of input tokens received from selling rewards
     */
    function claimAndSellForInputToken() external returns (uint256 inputTokenAmount);
}

/**
 * @title IBurnableERC20
 * @notice Interface for ERC20 tokens with burn functionality
 */
interface IBurnableERC20 is IERC20 {
    /**
     * @notice Burns a specific amount of tokens
     * @param amount The amount of tokens to burn
     */
    function burn(uint256 amount) external;
    
    /**
     * @notice Burns tokens from a specific account (requires approval or special permission)
     * @param account The account to burn tokens from
     * @param amount The amount of tokens to burn
     */
    function burnFrom(address account, uint256 amount) external;
}

// Custom errors for enhanced error handling
error InsufficientBalance(address account, uint256 requested, uint256 available);
error InvalidBurnAmount(uint256 amount, string reason);
error BoostCalculationFailed(uint256 sFlaxAmount, string reason);
error EmergencyStateActive();
error VaultDisabled();
error InvalidExchangeRate(uint256 rate);
error GasEstimationFailed(string operation);

/**
 * @title Vault
 * @author Justin Goro
 * @notice User-facing vault contract for depositing tokens into yield sources and earning Flax rewards
 * @dev Manages deposits, withdrawals, and reward distribution with optional sFlax token burning for boosted rewards
 */
contract Vault is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice The token that users deposit into the vault (e.g., USDC)
    IERC20 public immutable inputToken;
    
    /// @notice The Flax token distributed as rewards
    IERC20 public immutable flaxToken;
    
    /// @notice The sFlax token that can be burned for boosted rewards
    IERC20 public immutable sFlaxToken;
    
    /// @notice The current yield source where deposits are forwarded
    address public yieldSource;
    
    /// @notice The price tilter contract for Flax/ETH operations
    address public immutable priceTilter;
    
    /// @notice Exchange rate for burning sFlax to receive Flax (scaled by 1e18)
    uint256 public flaxPerSFlax;
    
    /// @notice Total amount of input tokens deposited across all users
    uint256 public totalDeposits;
    
    /// @notice Surplus input tokens from yield source operations
    /// @dev Used to offset withdrawal shortfalls from impermanent loss or fees
    uint256 public surplusInputToken;
    
    /// @notice Tracks each user's original deposit amount
    mapping(address => uint256) public originalDeposits;
    
    /// @notice Emergency state flag that prevents deposits, claims, and migrations
    bool public emergencyState;
    
    /// @notice Rebase multiplier for handling emergency withdrawals (18 decimals, 1e18 = 1.0)
    /// @dev When set to 0, all user deposits become effectively 0 and vault is disabled
    uint256 public rebaseMultiplier;
    
    /// @notice Maximum boost percentage that can be applied (in basis points, e.g., 5000 = 50%)
    uint256 public maxBoostPercentage;
    
    /// @notice Base boost rate per sFlax token (in basis points per token, e.g., 100 = 1% per sFlax)
    uint256 public boostRatePerSFlax;
    
    /// @notice Mapping to track if an address is approved to burn sFlax tokens
    mapping(address => bool) public approvedBurners;

    /**
     * @notice Emitted when a user deposits tokens
     * @param user The address of the depositor
     * @param amount The amount of input tokens deposited
     */
    event Deposited(address indexed user, uint256 amount);
    
    /**
     * @notice Emitted when a user claims Flax rewards
     * @param user The address of the user claiming rewards
     * @param flaxAmount The amount of Flax tokens claimed
     */
    event RewardsClaimed(address indexed user, uint256 flaxAmount);
    
    /**
     * @notice Emitted when sFlax is burned for bonus rewards
     * @param user The address burning sFlax
     * @param sFlaxAmount The amount of sFlax burned
     * @param flaxRewarded The amount of bonus Flax received
     */
    event SFlaxBurned(address indexed user, uint256 sFlaxAmount, uint256 flaxRewarded);
    
    /**
     * @notice Emitted when a user withdraws their deposit
     * @param user The address of the withdrawer
     * @param amount The amount of input tokens withdrawn
     */
    event Withdrawn(address indexed user, uint256 amount);
    
    /**
     * @notice Emitted when the Flax per sFlax ratio is updated
     * @param newRatio The new exchange ratio (scaled by 1e18)
     */
    event FlaxPerSFlaxUpdated(uint256 newRatio);
    
    /**
     * @notice Emitted when the yield source is migrated
     * @param oldYieldSource The previous yield source address
     * @param newYieldSource The new yield source address
     */
    event YieldSourceMigrated(address indexed oldYieldSource, address indexed newYieldSource);
    
    /**
     * @notice Emitted when emergency state is changed
     * @param state The new emergency state
     */
    event EmergencyStateChanged(bool state);
    
    /**
     * @notice Emitted when emergency withdrawal is executed
     * @param token The token address withdrawn (address(0) for ETH)
     * @param recipient The recipient of the withdrawal
     * @param amount The amount withdrawn
     */
    event EmergencyWithdrawal(address indexed token, address indexed recipient, uint256 amount);
    
    /**
     * @notice Emitted when rebase multiplier changes
     * @param oldMultiplier The previous rebase multiplier
     * @param newMultiplier The new rebase multiplier
     */
    event RebaseMultiplierUpdated(uint256 oldMultiplier, uint256 newMultiplier);
    
    /**
     * @notice Emitted when vault is permanently disabled
     */
    event VaultPermanentlyDisabled();
    
    /**
     * @notice Emitted when boost calculation parameters are updated
     * @param maxBoostPercentage The new maximum boost percentage
     * @param boostRatePerSFlax The new boost rate per sFlax token
     */
    event BoostParametersUpdated(uint256 maxBoostPercentage, uint256 boostRatePerSFlax);
    
    /**
     * @notice Emitted when boost is calculated for a user
     * @param user The address receiving the boost
     * @param sFlaxAmount The amount of sFlax burned
     * @param boostPercentage The calculated boost percentage
     * @param additionalFlax The additional Flax received from boost
     */
    event BoostCalculated(address indexed user, uint256 sFlaxAmount, uint256 boostPercentage, uint256 additionalFlax);
    
    /**
     * @notice Emitted when an approved burner status is changed
     * @param burner The address whose status changed
     * @param approved Whether the address is now approved
     */
    event ApprovedBurnerUpdated(address indexed burner, bool approved);

    /**
     * @notice Initializes the vault with token addresses and yield source
     * @param _flaxToken Address of the Flax token contract
     * @param _sFlaxToken Address of the sFlax token contract (must implement burn)
     * @param _inputToken Address of the input token (e.g., USDC)
     * @param _yieldSource Initial yield source contract address
     * @param _priceTilter Address of the price tilter contract
     */
    constructor(
        address _flaxToken,
        address _sFlaxToken,
        address _inputToken,
        address _yieldSource,
        address _priceTilter
    ) Ownable(msg.sender) {
        flaxToken = IERC20(_flaxToken);
        sFlaxToken = IERC20(_sFlaxToken);
        inputToken = IERC20(_inputToken);
        yieldSource = _yieldSource;
        priceTilter = _priceTilter;
        emergencyState = false;
        rebaseMultiplier = 1e18; // Initialize to 1.0 (normal operation)
        
        // Initialize boost parameters with reasonable defaults
        maxBoostPercentage = 5000; // 50% max boost
        boostRatePerSFlax = 100;   // 1% per sFlax token (100 basis points)
        flaxPerSFlax = 11 * 1e17;  // Initialize to 1.1 Flax per sFlax (not fallback 1)
        
        // Set this vault as an approved burner for sFlax tokens
        approvedBurners[address(this)] = true;
        emit ApprovedBurnerUpdated(address(this), true);
    }

    /**
     * @notice Modifier to prevent function execution during emergency state
     */
    modifier notInEmergencyState() {
        require(!emergencyState, "Contract is in emergency state");
        _;
    }
    
    /**
     * @notice Modifier to prevent operations when vault is permanently disabled (rebase = 0)
     */
    modifier notPermanentlyDisabled() {
        require(rebaseMultiplier > 0, "Vault permanently disabled");
        _;
    }
    
    /**
     * @notice Get a user's effective deposit amount after applying rebase multiplier
     * @param user The user address
     * @return The effective deposit amount
     */
    function getEffectiveDeposit(address user) public view returns (uint256) {
        return (originalDeposits[user] * rebaseMultiplier) / 1e18;
    }
    
    /**
     * @notice Get the effective total deposits after applying rebase multiplier
     * @return The effective total deposits
     */
    function getEffectiveTotalDeposits() public view returns (uint256) {
        return (totalDeposits * rebaseMultiplier) / 1e18;
    }

    /**
     * @notice Deposits input tokens into the yield source
     * @param amount The amount of input tokens to deposit
     * @dev Tokens are immediately forwarded to the yield source
     */
    function deposit(uint256 amount) external nonReentrant notInEmergencyState notPermanentlyDisabled {
        require(amount > 0, "Deposit amount must be greater than 0");
        inputToken.safeTransferFrom(msg.sender, address(this), amount);
        inputToken.approve(yieldSource, amount);
        uint256 received = IYieldsSource(yieldSource).deposit(amount);
        originalDeposits[msg.sender] += amount;
        totalDeposits += amount;
        emit Deposited(msg.sender, amount);
    }

    /**
     * @notice Withdraws deposited tokens and claims rewards
     * @param amount The amount of input tokens to withdraw
     * @param protectLoss If true, reverts when shortfall exceeds surplus
     * @param sFlaxAmount Amount of sFlax to burn for bonus rewards
     * @dev Uses surplus to cover shortfalls from impermanent loss or fees
     */
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
            // Calculate boost using the new boost calculation system
            uint256 boostPercentage = calculateBoostPercentage(sFlaxAmount);
            uint256 boostMultiplier = (10000 + boostPercentage); // 10000 = 100% in basis points
            uint256 boostedFlaxValue = (flaxValue * boostMultiplier) / 10000;
            uint256 additionalFlaxFromBoost = boostedFlaxValue - flaxValue;
            
            // Transfer and burn sFlax tokens
            sFlaxToken.safeTransferFrom(msg.sender, address(this), sFlaxAmount);
            IBurnableERC20(address(sFlaxToken)).burn(sFlaxAmount);
            
            totalFlax = boostedFlaxValue;
            
            emit SFlaxBurned(msg.sender, sFlaxAmount, additionalFlaxFromBoost);
            emit BoostCalculated(msg.sender, sFlaxAmount, boostPercentage, additionalFlaxFromBoost);
        }

        if (totalFlax > 0) {
            flaxToken.safeTransfer(msg.sender, totalFlax);
            emit RewardsClaimed(msg.sender, totalFlax);
        }

        // Update raw deposits
        originalDeposits[msg.sender] -= rawAmountToWithdraw;
        totalDeposits -= rawAmountToWithdraw;

        uint256 actualWithdrawn;
        if (received > amount) {
            surplusInputToken += received - amount;
            inputToken.safeTransfer(msg.sender, amount);
            actualWithdrawn = amount;
        } else if (received < amount) {
            uint256 shortfall = amount - received;
            if (surplusInputToken >= shortfall) {
                surplusInputToken -= shortfall;
                inputToken.safeTransfer(msg.sender, amount);
                actualWithdrawn = amount;
            } else if (protectLoss) {
                revert("Shortfall exceeds surplus");
            } else {
                inputToken.safeTransfer(msg.sender, received);
                actualWithdrawn = received;
            }
        } else {
            inputToken.safeTransfer(msg.sender, amount);
            actualWithdrawn = amount;
        }

        emit Withdrawn(msg.sender, actualWithdrawn);
    }

    /**
     * @notice Claims accumulated rewards from the yield source
     * @param sFlaxAmount Amount of sFlax to burn for bonus rewards
     * @dev Rewards are calculated by the yield source and distributed as Flax
     */
    function claimRewards(uint256 sFlaxAmount) external nonReentrant notInEmergencyState notPermanentlyDisabled {
        uint256 flaxValue = IYieldsSource(yieldSource).claimRewards();
        uint256 totalFlax = flaxValue;

        if (sFlaxAmount > 0 && flaxPerSFlax > 0) {
            // Calculate boost using the new boost calculation system
            uint256 boostPercentage = calculateBoostPercentage(sFlaxAmount);
            uint256 boostMultiplier = (10000 + boostPercentage); // 10000 = 100% in basis points
            uint256 boostedFlaxValue = (flaxValue * boostMultiplier) / 10000;
            uint256 additionalFlaxFromBoost = boostedFlaxValue - flaxValue;
            
            // Transfer and burn sFlax tokens
            sFlaxToken.safeTransferFrom(msg.sender, address(this), sFlaxAmount);
            IBurnableERC20(address(sFlaxToken)).burn(sFlaxAmount);
            
            totalFlax = boostedFlaxValue;
            
            emit SFlaxBurned(msg.sender, sFlaxAmount, additionalFlaxFromBoost);
            emit BoostCalculated(msg.sender, sFlaxAmount, boostPercentage, additionalFlaxFromBoost);
        }

        if (totalFlax > 0) {
            flaxToken.safeTransfer(msg.sender, totalFlax);
            emit RewardsClaimed(msg.sender, totalFlax);
        }
    }

    /**
     * @notice Sets the exchange rate for burning sFlax to receive Flax
     * @param _flaxPerSFlax The amount of Flax per sFlax (scaled by 1e18)
     * @dev Only callable by owner
     */
    function setFlaxPerSFlax(uint256 _flaxPerSFlax) external onlyOwner {
        if (_flaxPerSFlax == 0) revert InvalidExchangeRate(_flaxPerSFlax);
        flaxPerSFlax = _flaxPerSFlax;
        emit FlaxPerSFlaxUpdated(_flaxPerSFlax);
    }
    
    /**
     * @notice Calculates boost percentage based on sFlax burn amount
     * @param sFlaxBurnAmount The amount of sFlax to burn for boost
     * @return The boost percentage in basis points (e.g., 500 = 5%)
     * @dev Implements diminishing returns and caps at maxBoostPercentage
     */
    function calculateBoostPercentage(uint256 sFlaxBurnAmount) public view returns (uint256) {
        if (sFlaxBurnAmount == 0) return 0;
        
        // Basic calculation: boostRatePerSFlax * sFlaxBurnAmount (in basis points)
        uint256 baseBoost = (sFlaxBurnAmount * boostRatePerSFlax) / 1e18;
        
        // Apply diminishing returns for large amounts (square root scaling)
        if (baseBoost > 1000) { // Over 10% starts diminishing returns
            // Calculate square root approximation for amounts over 10%
            uint256 excess = baseBoost - 1000;
            uint256 diminishedExcess = _sqrt(excess * 1e18) / 1e9; // Scale down the excess
            baseBoost = 1000 + diminishedExcess;
        }
        
        // Cap at maximum boost percentage
        if (baseBoost > maxBoostPercentage) {
            baseBoost = maxBoostPercentage;
        }
        
        return baseBoost;
    }
    
    /**
     * @notice Calculates optimal sFlax burn amount for a given base reward
     * @param baseRewards The base reward amount in Flax tokens
     * @return The optimal sFlax amount to burn for maximum efficiency
     * @dev Returns amount that gives best reward/cost ratio
     */
    function getOptimalBurnAmount(uint256 baseRewards) public view returns (uint256) {
        if (baseRewards == 0 || flaxPerSFlax == 0) return 0;
        
        // For optimal efficiency, target around 10% boost (1000 basis points)
        // This avoids diminishing returns while providing meaningful boost
        uint256 targetBoostBps = 1000;
        
        // Calculate sFlax needed for target boost
        uint256 targetSFlaxAmount = (targetBoostBps * 1e18) / boostRatePerSFlax;
        
        // Limit to what would give at most 25% of base rewards as boost
        uint256 maxReasonableSFlax = (baseRewards * 25 * 1e18) / (100 * flaxPerSFlax);
        
        // Return the smaller of the two
        return targetSFlaxAmount < maxReasonableSFlax ? targetSFlaxAmount : maxReasonableSFlax;
    }
    
    /**
     * @notice Returns the maximum boost percentage allowed
     * @return The maximum boost percentage in basis points
     */
    function getMaxBoostPercentage() public view returns (uint256) {
        return maxBoostPercentage;
    }
    
    /**
     * @notice Updates boost calculation parameters
     * @param _maxBoostPercentage Maximum boost percentage in basis points
     * @param _boostRatePerSFlax Boost rate per sFlax token in basis points per token
     * @dev Only callable by owner
     */
    function setBoostParameters(uint256 _maxBoostPercentage, uint256 _boostRatePerSFlax) external onlyOwner {
        maxBoostPercentage = _maxBoostPercentage;
        boostRatePerSFlax = _boostRatePerSFlax;
        emit BoostParametersUpdated(_maxBoostPercentage, _boostRatePerSFlax);
    }
    
    /**
     * @notice Sets approved burner status for an address
     * @param burner The address to update
     * @param approved Whether the address should be approved to burn sFlax
     * @dev Only callable by owner
     */
    function setApprovedBurner(address burner, bool approved) external onlyOwner {
        approvedBurners[burner] = approved;
        emit ApprovedBurnerUpdated(burner, approved);
    }
    
    /**
     * @notice Estimates gas cost for boost-related operations
     * @param operation The operation to estimate ("calculateBoost", "claimWithBoost", "withdrawWithBoost")
     * @param sFlaxAmount Amount of sFlax involved in the operation
     * @return Estimated gas cost in wei
     */
    function estimateGasCost(string memory operation, uint256 sFlaxAmount) external view returns (uint256) {
        // Base gas costs for different operations
        if (_compareStrings(operation, "calculateBoost")) {
            return 50000; // Base cost for boost calculation
        } else if (_compareStrings(operation, "claimWithBoost")) {
            return sFlaxAmount > 0 ? 120000 : 80000; // Higher if burning sFlax
        } else if (_compareStrings(operation, "withdrawWithBoost")) {
            return sFlaxAmount > 0 ? 180000 : 140000; // Highest for withdrawal with boost
        } else {
            revert GasEstimationFailed("Unknown operation");
        }
    }

    /**
     * @notice Migrates all funds to a new yield source
     * @param newYieldSource Address of the new yield source contract
     * @dev Claims rewards, withdraws all funds, and redeposits into new source
     * @dev Any losses during migration are absorbed by the surplus
     */
    function migrateYieldSource(address newYieldSource) external onlyOwner nonReentrant notInEmergencyState notPermanentlyDisabled {
        address oldYieldSource = yieldSource;

        // Claim and sell rewards for inputToken
        uint256 inputTokenAmount = IYieldsSource(oldYieldSource).claimAndSellForInputToken();
        if (inputTokenAmount > 0) {
            surplusInputToken += inputTokenAmount;
        }

        // Withdraw all funds
        uint256 amount = totalDeposits;
        if (amount > 0) {
            (uint256 received, ) = IYieldsSource(oldYieldSource).withdraw(amount);
            totalDeposits = 0;
            surplusInputToken += received;
        }

        // Deposit into new yieldSource
        if (surplusInputToken > 0) {
            inputToken.approve(newYieldSource, surplusInputToken);
            uint256 deposited = surplusInputToken;
            IYieldsSource(newYieldSource).deposit(surplusInputToken);
            totalDeposits = deposited;  // Track input token amount, not LP amount
            surplusInputToken = 0;
        }

        yieldSource = newYieldSource;
        emit YieldSourceMigrated(oldYieldSource, newYieldSource);
    }

    /**
     * @notice Checks if withdrawals are currently allowed
     * @return Whether withdrawals are permitted
     * @dev Placeholder for future governance rules (e.g., auctions, crowdfunds)
     */
    function canWithdraw() public view returns (bool) {
        return true; // Placeholder
    }
    
    /**
     * @notice Sets the emergency state of the contract
     * @param state True to enable emergency state, false to disable
     * @dev Emergency state prevents deposits, claims, and migrations
     */
    function setEmergencyState(bool state) external onlyOwner {
        emergencyState = state;
        emit EmergencyStateChanged(state);
    }
    
    /**
     * @notice Emergency function to withdraw ERC20 tokens
     * @param token Address of the token to withdraw
     * @param recipient Address to receive the tokens
     * @dev Only callable by owner for emergency recovery
     */
    function emergencyWithdraw(address token, address recipient) external onlyOwner {
        require(token != address(0), "Invalid token address");
        
        IERC20 tokenContract = IERC20(token);
        uint256 balance = tokenContract.balanceOf(address(this));
        
        if (balance > 0) {
            tokenContract.safeTransfer(recipient, balance);
            emit EmergencyWithdrawal(token, recipient, balance);
        }
    }
    
    /**
     * @notice Emergency function to withdraw ETH
     * @param recipient Address to receive the ETH
     * @dev Only callable by owner for emergency recovery
     */
    function emergencyWithdrawETH(address payable recipient) external onlyOwner {
        uint256 balance = address(this).balance;
        
        if (balance > 0) {
            recipient.transfer(balance);
            emit EmergencyWithdrawal(address(0), recipient, balance);
        }
    }
    
    /**
     * @notice Emergency function to withdraw from yield source and recover tokens
     * @param token Address of the token to withdraw
     * @param recipient Address to receive the tokens
     * @dev Requires emergency state to be active
     * @dev First attempts to withdraw from yield source if withdrawing input token
     */
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
    
    /**
     * @notice Allows the contract to receive ETH
     */
    receive() external payable {}
    
    // Private helper functions
    
    /**
     * @notice Calculates integer square root using Newton's method
     * @param y The number to find the square root of
     * @return z The square root
     */
    function _sqrt(uint256 y) private pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }
    
    /**
     * @notice Compares two strings for equality
     * @param a First string
     * @param b Second string
     * @return Whether the strings are equal
     */
    function _compareStrings(string memory a, string memory b) private pure returns (bool) {
        return keccak256(abi.encodePacked(a)) == keccak256(abi.encodePacked(b));
    }
}