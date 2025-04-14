// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "@oz_reflax/contracts/access/Ownable.sol";
import "@oz_reflax/contracts/token/ERC20/IERC20.sol";
import "../yieldSource/AYieldSource.sol";
import "../priceTilting/IPriceTilter.sol";

contract Vault is Ownable {
    IERC20 public flaxToken;
    IERC20 public sFlaxToken;
    IERC20 public inputToken;
    AYieldSource public yieldSource;
    IPriceTilter public priceTilter;

    uint256 public tiltRatio;
    uint256 public flaxPerSFlax;
    mapping(address => uint256) public originalDeposits;
    uint256 public surplusInputToken;

    event TiltRatioUpdated(uint256 newRatio);
    event FlaxPerSFlaxUpdated(uint256 newRatio);
    event Deposited(address indexed user, uint256 amount);
    event RewardsClaimed(address indexed user, uint256 flaxAmount);
    event Withdrawn(address indexed user, uint256 amount);
    event SFlaxBurned(address indexed user, uint256 sFlaxAmount, uint256 flaxRewarded);
    event SurplusTilted(uint256 inputTokenAmount, uint256 flaxTransferred);
    event YieldSourceMigrated(address newYieldSource);

    constructor(
        IERC20 _flaxToken,
        IERC20 _sFlaxToken,
        IERC20 _inputToken,
        AYieldSource _yieldSource,
        IPriceTilter _priceTilter
    ) Ownable(msg.sender) {
        flaxToken = _flaxToken;
        sFlaxToken = _sFlaxToken;
        inputToken = _inputToken;
        yieldSource = _yieldSource;
        priceTilter = _priceTilter;
        tiltRatio = 5000;
        flaxPerSFlax = 0; // Default to 0, set by owner
    }

    function setTiltRatio(uint256 ratio) external onlyOwner {
        require(ratio <= 10000, "Ratio must be <= 10000 bps");
        tiltRatio = ratio;
        emit TiltRatioUpdated(ratio);
    }

    function setFlaxPerSFlax(uint256 ratio) external onlyOwner {
        flaxPerSFlax = ratio;
        emit FlaxPerSFlaxUpdated(ratio);
    }

    function deposit(uint256 amount) external {
        require(amount > 0, "Amount must be > 0");
        inputToken.transferFrom(msg.sender, address(this), amount);
        inputToken.approve(address(yieldSource), amount);
        yieldSource.deposit(amount);
        originalDeposits[msg.sender] += amount;
        emit Deposited(msg.sender, amount);
    }

    function claimRewards(uint256 sFlaxAmount) external {
        uint256 flaxValue = yieldSource.claimRewards();
        uint256 totalFlax = flaxValue;

        if (sFlaxAmount > 0 && flaxPerSFlax > 0) {
            uint256 flaxBoost = (sFlaxAmount * flaxPerSFlax) / 1e18;
            sFlaxToken.transferFrom(msg.sender, address(this), sFlaxAmount);
            // Assume sFlax has a burn function; adjust if needed
            (bool success,) = address(sFlaxToken).call(
                abi.encodeWithSignature("burn(uint256)", sFlaxAmount)
            );
            require(success, "sFlax burn failed");
            totalFlax += flaxBoost;
            emit SFlaxBurned(msg.sender, sFlaxAmount, flaxBoost);
        }

        if (totalFlax > 0) {
            flaxToken.transfer(msg.sender, totalFlax);
            emit RewardsClaimed(msg.sender, totalFlax);
        }
    }

    function withdraw(uint256 amount, bool protectLoss, uint256 sFlaxAmount) external {
        require(canWithdraw(), "Withdrawal not allowed");
        require(originalDeposits[msg.sender] >= amount, "Insufficient deposit");

        uint256 balanceBefore = inputToken.balanceOf(address(this));
        (uint256 received, uint256 flaxValue) = yieldSource.withdraw(amount);
        uint256 balanceAfter = inputToken.balanceOf(address(this));
        require(balanceAfter >= balanceBefore + received, "Balance mismatch");

        uint256 totalFlax = flaxValue;

        if (sFlaxAmount > 0 && flaxPerSFlax > 0) {
            uint256 flaxBoost = (sFlaxAmount * flaxPerSFlax) / 1e18;
            sFlaxToken.transferFrom(msg.sender, address(this), sFlaxAmount);
            // Assume sFlax has a burn function; adjust if needed
            (bool success,) = address(sFlaxToken).call(
                abi.encodeWithSignature("burn(uint256)", sFlaxAmount)
            );
            require(success, "sFlax burn failed");
            totalFlax += flaxBoost;
            emit SFlaxBurned(msg.sender, sFlaxAmount, flaxBoost);
        }

        if (totalFlax > 0) {
            flaxToken.transfer(msg.sender, totalFlax);
            emit RewardsClaimed(msg.sender, totalFlax);
        }

        originalDeposits[msg.sender] -= amount;

        if (received > amount) {
            surplusInputToken += received - amount;
            inputToken.transfer(msg.sender, amount);
        } else if (received < amount) {
            uint256 shortfall = amount - received;
            if (surplusInputToken >= shortfall) {
                surplusInputToken -= shortfall;
                inputToken.transfer(msg.sender, amount);
            } else if (protectLoss) {
                revert("Shortfall exceeds surplus");
            } else {
                inputToken.transfer(msg.sender, received);
            }
        } else {
            inputToken.transfer(msg.sender, amount);
        }

        emit Withdrawn(msg.sender, amount);
    }

    function canWithdraw() public view virtual returns (bool) {
        return true;
    }

    function tiltSurplus() external onlyOwner {
        uint256 inputTokenAmount = surplusInputToken / 2;
        require(inputTokenAmount > 0, "No surplus to tilt");

        uint256 flaxToTransfer = (inputTokenAmount * tiltRatio) / 10000;
        flaxToken.transfer(address(this), flaxToTransfer);
        surplusInputToken -= inputTokenAmount;

        priceTilter.tiltPrice(address(inputToken), inputTokenAmount);

        emit SurplusTilted(inputTokenAmount, flaxToTransfer);
    }

    function migrateYieldSource(address newYieldSource) external onlyOwner {
        yieldSource = AYieldSource(newYieldSource);
        emit YieldSourceMigrated(newYieldSource);
    }
}