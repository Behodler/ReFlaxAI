// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@oz_reflax/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@oz_reflax/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@oz_reflax/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@oz_reflax/contracts/utils/ReentrancyGuard.sol";
import {IPriceTilter} from "../priceTilting/IPriceTilter.sol";

interface IYieldsSource {
    function deposit(uint256 amount) external returns (uint256);
    function withdraw(uint256 amount) external returns (uint256 inputTokenAmount, uint256 flaxValue);
    function claimRewards() external returns (uint256);
    function claimAndSellForInputToken() external returns (uint256 inputTokenAmount);
}

contract Vault is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public immutable inputToken;
    IERC20 public immutable flaxToken;
    IERC20 public immutable sFlaxToken;
    address public yieldSource;
    address public immutable priceTilter;
    uint256 public flaxPerSFlax;
    uint256 public totalDeposits;
    uint256 public surplusInputToken;
    mapping(address => uint256) public originalDeposits;

    event Deposited(address indexed user, uint256 amount);
    event RewardsClaimed(address indexed user, uint256 flaxAmount);
    event SFlaxBurned(address indexed user, uint256 sFlaxAmount, uint256 flaxRewarded);
    event Withdrawn(address indexed user, uint256 amount);
    event FlaxPerSFlaxUpdated(uint256 newRatio);
    event YieldSourceMigrated(address indexed oldYieldSource, address indexed newYieldSource);

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
    }

    function deposit(uint256 amount) external nonReentrant {
        inputToken.safeTransferFrom(msg.sender, address(this), amount);
        inputToken.approve(yieldSource, amount);
        uint256 received = IYieldsSource(yieldSource).deposit(amount);
        originalDeposits[msg.sender] += amount;
        totalDeposits += amount;
        emit Deposited(msg.sender, amount);
    }

    function withdraw(uint256 amount, bool protectLoss, uint256 sFlaxAmount) external nonReentrant {
        require(canWithdraw(), "Withdrawal not allowed");
        require(originalDeposits[msg.sender] >= amount, "Insufficient deposit");

        uint256 balanceBefore = inputToken.balanceOf(address(this));
        (uint256 received, uint256 flaxValue) = IYieldsSource(yieldSource).withdraw(amount);
        uint256 balanceAfter = inputToken.balanceOf(address(this));
        require(balanceAfter >= balanceBefore + received, "Balance mismatch");

        uint256 totalFlax = flaxValue;

        if (sFlaxAmount > 0 && flaxPerSFlax > 0) {
            uint256 flaxBoost = (sFlaxAmount * flaxPerSFlax) / 1e18;
            sFlaxToken.safeTransferFrom(msg.sender, address(this), sFlaxAmount);
            (bool success,) = address(sFlaxToken).call(abi.encodeWithSignature("burn(uint256)", sFlaxAmount));
            require(success, "sFlax burn failed");
            totalFlax += flaxBoost;
            emit SFlaxBurned(msg.sender, sFlaxAmount, flaxBoost);
        }

        if (totalFlax > 0) {
            flaxToken.safeTransfer(msg.sender, totalFlax);
            emit RewardsClaimed(msg.sender, totalFlax);
        }

        originalDeposits[msg.sender] -= amount;
        totalDeposits -= amount;

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
                emit Withdrawn(msg.sender, received);
                return;
            }
        } else {
            inputToken.safeTransfer(msg.sender, amount);
        }

        emit Withdrawn(msg.sender, amount);
    }

    function claimRewards(uint256 sFlaxAmount) external nonReentrant {
        uint256 flaxValue = IYieldsSource(yieldSource).claimRewards();
        uint256 totalFlax = flaxValue;

        if (sFlaxAmount > 0 && flaxPerSFlax > 0) {
            uint256 flaxBoost = (sFlaxAmount * flaxPerSFlax) / 1e18;
            sFlaxToken.safeTransferFrom(msg.sender, address(this), sFlaxAmount);
            (bool success,) = address(sFlaxToken).call(abi.encodeWithSignature("burn(uint256)", sFlaxAmount));
            require(success, "sFlax burn failed");
            totalFlax += flaxBoost;
            emit SFlaxBurned(msg.sender, sFlaxAmount, flaxBoost);
        }

        if (totalFlax > 0) {
            flaxToken.safeTransfer(msg.sender, totalFlax);
            emit RewardsClaimed(msg.sender, totalFlax);
        }
    }

    function setFlaxPerSFlax(uint256 _flaxPerSFlax) external onlyOwner {
        flaxPerSFlax = _flaxPerSFlax;
        emit FlaxPerSFlaxUpdated(_flaxPerSFlax);
    }

    function migrateYieldSource(address newYieldSource) external onlyOwner nonReentrant {
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
            uint256 received = IYieldsSource(newYieldSource).deposit(surplusInputToken);
            totalDeposits = received;
            surplusInputToken = 0;
        }

        yieldSource = newYieldSource;
        emit YieldSourceMigrated(oldYieldSource, newYieldSource);
    }

    function canWithdraw() public view returns (bool) {
        return true; // Placeholder
    }
}