// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IntegrationTest} from "../base/IntegrationTest.sol";
import {ArbitrumConstants} from "../base/ArbitrumConstants.sol";
import {console} from "forge-std/console.sol";

/**
 * @title PoolInterfaceCheckIntegrationTest
 * @notice Test to check the actual interface of the USDC/USDe Curve pool
 */
contract PoolInterfaceCheckIntegrationTest is IntegrationTest {
    
    function setUp() public override {
        super.setUp();
    }
    
    /**
     * @notice Test different calc_token_amount signatures to find the correct one
     */
    function testCalcTokenAmountInterface() public {
        address pool = ArbitrumConstants.USDC_USDe_CRV_POOL;
        
        // Try 2-token interface
        console.log("Testing 2-token calc_token_amount interface...");
        try this.tryCalcTokenAmount2(pool) {
            console.log("SUCCESS: 2-token interface works!");
        } catch Error(string memory reason) {
            console.log("FAILED: 2-token interface failed:", reason);
        } catch (bytes memory) {
            console.log("FAILED: 2-token interface reverted with low-level error");
        }
        
        // Try 4-token interface
        console.log("\nTesting 4-token calc_token_amount interface...");
        try this.tryCalcTokenAmount4(pool) {
            console.log("SUCCESS: 4-token interface works!");
        } catch Error(string memory reason) {
            console.log("FAILED: 4-token interface failed:", reason);
        } catch (bytes memory) {
            console.log("FAILED: 4-token interface reverted with low-level error");
        }
        
        // Try dynamic array interface (newer pools)
        console.log("\nTesting dynamic array calc_token_amount interface...");
        try this.tryCalcTokenAmountDynamic(pool) {
            console.log("SUCCESS: Dynamic array interface works!");
        } catch Error(string memory reason) {
            console.log("FAILED: Dynamic array interface failed:", reason);
        } catch (bytes memory) {
            console.log("FAILED: Dynamic array interface reverted with low-level error");
        }
        
        // Try to check if it has calc_withdraw_one_coin
        console.log("\nTesting calc_withdraw_one_coin interface...");
        try this.tryCalcWithdrawOneCoin(pool) {
            console.log("SUCCESS: calc_withdraw_one_coin exists!");
        } catch Error(string memory reason) {
            console.log("FAILED: calc_withdraw_one_coin failed:", reason);
        } catch (bytes memory) {
            console.log("FAILED: calc_withdraw_one_coin reverted with low-level error");
        }
        
        // Try to check N_COINS
        console.log("\nTesting N_COINS getter...");
        try this.tryGetNCoins(pool) returns (uint256 nCoins) {
            console.log("SUCCESS: N_COINS =", nCoins);
        } catch Error(string memory reason) {
            console.log("FAILED: N_COINS failed:", reason);
        } catch (bytes memory) {
            console.log("FAILED: N_COINS reverted with low-level error");
        }
    }
    
    // External functions to be called via try/catch
    
    function tryCalcTokenAmount2(address pool) external view returns (uint256) {
        uint256[2] memory amounts = [uint256(1000e6), uint256(0)];
        (bool success, bytes memory data) = pool.staticcall(
            abi.encodeWithSignature("calc_token_amount(uint256[2],bool)", amounts, true)
        );
        require(success, "calc_token_amount call failed");
        return abi.decode(data, (uint256));
    }
    
    function tryCalcTokenAmount4(address pool) external view returns (uint256) {
        uint256[4] memory amounts = [uint256(1000e6), uint256(0), uint256(0), uint256(0)];
        (bool success, bytes memory data) = pool.staticcall(
            abi.encodeWithSignature("calc_token_amount(uint256[4],bool)", amounts, true)
        );
        require(success, "calc_token_amount call failed");
        return abi.decode(data, (uint256));
    }
    
    function tryCalcTokenAmountDynamic(address pool) external view returns (uint256) {
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1000e6;
        amounts[1] = 0;
        (bool success, bytes memory data) = pool.staticcall(
            abi.encodeWithSignature("calc_token_amount(uint256[],bool)", amounts, true)
        );
        require(success, "calc_token_amount call failed");
        return abi.decode(data, (uint256));
    }
    
    function tryCalcWithdrawOneCoin(address pool) external view returns (uint256) {
        (bool success, bytes memory data) = pool.staticcall(
            abi.encodeWithSignature("calc_withdraw_one_coin(uint256,int128)", 1000e18, int128(0))
        );
        require(success, "calc_withdraw_one_coin call failed");
        return abi.decode(data, (uint256));
    }
    
    function tryGetNCoins(address pool) external view returns (uint256) {
        (bool success, bytes memory data) = pool.staticcall(
            abi.encodeWithSignature("N_COINS()")
        );
        require(success, "N_COINS call failed");
        return abi.decode(data, (uint256));
    }
    
    /**
     * @notice Test other common pool functions
     */
    function testOtherPoolFunctions() public view {
        address pool = ArbitrumConstants.USDC_USDe_CRV_POOL;
        
        // Try get_dy (exchange rate)
        console.log("\nTesting get_dy function...");
        try this.tryGetDy(pool, 0, 1, 1000e6) returns (uint256 dy) {
            console.log("SUCCESS: get_dy(0, 1, 1000 USDC) =", dy, "USDe");
        } catch {
            console.log("FAILED: get_dy failed");
        }
        
        // Try get_virtual_price
        console.log("\nTesting get_virtual_price function...");
        try this.tryGetVirtualPrice(pool) returns (uint256 vp) {
            console.log("SUCCESS: get_virtual_price =", vp);
        } catch {
            console.log("FAILED: get_virtual_price failed");
        }
        
        // Try fee getter
        console.log("\nTesting fee function...");
        try this.tryGetFee(pool) returns (uint256 fee) {
            console.log("SUCCESS: fee =", fee, "(in basis points * 1e4)");
        } catch {
            console.log("FAILED: fee failed");
        }
    }
    
    function tryGetDy(address pool, int128 i, int128 j, uint256 dx) external view returns (uint256) {
        (bool success, bytes memory data) = pool.staticcall(
            abi.encodeWithSignature("get_dy(int128,int128,uint256)", i, j, dx)
        );
        require(success, "get_dy call failed");
        return abi.decode(data, (uint256));
    }
    
    function tryGetVirtualPrice(address pool) external view returns (uint256) {
        (bool success, bytes memory data) = pool.staticcall(
            abi.encodeWithSignature("get_virtual_price()")
        );
        require(success, "get_virtual_price call failed");
        return abi.decode(data, (uint256));
    }
    
    function tryGetFee(address pool) external view returns (uint256) {
        (bool success, bytes memory data) = pool.staticcall(
            abi.encodeWithSignature("fee()")
        );
        require(success, "fee call failed");
        return abi.decode(data, (uint256));
    }
}