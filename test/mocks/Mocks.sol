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
}

contract MockYieldSource {
    uint256 public totalDeposited;

    function deposit(uint256 amount) external returns (uint256) {
        totalDeposited += amount;
        return amount;
    }

    function claimRewards() external returns (uint256) {
        return 0;
    }

    function withdraw(uint256 amount) external returns (uint256 inputTokenAmount, uint256 flaxValue) {
        return (amount, 0);
    }
}