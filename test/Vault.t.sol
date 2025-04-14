// SPDX-License-License-Identifier: MIT
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
    event RewardsClaimed(address indexed user, uint256 flaxAmount);
    event SFlaxBurned(address indexed user, uint256 sFlaxAmount, uint256 flaxRewarded);

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

        // Setup for claimRewards
        sFlaxToken.mint(user, 1000 * 1e18);
        vm.prank(user);
        sFlaxToken.approve(address(vault), type(uint256).max);
        flaxToken.mint(address(vault), 1000 * 1e18); // Pre-fund vault
        vm.prank(address(vault.owner()));
        vault.setFlaxPerSFlax(1e17); // 0.1 Flax per sFlax
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

    function testClaimRewards() public {
        vm.startPrank(user);

        // Case 1: Positive sFlaxAmount
        uint256 sFlaxAmount = 100 * 1e18;
        uint256 flaxValue = 50 * 1e18;
        yieldSource.setFlaxValue(flaxValue);
        uint256 expectedFlaxBoost = (sFlaxAmount * vault.flaxPerSFlax()) / 1e18; // 100 * 0.1 = 10 * 1e18
        uint256 expectedTotalFlax = flaxValue + expectedFlaxBoost;

        vm.expectEmit(true, false, false, true);
        emit SFlaxBurned(user, sFlaxAmount, expectedFlaxBoost);
        vm.expectEmit(true, false, false, true);
        emit RewardsClaimed(user, expectedTotalFlax);

        vault.claimRewards(sFlaxAmount);

        assertEq(sFlaxToken.balanceOf(user), 900 * 1e18, "sFlax balance incorrect");
        assertEq(flaxToken.balanceOf(user), expectedTotalFlax, "User flax balance incorrect");
        assertEq(flaxToken.balanceOf(address(vault)), 1000 * 1e18 - expectedTotalFlax, "Vault flax balance incorrect");

        // Case 2: Zero sFlaxAmount
        sFlaxAmount = 0;
        flaxValue = 20 * 1e18;
        yieldSource.setFlaxValue(flaxValue);
        expectedTotalFlax = flaxValue;

        vm.expectEmit(true, false, false, true);
        emit RewardsClaimed(user, expectedTotalFlax);

        vault.claimRewards(sFlaxAmount);

        assertEq(sFlaxToken.balanceOf(user), 900 * 1e18, "sFlax balance unchanged");
        assertEq(flaxToken.balanceOf(user), 80 * 1e18, "User flax balance incorrect after zero");
        assertEq(flaxToken.balanceOf(address(vault)), 920 * 1e18, "Vault flax balance incorrect after zero");

        vm.stopPrank();
    }
}