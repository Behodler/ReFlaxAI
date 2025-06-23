// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

// lib/oz_reflax/token/ERC20/IERC20.sol

// OpenZeppelin Contracts (last updated v5.1.0) (token/ERC20/IERC20.sol)

/**
 * @dev Interface of the ERC-20 standard as defined in the ERC.
 */
interface IERC20 {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Returns the value of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the value of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves a `value` amount of tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 value) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets a `value` amount of tokens as the allowance of `spender` over the
     * caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 value) external returns (bool);

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to` using the
     * allowance mechanism. `value` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

// src/priceTilting/IPriceTilter.sol

/**
 * @title IPriceTilter
 * @author Justin Goro
 * @notice Interface for price tilter contracts that manage Flax pricing
 * @dev Implements price tilting by adding liquidity with reduced Flax amounts
 */
interface IPriceTilter {
    /**
     * @notice Tilts the price of a token by adding liquidity
     * @param token Address of the token (typically Flax)
     * @param amount Amount of ETH or tokens to use for liquidity
     * @dev Adds less of the specified token than its TWAP value to increase its price
     */
    function tiltPrice(address token, uint256 amount) external;
    
    /**
     * @notice Returns the Flax token address
     * @return Address of the Flax token
     */
    function flaxToken() external view returns (address);
    
    /**
     * @notice Returns the Uniswap factory address
     * @return Address of the Uniswap factory
     */
    function factory() external view returns (address);
    
    /**
     * @notice Gets the current price between two tokens
     * @param tokenA First token in the pair
     * @param tokenB Second token in the pair
     * @return Price of tokenA in terms of tokenB
     * @dev May update oracle before returning price
     */
    function getPrice(address tokenA, address tokenB) external returns (uint256);
    
    /**
     * @notice Adds liquidity to a token pair
     * @param tokenA First token in the pair
     * @param tokenB Second token in the pair
     * @param amountA Amount of tokenA to add
     * @param amountB Amount of tokenB to add
     * @dev Used for general liquidity provision without price tilting
     */
    function addLiquidity(address tokenA, address tokenB, uint256 amountA, uint256 amountB) external;
}

// lib/oz_reflax/access/Ownable.sol

// OpenZeppelin Contracts (last updated v5.0.0) (access/Ownable.sol)

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * The initial owner is set to the address provided by the deployer. This can
 * later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable {
    address private _owner;

    /**
     * @dev The caller account is not authorized to perform an operation.
     */
    error OwnableUnauthorizedAccount(address account);

    /**
     * @dev The owner is not a valid owner account. (eg. `address(0)`)
     */
    error OwnableInvalidOwner(address owner);

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the address provided by the deployer as the initial owner.
     */
    constructor(address initialOwner) {
        if (initialOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(initialOwner);
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        if (owner() != msg.sender) {
            revert OwnableUnauthorizedAccount(msg.sender);
        }
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby disabling any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        if (newOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

// lib/oz_reflax/utils/ReentrancyGuard.sol

// OpenZeppelin Contracts (last updated v5.1.0) (utils/ReentrancyGuard.sol)

/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 *
 * TIP: If EIP-1153 (transient storage) is available on the chain you're deploying at,
 * consider using {ReentrancyGuardTransient} instead.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 */
abstract contract ReentrancyGuard {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;

    uint256 private _status;

    /**
     * @dev Unauthorized reentrant call.
     */
    error ReentrancyGuardReentrantCall();

    constructor() {
        _status = NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and making it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    function _nonReentrantBefore() private {
        // On the first call to nonReentrant, _status will be NOT_ENTERED
        if (_status == ENTERED) {
            revert ReentrancyGuardReentrantCall();
        }

        // Any calls to nonReentrant after this point will fail
        _status = ENTERED;
    }

    function _nonReentrantAfter() private {
        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = NOT_ENTERED;
    }

    /**
     * @dev Returns true if the reentrancy guard is currently set to "entered", which indicates there is a
     * `nonReentrant` function in the call stack.
     */
    function _reentrancyGuardEntered() internal view returns (bool) {
        return _status == ENTERED;
    }
}

// lib/oz_reflax/token/ERC20/utils/SafeERC20.sol

// OpenZeppelin Contracts (last updated v5.2.0) (token/ERC20/utils/SafeERC20.sol)

/**
 * @title SafeERC20
 * @dev Wrappers around ERC-20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for IERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20 {
    /**
     * @dev An operation with an ERC-20 token failed.
     */
    error SafeERC20FailedOperation(address token);

    /**
     * @dev Transfer `value` amount of `token` from the calling contract to `to`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     */
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeCall(token.transfer, (to, value)));
    }

    /**
     * @dev Transfer `value` amount of `token` from `from` to `to`, spending the approval given by `from` to the
     * calling contract. If `token` returns no value, non-reverting calls are assumed to be successful.
     */
    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeCall(token.transferFrom, (from, to, value)));
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     *
     * This is a variant of {_callOptionalReturnBool} that reverts if call fails to meet the requirements.
     */
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        uint256 returnSize;
        uint256 returnValue;
        assembly ("memory-safe") {
            let success := call(gas(), token, 0, add(data, 0x20), mload(data), 0, 0x20)
            // bubble errors
            if iszero(success) {
                let ptr := mload(0x40)
                returndatacopy(ptr, 0, returndatasize())
                revert(ptr, returndatasize())
            }
            returnSize := returndatasize()
            returnValue := mload(0)
        }

        if (returnSize == 0 ? address(token).code.length == 0 : returnValue != 1) {
            revert SafeERC20FailedOperation(address(token));
        }
    }
}

// src/vault/Vault.sol

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
}

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
            /// AssignmentMutation(`amount` |==> `0`) of: `actualWithdrawn = amount;`
            actualWithdrawn = 0;
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
    }

    /**
     * @notice Sets the exchange rate for burning sFlax to receive Flax
     * @param _flaxPerSFlax The amount of Flax per sFlax (scaled by 1e18)
     * @dev Only callable by owner
     */
    function setFlaxPerSFlax(uint256 _flaxPerSFlax) external onlyOwner {
        flaxPerSFlax = _flaxPerSFlax;
        emit FlaxPerSFlaxUpdated(_flaxPerSFlax);
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
}

