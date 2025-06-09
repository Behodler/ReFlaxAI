// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@oz_reflax/token/ERC20/IERC20.sol";
import {ArbitrumConstants} from "./ArbitrumConstants.sol";

/**
 * @title IntegrationTest
 * @notice Base contract for integration tests that fork Arbitrum mainnet
 */
abstract contract IntegrationTest is Test {
    // Common tokens
    IERC20 public usdc;
    IERC20 public usdt;
    IERC20 public crv;
    IERC20 public cvx;
    IERC20 public weth;
    IERC20 public usde;
    IERC20 public usdx;
    
    function setUp() public virtual {
        // Fork will be created by forge command line with -f flag
        // This ensures we're using the latest block
        
        // Initialize token interfaces
        usdc = IERC20(ArbitrumConstants.USDC);
        usdt = IERC20(ArbitrumConstants.USDT);
        crv = IERC20(ArbitrumConstants.CRV);
        cvx = IERC20(ArbitrumConstants.CVX);
        weth = IERC20(ArbitrumConstants.WETH);
        usde = IERC20(ArbitrumConstants.USDe);
        usdx = IERC20(ArbitrumConstants.USDx);
        
        // Label addresses for better trace output
        vm.label(ArbitrumConstants.USDC, "USDC");
        vm.label(ArbitrumConstants.USDT, "USDT");
        vm.label(ArbitrumConstants.CRV, "CRV");
        vm.label(ArbitrumConstants.CVX, "CVX");
        vm.label(ArbitrumConstants.WETH, "WETH");
        vm.label(ArbitrumConstants.USDe, "USDe");
        vm.label(ArbitrumConstants.USDx, "USDx");
        vm.label(ArbitrumConstants.CONVEX_BOOSTER, "ConvexBooster");
        vm.label(ArbitrumConstants.USDC_USDe_CRV_POOL, "USDC/USDe_Pool");
        vm.label(ArbitrumConstants.USDe_USDx_CRV_POOL, "USDe/USDx_Pool");
        vm.label(ArbitrumConstants.UNISWAP_V3_ROUTER, "UniswapV3Router");
        vm.label(ArbitrumConstants.UNISWAP_V2_ROUTER, "UniswapV2Router");
    }
    
    /**
     * @notice Helper to deal tokens from whales
     * @param token The token to transfer
     * @param whale The whale address to transfer from
     * @param recipient The recipient of the tokens
     * @param amount The amount to transfer
     */
    function dealTokens(address token, address whale, address recipient, uint256 amount) internal {
        uint256 whaleBalance = IERC20(token).balanceOf(whale);
        require(whaleBalance >= amount, "Whale has insufficient balance");
        
        vm.startPrank(whale);
        IERC20(token).transfer(recipient, amount);
        vm.stopPrank();
    }
    
    /**
     * @notice Helper to deal USDC
     * @param recipient The recipient of the USDC
     * @param amount The amount of USDC to deal (with 6 decimals)
     */
    function dealUSDC(address recipient, uint256 amount) internal {
        dealTokens(ArbitrumConstants.USDC, ArbitrumConstants.USDC_WHALE, recipient, amount);
    }
    
    /**
     * @notice Helper to deal USDe
     * @param recipient The recipient of the USDe
     * @param amount The amount of USDe to deal (with 18 decimals)
     */
    function dealUSDe(address recipient, uint256 amount) internal {
        dealTokens(ArbitrumConstants.USDe, ArbitrumConstants.USDe_WHALE, recipient, amount);
    }
    
    /**
     * @notice Helper to deal ETH
     * @param recipient The recipient of the ETH
     * @param amount The amount of ETH to deal
     */
    function dealETH(address recipient, uint256 amount) internal {
        vm.deal(recipient, amount);
    }
    
    /**
     * @notice Helper to advance time
     * @param seconds_ The number of seconds to advance
     */
    function advanceTime(uint256 seconds_) internal {
        vm.warp(block.timestamp + seconds_);
        // Arbitrum has ~0.25 second block times, but we'll use 1 second for simplicity
        vm.roll(block.number + seconds_);
    }
    
    /**
     * @notice Helper to take a snapshot and return snapshot ID
     * @return snapshotId The ID of the snapshot
     */
    function takeSnapshot() internal returns (uint256) {
        return vm.snapshot();
    }
    
    /**
     * @notice Helper to revert to a snapshot
     * @param snapshotId The ID of the snapshot to revert to
     */
    function revertToSnapshot(uint256 snapshotId) internal {
        vm.revertTo(snapshotId);
    }
    
    /**
     * @notice Helper to wrap ETH into WETH
     * @param amount The amount of ETH to wrap
     */
    function wrapETH(uint256 amount) internal {
        (bool success,) = ArbitrumConstants.WETH.call{value: amount}("");
        require(success, "WETH deposit failed");
    }
    
    /**
     * @notice Helper to get current block timestamp
     * @return The current block timestamp
     */
    function currentTimestamp() internal view returns (uint256) {
        return block.timestamp;
    }
}