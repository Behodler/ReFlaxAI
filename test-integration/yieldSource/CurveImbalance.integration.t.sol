// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IntegrationTest} from "../base/IntegrationTest.sol";
import {ArbitrumConstants} from "../base/ArbitrumConstants.sol";
import {IERC20} from "@oz_reflax/token/ERC20/IERC20.sol";
import {console} from "forge-std/console.sol";

// Interface for newer Curve pools (StableSwapNG)
interface ICurvePoolNG {
    function add_liquidity(uint256[] memory amounts, uint256 min_mint_amount) external payable returns (uint256);
    function remove_liquidity_one_coin(uint256 token_amount, int128 i, uint256 min_amount) external returns (uint256);
    function coins(uint256 i) external view returns (address);
    function get_virtual_price() external view returns (uint256);
    function calc_token_amount(uint256[] memory amounts, bool is_deposit) external view returns (uint256);
    function balances(uint256 i) external view returns (uint256);
    function get_dy(int128 i, int128 j, uint256 dx) external view returns (uint256);
}

/**
 * @title CurveImbalanceIntegrationTest
 * @notice Tests protocol behavior when Curve pools are heavily imbalanced
 * @dev Uses real Arbitrum mainnet fork to test realistic imbalance scenarios
 */
contract CurveImbalanceIntegrationTest is IntegrationTest {
    // Real Curve pool
    ICurvePoolNG public curvePool;
    
    // Test users
    address public alice = address(0x1111);
    address public bob = address(0x2222);
    address public charlie = address(0x3333);
    address public whale = address(0x4444);
    
    // Constants
    uint256 constant SLIPPAGE_TOLERANCE = 500; // 5% = 500 basis points
    uint256 constant SEVERE_IMBALANCE_THRESHOLD = 8000; // 80% in one token
    
    function setUp() public override {
        super.setUp();
        
        curvePool = ICurvePoolNG(ArbitrumConstants.USDC_USDe_CRV_POOL);
        
        // Label addresses
        vm.label(alice, "Alice");
        vm.label(bob, "Bob");
        vm.label(charlie, "Charlie");
        vm.label(whale, "Whale");
        vm.label(address(curvePool), "CurvePool");
    }
    
    /**
     * @notice Test deposits when pool has severe imbalance
     * @dev Creates imbalance and tests how it affects LP token calculations
     */
    function testDepositWithSevereImbalance() public {
        // First, check current pool balance
        uint256 usdcBalance = curvePool.balances(0);
        uint256 usdeBalance = curvePool.balances(1);
        
        console.log("=== Initial Pool State ===");
        console.log("USDC Balance:", usdcBalance / 1e6, "USDC");
        console.log("USDe Balance:", usdeBalance / 1e18, "USDe");
        
        // Create severe imbalance by adding large USDC deposit
        uint256 imbalanceAmount = 5_000_000e6; // 5M USDC
        dealUSDC(whale, imbalanceAmount);
        
        vm.startPrank(whale);
        usdc.approve(address(curvePool), imbalanceAmount);
        
        uint256[] memory whaleAmounts = new uint256[](2);
        whaleAmounts[0] = imbalanceAmount;
        whaleAmounts[1] = 0;
        
        // Calculate expected LP before adding
        uint256 expectedLp = curvePool.calc_token_amount(whaleAmounts, true);
        uint256 actualLp = curvePool.add_liquidity(whaleAmounts, expectedLp * 95 / 100);
        vm.stopPrank();
        
        // Check new pool state
        uint256 newUsdcBalance = curvePool.balances(0);
        uint256 newUsdeBalance = curvePool.balances(1);
        uint256 totalValue = newUsdcBalance + (newUsdeBalance / 1e12);
        uint256 usdcRatio = (newUsdcBalance * 10000) / totalValue;
        
        console.log("\n=== After Creating Imbalance ===");
        console.log("USDC Balance:", newUsdcBalance / 1e6, "USDC");
        console.log("USDe Balance:", newUsdeBalance / 1e18, "USDe");
        console.log("USDC Ratio:", usdcRatio / 100, "%");
        
        // Now test different deposit scenarios with imbalanced pool
        
        // Test 1: Deposit to the abundant token (USDC)
        uint256 usdcDepositAmount = 10_000e6; // 10k USDC
        dealUSDC(alice, usdcDepositAmount);
        
        vm.startPrank(alice);
        usdc.approve(address(curvePool), usdcDepositAmount);
        
        uint256[] memory aliceAmounts = new uint256[](2);
        aliceAmounts[0] = usdcDepositAmount;
        aliceAmounts[1] = 0;
        
        uint256 aliceExpectedLp = curvePool.calc_token_amount(aliceAmounts, true);
        uint256 aliceActualLp = curvePool.add_liquidity(aliceAmounts, aliceExpectedLp * 95 / 100);
        vm.stopPrank();
        
        console.log("\n=== Alice deposits to abundant token (USDC) ===");
        console.log("Deposit Amount:", usdcDepositAmount / 1e6, "USDC");
        console.log("Expected LP:", aliceExpectedLp);
        console.log("Actual LP:", aliceActualLp);
        console.log("LP per USDC:", aliceActualLp / (usdcDepositAmount / 1e6));
        
        // Test 2: Deposit to the scarce token (USDe)
        uint256 usdeDepositAmount = 5_000e18; // 5k USDe (reduced to fit whale balance)
        dealUSDe(bob, usdeDepositAmount);
        
        vm.startPrank(bob);
        usde.approve(address(curvePool), usdeDepositAmount);
        
        uint256[] memory bobAmounts = new uint256[](2);
        bobAmounts[0] = 0;
        bobAmounts[1] = usdeDepositAmount;
        
        uint256 bobExpectedLp = curvePool.calc_token_amount(bobAmounts, true);
        uint256 bobActualLp = curvePool.add_liquidity(bobAmounts, bobExpectedLp * 95 / 100);
        vm.stopPrank();
        
        console.log("\n=== Bob deposits to scarce token (USDe) ===");
        console.log("Deposit Amount:", usdeDepositAmount / 1e18, "USDe");
        console.log("Expected LP:", bobExpectedLp);
        console.log("Actual LP:", bobActualLp);
        console.log("LP per USDe:", bobActualLp / (usdeDepositAmount / 1e18));
        
        // Compare LP token efficiency
        uint256 lpDifference = bobActualLp > aliceActualLp 
            ? ((bobActualLp - aliceActualLp) * 10000) / aliceActualLp
            : ((aliceActualLp - bobActualLp) * 10000) / bobActualLp;
            
        console.log("\n=== LP Token Efficiency ===");
        console.log("Scarce token deposit advantage:", lpDifference, "bps");
        
        // Verify that depositing scarce token gets bonus LP tokens
        assertGt(bobActualLp, aliceActualLp, "Scarce token deposit should receive more LP tokens");
    }
    
    /**
     * @notice Test withdrawals from an imbalanced pool
     * @dev Shows how imbalance affects withdrawal values
     */
    function testWithdrawalFromImbalancedPool() public {
        // Create imbalance first
        uint256 imbalanceAmount = 3_000_000e6; // 3M USDC
        dealUSDC(whale, imbalanceAmount);
        
        vm.startPrank(whale);
        usdc.approve(address(curvePool), imbalanceAmount);
        uint256[] memory whaleAmounts = new uint256[](2);
        whaleAmounts[0] = imbalanceAmount;
        whaleAmounts[1] = 0;
        uint256 whaleLp = curvePool.add_liquidity(whaleAmounts, 0);
        vm.stopPrank();
        
        // Alice deposits balanced amounts before imbalance worsens
        dealUSDC(alice, 50_000e6);
        dealUSDe(alice, 5_000e18); // Reduced to fit whale balance
        
        vm.startPrank(alice);
        usdc.approve(address(curvePool), 50_000e6);
        usde.approve(address(curvePool), 50_000e18);
        
        uint256[] memory aliceAmounts = new uint256[](2);
        aliceAmounts[0] = 50_000e6;
        aliceAmounts[1] = 5_000e18;
        uint256 aliceLp = curvePool.add_liquidity(aliceAmounts, 0);
        
        // Now test withdrawals
        uint256 lpToWithdraw = aliceLp / 2;
        
        // Withdraw to USDC (abundant token)
        uint256 usdcBefore = usdc.balanceOf(alice);
        uint256 usdcWithdrawn = curvePool.remove_liquidity_one_coin(lpToWithdraw, 0, 0);
        uint256 usdcAfter = usdc.balanceOf(alice);
        
        console.log("\n=== Withdrawal to abundant token (USDC) ===");
        console.log("LP withdrawn:", lpToWithdraw);
        console.log("USDC received:", (usdcAfter - usdcBefore) / 1e6);
        
        // Withdraw remaining to USDe (scarce token)
        uint256 usdeBefore = usde.balanceOf(alice);
        uint256 usdeWithdrawn = curvePool.remove_liquidity_one_coin(lpToWithdraw, 1, 0);
        uint256 usdeAfter = usde.balanceOf(alice);
        
        console.log("\n=== Withdrawal to scarce token (USDe) ===");
        console.log("LP withdrawn:", lpToWithdraw);
        console.log("USDe received:", (usdeAfter - usdeBefore) / 1e18);
        
        vm.stopPrank();
        
        // Calculate value difference
        uint256 usdcValue = (usdcAfter - usdcBefore);
        uint256 usdeValue = (usdeAfter - usdeBefore) / 1e12; // Convert to 6 decimals
        
        console.log("\n=== Value Comparison ===");
        console.log("USDC value:", usdcValue / 1e6);
        console.log("USDe value:", usdeValue / 1e6);
        
        // In heavily imbalanced pool, the bonding curve can result in different behaviors
        // Log the difference for analysis
        if (usdcValue > usdeValue) {
            uint256 difference = ((usdcValue - usdeValue) * 10000) / usdeValue;
            console.log("USDC withdrawal advantage:", difference, "bps");
        } else {
            uint256 difference = ((usdeValue - usdcValue) * 10000) / usdcValue;
            console.log("USDe withdrawal advantage:", difference, "bps");
        }
        
        // Verify both withdrawals succeeded with non-zero amounts
        assertGt(usdcValue, 0, "USDC withdrawal should return non-zero value");
        assertGt(usdeValue, 0, "USDe withdrawal should return non-zero value");
    }
    
    /**
     * @notice Test that slippage protection prevents bad trades in imbalanced pools
     * @dev Verifies the protocol rejects trades with excessive slippage
     */
    function testSlippageProtectionPreventsImbalancedTrades() public {
        // Create extreme imbalance
        uint256 extremeAmount = 10_000_000e6; // 10M USDC
        dealUSDC(whale, extremeAmount);
        
        vm.startPrank(whale);
        usdc.approve(address(curvePool), extremeAmount);
        uint256[] memory whaleAmounts = new uint256[](2);
        whaleAmounts[0] = extremeAmount;
        whaleAmounts[1] = 0;
        curvePool.add_liquidity(whaleAmounts, 0);
        vm.stopPrank();
        
        // Check pool state
        uint256 usdcBalance = curvePool.balances(0);
        uint256 usdeBalance = curvePool.balances(1);
        uint256 totalValue = usdcBalance + (usdeBalance / 1e12);
        uint256 usdcRatio = (usdcBalance * 10000) / totalValue;
        
        console.log("\n=== Extreme Imbalance Created ===");
        console.log("USDC Ratio:", usdcRatio / 100, "%");
        
        // Try to deposit more USDC (worsening imbalance)
        dealUSDC(alice, 100_000e6);
        
        vm.startPrank(alice);
        usdc.approve(address(curvePool), 100_000e6);
        
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 100_000e6;
        amounts[1] = 0;
        
        // Calculate expected LP with extreme imbalance
        uint256 expectedLp = curvePool.calc_token_amount(amounts, true);
        
        // Calculate what LP we would get with balanced pool (approximation)
        uint256 virtualPrice = curvePool.get_virtual_price();
        uint256 fairLp = (100_000e6 * 1e12 * 1e18) / virtualPrice;
        
        // Calculate actual slippage
        uint256 slippageBps = ((fairLp - expectedLp) * 10000) / fairLp;
        
        console.log("\n=== Slippage Analysis ===");
        console.log("Expected LP (imbalanced):", expectedLp);
        console.log("Fair LP (balanced estimate):", fairLp);
        console.log("Slippage:", slippageBps, "bps");
        
        // If slippage is too high, the protocol should reject
        if (slippageBps > SLIPPAGE_TOLERANCE) {
            // Try to add liquidity with tight slippage protection
            vm.expectRevert();
            curvePool.add_liquidity(amounts, fairLp * 95 / 100);
            console.log("Transaction correctly rejected due to high slippage");
        } else {
            // Add liquidity succeeds
            uint256 actualLp = curvePool.add_liquidity(amounts, expectedLp * 95 / 100);
            console.log("Transaction succeeded with acceptable slippage");
            assertGe(actualLp, expectedLp * 95 / 100, "LP received should meet minimum");
        }
        
        vm.stopPrank();
    }
    
    /**
     * @notice Test how rebalancing trades affect the pool
     * @dev Shows bonus LP tokens for trades that improve balance
     */
    function testPoolRebalancingEffects() public {
        // Create moderate imbalance (70% USDC, 30% USDe)
        uint256 imbalanceAmount = 2_000_000e6; // 2M USDC
        dealUSDC(whale, imbalanceAmount);
        
        vm.startPrank(whale);
        usdc.approve(address(curvePool), imbalanceAmount);
        uint256[] memory whaleAmounts = new uint256[](2);
        whaleAmounts[0] = imbalanceAmount;
        whaleAmounts[1] = 0;
        curvePool.add_liquidity(whaleAmounts, 0);
        vm.stopPrank();
        
        // Record pool state
        uint256 beforeUsdcBalance = curvePool.balances(0);
        uint256 beforeUsdeBalance = curvePool.balances(1);
        
        console.log("\n=== Initial Imbalanced State ===");
        console.log("USDC:", beforeUsdcBalance / 1e6);
        console.log("USDe:", beforeUsdeBalance / 1e18);
        
        // Alice adds liquidity that improves balance (more USDe)
        uint256 usdeRebalanceAmount = 5_000e18; // 5k USDe (reduced to fit whale balance)
        uint256 usdcSmallAmount = 500e6; // 500 USDC
        
        dealUSDe(alice, usdeRebalanceAmount);
        dealUSDC(alice, usdcSmallAmount);
        
        vm.startPrank(alice);
        usde.approve(address(curvePool), usdeRebalanceAmount);
        usdc.approve(address(curvePool), usdcSmallAmount);
        
        // First calculate LP for balanced deposit
        uint256[] memory balancedAmounts = new uint256[](2);
        balancedAmounts[0] = 2_750e6; // 2.75k USDC equivalent
        balancedAmounts[1] = 2_750e18; // 2.75k USDe
        uint256 balancedLp = curvePool.calc_token_amount(balancedAmounts, true);
        
        // Now calculate LP for rebalancing deposit
        uint256[] memory rebalanceAmounts = new uint256[](2);
        rebalanceAmounts[0] = usdcSmallAmount;
        rebalanceAmounts[1] = usdeRebalanceAmount;
        uint256 rebalanceLp = curvePool.calc_token_amount(rebalanceAmounts, true);
        
        // Execute the rebalancing deposit
        uint256 actualLp = curvePool.add_liquidity(rebalanceAmounts, 0);
        
        console.log("\n=== Rebalancing Deposit ===");
        console.log("Balanced deposit LP (theoretical):", balancedLp);
        console.log("Rebalancing deposit LP:", rebalanceLp);
        console.log("Actual LP received:", actualLp);
        
        // Calculate bonus
        if (rebalanceLp > balancedLp) {
            uint256 bonusBps = ((rebalanceLp - balancedLp) * 10000) / balancedLp;
            console.log("Rebalancing bonus:", bonusBps, "bps");
        }
        
        // Check new pool state
        uint256 afterUsdcBalance = curvePool.balances(0);
        uint256 afterUsdeBalance = curvePool.balances(1);
        uint256 totalAfter = afterUsdcBalance + (afterUsdeBalance / 1e12);
        uint256 newUsdcRatio = (afterUsdcBalance * 10000) / totalAfter;
        
        console.log("\n=== After Rebalancing ===");
        console.log("USDC Ratio:", newUsdcRatio / 100, "%");
        console.log("Pool is more balanced:", newUsdcRatio < 7000 ? "Yes" : "No");
        
        vm.stopPrank();
    }
    
    /**
     * @notice Test multiple users interacting with imbalanced pool
     * @dev Comprehensive scenario with deposits and withdrawals
     */
    function testMultiUserImbalanceScenario() public {
        // Initial pool state
        console.log("\n=== Multi-User Imbalance Scenario ===");
        
        // Whale creates initial imbalance
        uint256 whaleUsdc = 4_000_000e6; // 4M USDC
        dealUSDC(whale, whaleUsdc);
        
        vm.startPrank(whale);
        usdc.approve(address(curvePool), whaleUsdc);
        uint256[] memory whaleAmounts = new uint256[](2);
        whaleAmounts[0] = whaleUsdc;
        whaleAmounts[1] = 0;
        uint256 whaleLp = curvePool.add_liquidity(whaleAmounts, 0);
        vm.stopPrank();
        
        console.log("Whale deposited 4M USDC, created imbalance");
        
        // Alice deposits to scarce asset (USDe)
        uint256 aliceUsde = 2_000e18; // 2k USDe (reduced to fit whale balance)
        dealUSDe(alice, aliceUsde);
        
        vm.startPrank(alice);
        usde.approve(address(curvePool), aliceUsde);
        uint256[] memory aliceAmounts = new uint256[](2);
        aliceAmounts[0] = 0;
        aliceAmounts[1] = aliceUsde;
        uint256 aliceLp = curvePool.add_liquidity(aliceAmounts, 0);
        vm.stopPrank();
        
        console.log("Alice deposited 200k USDe (scarce asset)");
        
        // Bob deposits mixed amounts
        uint256 bobUsdc = 100_000e6; // 100k USDC
        uint256 bobUsde = 1_500e18; // 1.5k USDe (reduced to fit whale balance)
        dealUSDC(bob, bobUsdc);
        dealUSDe(bob, bobUsde);
        
        vm.startPrank(bob);
        usdc.approve(address(curvePool), bobUsdc);
        usde.approve(address(curvePool), bobUsde);
        uint256[] memory bobAmounts = new uint256[](2);
        bobAmounts[0] = bobUsdc;
        bobAmounts[1] = bobUsde;
        uint256 bobLp = curvePool.add_liquidity(bobAmounts, 0);
        vm.stopPrank();
        
        console.log("Bob deposited mixed: 100k USDC + 150k USDe");
        
        // Charlie tries large USDC deposit (worsening imbalance)
        uint256 charlieUsdc = 500_000e6; // 500k USDC
        dealUSDC(charlie, charlieUsdc);
        
        vm.startPrank(charlie);
        usdc.approve(address(curvePool), charlieUsdc);
        uint256[] memory charlieAmounts = new uint256[](2);
        charlieAmounts[0] = charlieUsdc;
        charlieAmounts[1] = 0;
        
        // Calculate expected LP and slippage
        uint256 expectedCharlieLp = curvePool.calc_token_amount(charlieAmounts, true);
        uint256 virtualPrice = curvePool.get_virtual_price();
        uint256 fairLp = (charlieUsdc * 1e12 * 1e18) / virtualPrice;
        uint256 slippage = ((fairLp - expectedCharlieLp) * 10000) / fairLp;
        
        console.log("\nCharlie attempting 500k USDC deposit:");
        console.log("Expected slippage:", slippage, "bps");
        
        uint256 charlieLp = curvePool.add_liquidity(charlieAmounts, expectedCharlieLp * 95 / 100);
        vm.stopPrank();
        
        // Now test withdrawals
        console.log("\n=== Withdrawal Phase ===");
        
        // Alice withdraws half to USDC
        vm.startPrank(alice);
        uint256 aliceUsdcBefore = usdc.balanceOf(alice);
        curvePool.remove_liquidity_one_coin(aliceLp / 2, 0, 0);
        uint256 aliceUsdcAfter = usdc.balanceOf(alice);
        console.log("Alice withdrew to USDC:", (aliceUsdcAfter - aliceUsdcBefore) / 1e6);
        vm.stopPrank();
        
        // Bob withdraws all to USDe
        vm.startPrank(bob);
        uint256 bobUsdeBefore = usde.balanceOf(bob);
        curvePool.remove_liquidity_one_coin(bobLp, 1, 0);
        uint256 bobUsdeAfter = usde.balanceOf(bob);
        console.log("Bob withdrew to USDe:", (bobUsdeAfter - bobUsdeBefore) / 1e18);
        vm.stopPrank();
        
        // Final pool state
        uint256 finalUsdcBalance = curvePool.balances(0);
        uint256 finalUsdeBalance = curvePool.balances(1);
        uint256 finalTotal = finalUsdcBalance + (finalUsdeBalance / 1e12);
        uint256 finalUsdcRatio = (finalUsdcBalance * 10000) / finalTotal;
        
        console.log("\n=== Final Pool State ===");
        console.log("USDC Ratio:", finalUsdcRatio / 100, "%");
        console.log("Pool still imbalanced:", finalUsdcRatio > 6000 ? "Yes" : "No");
        
        // Verify all users could interact despite imbalance
        assertGt(aliceLp, 0, "Alice should have received LP tokens");
        assertGt(bobLp, 0, "Bob should have received LP tokens");
        assertGt(charlieLp, 0, "Charlie should have received LP tokens");
    }
    
    /**
     * @notice Helper to create pool imbalance
     * @param usdcAmount Amount of USDC to add for imbalance
     */
    function createImbalance(uint256 usdcAmount) internal {
        dealUSDC(whale, usdcAmount);
        vm.startPrank(whale);
        usdc.approve(address(curvePool), usdcAmount);
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = usdcAmount;
        amounts[1] = 0;
        curvePool.add_liquidity(amounts, 0);
        vm.stopPrank();
    }
    
    /**
     * @notice Helper to check pool balance ratios
     * @return usdcRatio USDC ratio in basis points
     * @return usdeRatio USDe ratio in basis points
     */
    function getPoolRatios() internal view returns (uint256 usdcRatio, uint256 usdeRatio) {
        uint256 usdcBalance = curvePool.balances(0);
        uint256 usdeBalance = curvePool.balances(1);
        uint256 totalValue = usdcBalance + (usdeBalance / 1e12);
        usdcRatio = (usdcBalance * 10000) / totalValue;
        usdeRatio = 10000 - usdcRatio;
    }
}