// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@oz_reflax/token/ERC20/IERC20.sol";
import {SafeERC20} from "@oz_reflax/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@oz_reflax/access/Ownable.sol";
import {IPriceTilter} from "../priceTilting/IPriceTilter.sol";
import {IOracle} from "../priceTilting/IOracle.sol";

/**
 * @title AYieldSource
 * @author Justin Goro
 * @notice Abstract base contract for yield sources that convert input tokens to yield-bearing positions
 * @dev Handles deposits, withdrawals, reward claiming, and slippage protection via TWAP oracles
 */
abstract contract AYieldSource is Ownable {
    using SafeERC20 for IERC20;

    /// @notice The input token that gets deposited (e.g., USDC)
    IERC20 public immutable inputToken;
    
    /// @notice The Flax token contract address
    IERC20 public immutable flaxToken;
    
    /// @notice The price tilter contract for Flax/ETH operations
    IPriceTilter public immutable priceTilter;
    
    /// @notice The TWAP oracle contract for price calculations
    IOracle public immutable oracle;
    
    /// @notice Human-readable name of the LP token (e.g., "CRV triusd")
    string public lpTokenName;
    
    /// @notice Array of reward token addresses claimable from the protocol
    address[] public rewardTokens;
    
    /// @notice Mapping of vault addresses allowed to interact with this yield source
    mapping(address => bool) public whitelistedVaults;
    
    /// @notice Total amount of tokens deposited in the yield source
    uint256 public totalDeposited;
    
    /// @notice Minimum acceptable slippage in basis points (e.g., 50 = 0.5%)
    uint256 public minSlippageBps;

    /**
     * @notice Emitted when a vault's whitelist status is updated
     * @param vault Address of the vault
     * @param whitelisted Whether the vault is whitelisted
     */
    event VaultWhitelisted(address indexed vault, bool whitelisted);
    
    /**
     * @notice Emitted when reward tokens are claimed
     * @param token Address of the reward token
     * @param amount Amount of tokens claimed
     */
    event RewardClaimed(address indexed token, uint256 amount);
    
    /**
     * @notice Emitted when reward tokens are sold for ETH
     * @param token Address of the reward token sold
     * @param amount Amount of tokens sold
     * @param ethAmount Amount of ETH received
     */
    event RewardSold(address indexed token, uint256 amount, uint256 ethAmount);
    
    /**
     * @notice Emitted when ETH is converted to Flax value
     * @param ethAmount Amount of ETH being valued
     * @param flaxValue Calculated value in Flax tokens
     */
    event FlaxValueCalculated(uint256 ethAmount, uint256 flaxValue);
    
    /**
     * @notice Emitted when minimum slippage tolerance is updated
     * @param newSlippageBps New slippage tolerance in basis points
     */
    event MinSlippageBpsUpdated(uint256 newSlippageBps);
    
    /**
     * @notice Emitted when LP token name is updated
     * @param newName New name for the LP token
     */
    event LpTokenNameUpdated(string newName);

    /**
     * @notice Restricts function access to whitelisted vaults only
     */
    modifier onlyWhitelistedVault() {
        require(whitelistedVaults[msg.sender], "Not whitelisted vault");
        _;
    }

    /**
     * @notice Initializes the yield source with required contracts and parameters
     * @param _inputToken Address of the input token (e.g., USDC)
     * @param _flaxToken Address of the Flax token
     * @param _priceTilter Address of the price tilter contract
     * @param _oracle Address of the TWAP oracle contract
     * @param _lpTokenName Human-readable name for the LP token
     */
    constructor(
        address _inputToken,
        address _flaxToken,
        address _priceTilter,
        address _oracle,
        string memory _lpTokenName
    ) Ownable(msg.sender) {
        inputToken = IERC20(_inputToken);
        flaxToken = IERC20(_flaxToken);
        priceTilter = IPriceTilter(_priceTilter);
        oracle = IOracle(_oracle);
        lpTokenName = _lpTokenName;
        minSlippageBps = 50; // Default: 0.5%
    }

    /**
     * @notice Updates the whitelist status of a vault
     * @param vault Address of the vault to update
     * @param whitelisted Whether to whitelist or remove from whitelist
     * @dev Only callable by owner
     */
    function whitelistVault(address vault, bool whitelisted) external onlyOwner {
        whitelistedVaults[vault] = whitelisted;
        emit VaultWhitelisted(vault, whitelisted);
    }

    /**
     * @notice Sets the minimum acceptable slippage tolerance
     * @param newSlippageBps New slippage tolerance in basis points (max 10000 = 100%)
     * @dev Only callable by owner
     */
    function setMinSlippageBps(uint256 newSlippageBps) external onlyOwner {
        require(newSlippageBps <= 10000, "Slippage too high"); // Max 100%
        minSlippageBps = newSlippageBps;
        emit MinSlippageBpsUpdated(newSlippageBps);
    }

    /**
     * @notice Updates the LP token name
     * @param newName New name for the LP token
     * @dev Only callable by owner
     */
    function setLpTokenName(string memory newName) external onlyOwner {
        lpTokenName = newName;
        emit LpTokenNameUpdated(newName);
    }

    /**
     * @notice Updates TWAP oracle prices for relevant token pairs
     * @dev Base implementation can be empty; concrete implementations should update specific pairs
     */
    function _updateOracle() internal virtual {
        // Base implementation can be empty or update common pairs if WETH is known/passed.
        // The concrete YieldSource will provide the full implementation.
    }

    /**
     * @notice Deposits input tokens into the yield-generating protocol
     * @param amount Amount of input tokens to deposit
     * @return Amount of yield-bearing tokens received
     * @dev Updates oracle before deposit for accurate pricing
     */
    function deposit(uint256 amount) external virtual onlyWhitelistedVault returns (uint256) {
        _updateOracle();
        inputToken.safeTransferFrom(msg.sender, address(this), amount);
        uint256 received = _depositToProtocol(amount);
        totalDeposited += received;
        return received;
    }

    /**
     * @notice Withdraws tokens from the yield-generating protocol
     * @param amount Amount to withdraw
     * @return inputTokenAmount Amount of input tokens received
     * @return flaxValue Value of rewards in Flax tokens
     * @dev Updates oracle before withdrawal for accurate pricing
     */
    function withdraw(uint256 amount) external virtual onlyWhitelistedVault returns (uint256 inputTokenAmount, uint256 flaxValue) {
        _updateOracle();
        (inputTokenAmount, flaxValue) = _withdrawFromProtocol(amount);
        inputToken.safeTransfer(msg.sender, inputTokenAmount);
        totalDeposited -= amount;
    }

    /**
     * @notice Claims and sells reward tokens for ETH, then calculates Flax value
     * @return flaxValue Total value of claimed rewards in Flax tokens
     * @dev Updates oracle, claims all reward tokens, sells for ETH, and converts to Flax value
     */
    function claimRewards() external virtual onlyWhitelistedVault returns (uint256 flaxValue) {
        _updateOracle();
        uint256 ethAmount;
        for (uint256 i = 0; i < rewardTokens.length; i++) {
            address token = rewardTokens[i];
            uint256 amount = _claimRewardToken(token);
            if (amount > 0) {
                emit RewardClaimed(token, amount);
                ethAmount += _sellRewardToken(token, amount);
                emit RewardSold(token, amount, ethAmount);
            }
        }
        if (ethAmount > 0) {
            flaxValue = _getFlaxValue(ethAmount);
            emit FlaxValueCalculated(ethAmount, flaxValue);
        }
    }

    /**
     * @notice Claims rewards and sells them for input tokens
     * @return inputTokenAmount Amount of input tokens received from selling rewards
     * @dev Used during vault migration to convert rewards to input tokens
     */
    function claimAndSellForInputToken() external virtual onlyWhitelistedVault returns (uint256 inputTokenAmount) {
        uint256 ethAmount;
        for (uint256 i = 0; i < rewardTokens.length; i++) {
            address token = rewardTokens[i];
            uint256 amount = _claimRewardToken(token);
            if (amount > 0) {
                emit RewardClaimed(token, amount);
                ethAmount += _sellRewardToken(token, amount);
                emit RewardSold(token, amount, ethAmount);
            }
        }
        if (ethAmount > 0) {
            inputTokenAmount = _sellEthForInputToken(ethAmount);
        }
    }

    /**
     * @notice Deposits tokens into the underlying yield protocol
     * @param amount Amount of input tokens to deposit
     * @return Amount of yield-bearing tokens received
     * @dev Must be implemented by concrete yield source
     */
    function _depositToProtocol(uint256 amount) internal virtual returns (uint256);
    
    /**
     * @notice Withdraws tokens from the underlying yield protocol
     * @param amount Amount to withdraw
     * @return inputTokenAmount Amount of input tokens received
     * @return flaxValue Value of rewards in Flax tokens
     * @dev Must be implemented by concrete yield source
     */
    function _withdrawFromProtocol(uint256 amount) internal virtual returns (uint256 inputTokenAmount, uint256 flaxValue);
    
    /**
     * @notice Claims a specific reward token from the protocol
     * @param token Address of the reward token to claim
     * @return Amount of reward tokens claimed
     * @dev Must be implemented by concrete yield source
     */
    function _claimRewardToken(address token) internal virtual returns (uint256);
    
    /**
     * @notice Sells reward tokens for ETH
     * @param token Address of the token to sell
     * @param amount Amount of tokens to sell
     * @return ethAmount Amount of ETH received
     * @dev Must be implemented by concrete yield source
     */
    function _sellRewardToken(address token, uint256 amount) internal virtual returns (uint256 ethAmount);
    
    /**
     * @notice Sells ETH for input tokens
     * @param ethAmount Amount of ETH to sell
     * @return inputTokenAmount Amount of input tokens received
     * @dev Must be implemented by concrete yield source
     */
    function _sellEthForInputToken(uint256 ethAmount) internal virtual returns (uint256 inputTokenAmount);
    
    /**
     * @notice Calculates the Flax value of ETH using the price tilter
     * @param ethAmount Amount of ETH to value
     * @return flaxAmount Calculated value in Flax tokens
     * @dev Must be implemented by concrete yield source
     */
    function _getFlaxValue(uint256 ethAmount) internal virtual returns (uint256 flaxAmount);
}