// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract MockERC20 {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function transfer(address to, uint256 amount) external returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
    }

    // For sFlax burning
    function burn(uint256 amount) external {
        balanceOf[msg.sender] -= amount;
    }
}

contract MockYieldSource {
    uint256 public totalDeposited;
    uint256 public flaxValueToReturn;
    uint256 public inputTokenToReturn;
    MockERC20 public inputToken; // Added to enable transfer

    constructor(address _inputToken) {
        inputToken = MockERC20(_inputToken);
    }

    function setReturnValues(uint256 _inputTokenAmount, uint256 _flaxValue) external {
        inputTokenToReturn = _inputTokenAmount;
        flaxValueToReturn = _flaxValue;
    }

    function deposit(uint256 amount) external returns (uint256) {
        totalDeposited += amount;
        return amount;
    }

    function claimRewards() external returns (uint256) {
        return flaxValueToReturn;
    }

    function withdraw(uint256 amount) external returns (uint256 inputTokenAmount, uint256 flaxValue) {
        inputToken.transfer(msg.sender, inputTokenToReturn); // Transfer inputToken
        return (inputTokenToReturn, flaxValueToReturn);
    }
}

contract MockPriceTilter {
    function tiltPrice(address token, uint256 amount) external {}
    function flaxToken() external view returns (address) { return address(0); }
    function getPrice(address tokenA, address tokenB) external returns (uint256) { return 0; }
    function addLiquidity(address tokenA, address tokenB, uint256 amountA, uint256 amountB) external {}
}