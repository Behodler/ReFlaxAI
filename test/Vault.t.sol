// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {Vault} from "../src/vault/Vault.sol";
import {MockERC20, MockYieldSource} from "./mocks/Mocks.sol";
import {IERC20} from "@oz_reflax/contracts/token/ERC20/IERC20.sol";
import {IPriceTilter} from "../src/priceTilting/IPriceTilter.sol";

contract VaultTest is Test {
    Vault vault;
    MockERC20 inputToken;
    MockERC20 flaxToken;
    MockERC20 sFlaxToken;
    MockYieldSource yieldSource;
    address priceTilter;
    address user;

    event Deposited(address indexed user, uint256 amount);

    function setUp() public {
        user = address(0x1234);
        inputToken = new MockERC20();
        flaxToken = new MockERC20();
        sFlaxToken = new MockERC20();
        yieldSource = new MockYieldSource();
        priceTilter = address(0x5678);

        vault = new Vault(
            address(flaxToken),
            address(sFlaxToken),
            address(inputToken),
            address(yieldSource),
            priceTilter
        );

        inputToken.mint(user, 1000 * 1e18);
        vm.prank(user);
        inputToken.approve(address(vault), type(uint256).max);
    }

    function testDeposit() public {
        uint256 depositAmount = 100 * 1e18;

        vm.startPrank(user);

        vm.expectEmit(true, false, false, true);
        emit Deposited(user, depositAmount);

        vault.deposit(depositAmount);

        assertEq(inputToken.balanceOf(user), 900 * 1e18, "User balance incorrect");
        assertEq(inputToken.balanceOf(address(vault)), depositAmount, "Vault balance incorrect");
        assertEq(yieldSource.totalDeposited(), depositAmount, "YieldSource deposit incorrect");
        assertEq(vault.originalDeposits(user), depositAmount, "originalDeposits incorrect");

        vm.stopPrank();
    }
}