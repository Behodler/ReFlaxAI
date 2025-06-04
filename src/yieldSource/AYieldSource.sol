// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@oz_reflax/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@oz_reflax/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@oz_reflax/contracts/access/Ownable.sol";
import {IPriceTilter} from "../priceTilting/IPriceTilter.sol";
import {IOracle} from "../priceTilting/IOracle.sol";

abstract contract AYieldSource is Ownable {
    using SafeERC20 for IERC20;

    IERC20 public immutable inputToken;
    IERC20 public immutable flaxToken;
    IPriceTilter public immutable priceTilter;
    IOracle public immutable oracle;
    string public lpTokenName; // e.g., "CRV triusd"
    address[] public rewardTokens;
    mapping(address => bool) public whitelistedVaults;
    uint256 public totalDeposited;
    uint256 public minSlippageBps; // e.g., 50 bps = 0.5%

    event VaultWhitelisted(address indexed vault, bool whitelisted);
    event RewardClaimed(address indexed token, uint256 amount);
    event RewardSold(address indexed token, uint256 amount, uint256 ethAmount);
    event FlaxValueCalculated(uint256 ethAmount, uint256 flaxValue);
    event MinSlippageBpsUpdated(uint256 newSlippageBps);
    event LpTokenNameUpdated(string newName);

    modifier onlyWhitelistedVault() {
        require(whitelistedVaults[msg.sender], "Not whitelisted vault");
        _;
    }

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

    function whitelistVault(address vault, bool whitelisted) external onlyOwner {
        whitelistedVaults[vault] = whitelisted;
        emit VaultWhitelisted(vault, whitelisted);
    }

    function setMinSlippageBps(uint256 newSlippageBps) external onlyOwner {
        require(newSlippageBps <= 10000, "Slippage too high"); // Max 100%
        minSlippageBps = newSlippageBps;
        emit MinSlippageBpsUpdated(newSlippageBps);
    }

    function setLpTokenName(string memory newName) external onlyOwner {
        lpTokenName = newName;
        emit LpTokenNameUpdated(newName);
    }

    function _updateOracle() internal virtual {
        // Base implementation can be empty or update common pairs if WETH is known/passed.
        // The concrete YieldSource will provide the full implementation.
    }

    function deposit(uint256 amount) external virtual onlyWhitelistedVault returns (uint256) {
        _updateOracle();
        inputToken.safeTransferFrom(msg.sender, address(this), amount);
        uint256 received = _depositToProtocol(amount);
        totalDeposited += received;
        return received;
    }

    function withdraw(uint256 amount) external virtual onlyWhitelistedVault returns (uint256 inputTokenAmount, uint256 flaxValue) {
        _updateOracle();
        (inputTokenAmount, flaxValue) = _withdrawFromProtocol(amount);
        inputToken.safeTransfer(msg.sender, inputTokenAmount);
        totalDeposited -= amount;
    }

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

    function _depositToProtocol(uint256 amount) internal virtual returns (uint256);
    function _withdrawFromProtocol(uint256 amount) internal virtual returns (uint256 inputTokenAmount, uint256 flaxValue);
    function _claimRewardToken(address token) internal virtual returns (uint256);
    function _sellRewardToken(address token, uint256 amount) internal virtual returns (uint256 ethAmount);
    function _sellEthForInputToken(uint256 ethAmount) internal virtual returns (uint256 inputTokenAmount);
    function _getFlaxValue(uint256 ethAmount) internal virtual returns (uint256 flaxAmount);
}