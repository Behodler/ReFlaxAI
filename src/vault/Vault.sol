// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@oz_reflax/token/ERC20/IERC20.sol";
import {SafeERC20} from "@oz_reflax/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@oz_reflax/access/Ownable.sol";
import {ReentrancyGuard} from "@oz_reflax/utils/ReentrancyGuard.sol";
import {IPriceTilter} from "../priceTilting/IPriceTilter.sol";

interface IYieldsSource {
    function deposit(uint256 amount) external returns (uint256);
    function withdraw(uint256 amount) external returns (uint256 inputTokenAmount, uint256 flaxValue);
    function claimRewards() external returns (uint256);
    function claimAndSellForInputToken() external returns (uint256 inputTokenAmount);
}

interface IBurnableERC20 is IERC20 {
    function burn(uint256 amount) external;
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
    bool public emergencyState;

    event Deposited(address indexed user, uint256 amount);
    event RewardsClaimed(address indexed user, uint256 flaxAmount);
    event SFlaxBurned(address indexed user, uint256 sFlaxAmount, uint256 flaxRewarded);
    event Withdrawn(address indexed user, uint256 amount);
    event FlaxPerSFlaxUpdated(uint256 newRatio);
    event YieldSourceMigrated(address indexed oldYieldSource, address indexed newYieldSource);
    event EmergencyStateChanged(bool state);
    event EmergencyWithdrawal(address indexed token, address indexed recipient, uint256 amount);

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
    }

    modifier notInEmergencyState() {
        require(!emergencyState, "Contract is in emergency state");
        _;
    }

    function deposit(uint256 amount) external nonReentrant notInEmergencyState {
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
            IBurnableERC20(address(sFlaxToken)).burn(sFlaxAmount);
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

    function claimRewards(uint256 sFlaxAmount) external nonReentrant notInEmergencyState {
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

    function setFlaxPerSFlax(uint256 _flaxPerSFlax) external onlyOwner {
        flaxPerSFlax = _flaxPerSFlax;
        emit FlaxPerSFlaxUpdated(_flaxPerSFlax);
    }

    function migrateYieldSource(address newYieldSource) external onlyOwner nonReentrant notInEmergencyState {
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
    
    function setEmergencyState(bool state) external onlyOwner {
        emergencyState = state;
        emit EmergencyStateChanged(state);
    }
    
    function emergencyWithdraw(address token, address recipient) external onlyOwner {
        require(token != address(0), "Invalid token address");
        
        IERC20 tokenContract = IERC20(token);
        uint256 balance = tokenContract.balanceOf(address(this));
        
        if (balance > 0) {
            tokenContract.safeTransfer(recipient, balance);
            emit EmergencyWithdrawal(token, recipient, balance);
        }
    }
    
    function emergencyWithdrawETH(address payable recipient) external onlyOwner {
        uint256 balance = address(this).balance;
        
        if (balance > 0) {
            recipient.transfer(balance);
            emit EmergencyWithdrawal(address(0), recipient, balance);
        }
    }
    
    function emergencyWithdrawFromYieldSource(address token, address recipient) external onlyOwner {
        require(emergencyState, "Not in emergency state");
        
        // First withdraw all funds from yield source if it's the input token
        if (token == address(inputToken) && totalDeposits > 0) {
            (uint256 received, ) = IYieldsSource(yieldSource).withdraw(totalDeposits);
            totalDeposits = 0;
            surplusInputToken += received;
        }
        
        // Now withdraw the token from this contract
        IERC20 tokenContract = IERC20(token);
        uint256 balance = tokenContract.balanceOf(address(this));
        
        if (balance > 0) {
            tokenContract.safeTransfer(recipient, balance);
            emit EmergencyWithdrawal(token, recipient, balance);
        }
    }
    
    receive() external payable {}
}