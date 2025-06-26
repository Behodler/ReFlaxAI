// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";
import {Vault} from "../src/vault/Vault.sol";
import {CVX_CRV_YieldSource} from "../src/yieldSource/CVX_CRV_YieldSource.sol";
import {PriceTilterTWAP} from "../src/priceTilting/PriceTilterTWAP.sol";
import {TWAPOracle} from "../src/priceTilting/TWAPOracle.sol";
import {MockERC20, MockYieldSource, MockPriceTilter} from "./mocks/Mocks.sol";
import {MockUniswapV3Router, MockCurvePool, MockConvexBooster, MockConvexRewardPool} from "./mocks/Mocks.sol";
import {MockUniswapV2Factory, MockUniswapV2Pair, MockUniswapV2Router} from "./mocks/Mocks.sol";
import {IERC20} from "@oz_reflax/token/ERC20/IERC20.sol";
import {Ownable} from "@oz_reflax/access/Ownable.sol";

// Mock Oracle for testing
contract MockOracle {
    function consult(address, address, uint256 amountIn) external pure returns (uint256) {
        return amountIn; // 1:1 exchange rate
    }
    
    function update(address, address) external {
        // No-op implementation
    }
}

contract AccessControlTest is Test {
    Vault vault;
    CVX_CRV_YieldSource yieldSource;
    PriceTilterTWAP priceTilter;
    TWAPOracle oracle;
    MockERC20 inputToken;
    MockERC20 flaxToken;
    MockERC20 sFlaxToken;
    MockERC20 crvLpToken;
    MockERC20 rewardToken;
    MockOracle mockOracle;
    MockUniswapV3Router uniswapRouter;
    MockCurvePool curvePool;
    MockConvexBooster convexBooster;
    MockConvexRewardPool convexRewardPool;
    MockUniswapV2Factory uniswapFactory;
    MockUniswapV2Pair pair;

    address nonOwner = address(0x1234);
    address weth = address(0x456);

    function setUp() public {
        // Set up tokens
        inputToken = new MockERC20();
        flaxToken = new MockERC20();
        sFlaxToken = new MockERC20();
        crvLpToken = new MockERC20();
        rewardToken = new MockERC20();
        
        // Set up mocks
        mockOracle = new MockOracle();
        uniswapRouter = new MockUniswapV3Router();
        curvePool = new MockCurvePool(address(crvLpToken));
        convexBooster = new MockConvexBooster();
        convexRewardPool = new MockConvexRewardPool(address(rewardToken));
        uniswapFactory = new MockUniswapV2Factory();
        
        // Set up TWAP Oracle
        pair = new MockUniswapV2Pair(address(flaxToken), weth);
        uniswapFactory.setPair(address(flaxToken), weth, address(pair));
        oracle = new TWAPOracle(address(uniswapFactory), weth);
        
        // Set up PriceTilter
        MockUniswapV2Router uniswapV2Router = new MockUniswapV2Router(weth);
        priceTilter = new PriceTilterTWAP(address(uniswapFactory), address(uniswapV2Router), address(flaxToken), address(oracle));
        
        // Set up YieldSource
        address[] memory poolTokens = new address[](2);
        string[] memory poolTokenSymbols = new string[](2);
        address[] memory rewardTokens = new address[](1);
        
        poolTokens[0] = address(inputToken);
        poolTokens[1] = address(rewardToken);
        poolTokenSymbols[0] = "USDC";
        poolTokenSymbols[1] = "USDT";
        rewardTokens[0] = address(rewardToken);

        yieldSource = new CVX_CRV_YieldSource(
            address(inputToken),
            address(flaxToken),
            address(priceTilter),
            address(mockOracle),
            "CRV test",
            address(curvePool),
            address(crvLpToken),
            address(convexBooster),
            address(convexRewardPool),
            123,
            address(uniswapRouter),
            poolTokens,
            poolTokenSymbols,
            rewardTokens
        );

        // Set up Vault
        vault = new Vault(
            address(flaxToken),
            address(sFlaxToken),
            address(inputToken),
            address(yieldSource),
            address(priceTilter)
        );
    }

    // Test Vault owner-only functions
    function testVaultOnlyOwnerFunctions() public {
        // Test setFlaxPerSFlax
        vm.expectRevert();
        vm.prank(nonOwner);
        vault.setFlaxPerSFlax(1e17);

        vm.prank(vault.owner());
        vault.setFlaxPerSFlax(1e17);
        assertEq(vault.flaxPerSFlax(), 1e17);

        // Test setEmergencyState
        vm.expectRevert();
        vm.prank(nonOwner);
        vault.setEmergencyState(true);

        vm.prank(vault.owner());
        vault.setEmergencyState(true);
        assertTrue(vault.emergencyState());

        // Test emergencyWithdraw
        MockERC20 testToken = new MockERC20();
        testToken.mint(address(vault), 1000);

        vm.expectRevert();
        vm.prank(nonOwner);
        vault.emergencyWithdraw(address(testToken), nonOwner);

        vm.prank(vault.owner());
        vault.emergencyWithdraw(address(testToken), nonOwner);
        assertEq(testToken.balanceOf(nonOwner), 1000);

        // Test emergencyWithdrawETH
        vm.deal(address(vault), 1 ether);

        vm.expectRevert();
        vm.prank(nonOwner);
        vault.emergencyWithdrawETH(payable(nonOwner));

        vm.prank(vault.owner());
        vault.emergencyWithdrawETH(payable(nonOwner));
        assertEq(nonOwner.balance, 1 ether);

        // Test emergencyWithdrawFromYieldSource (requires emergency state)
        vm.expectRevert();
        vm.prank(nonOwner);
        vault.emergencyWithdrawFromYieldSource(address(inputToken), nonOwner);

        // Test migrateYieldSource
        MockYieldSource newYieldSource = new MockYieldSource(address(inputToken));
        
        vm.expectRevert();
        vm.prank(nonOwner);
        vault.migrateYieldSource(address(newYieldSource));

        // This should work (owner calling migration)
        vm.prank(vault.owner());
        vault.setEmergencyState(false); // Disable emergency state for migration
        // Note: Full migration test is covered in Vault.t.sol
    }

    // Test YieldSource owner-only functions
    function testYieldSourceOnlyOwnerFunctions() public {
        // Test whitelistVault
        vm.expectRevert();
        vm.prank(nonOwner);
        yieldSource.whitelistVault(address(vault), true);

        vm.prank(yieldSource.owner());
        yieldSource.whitelistVault(address(vault), true);
        assertTrue(yieldSource.whitelistedVaults(address(vault)));

        // Test setMinSlippageBps
        vm.expectRevert();
        vm.prank(nonOwner);
        yieldSource.setMinSlippageBps(100);

        vm.prank(yieldSource.owner());
        yieldSource.setMinSlippageBps(100);
        assertEq(yieldSource.minSlippageBps(), 100);

        // Test setLpTokenName
        vm.expectRevert();
        vm.prank(nonOwner);
        yieldSource.setLpTokenName("New Name");

        vm.prank(yieldSource.owner());
        yieldSource.setLpTokenName("New Name");
        assertEq(yieldSource.lpTokenName(), "New Name");

        // Test setUnderlyingWeights
        uint256[] memory weights = new uint256[](2);
        weights[0] = 5000;
        weights[1] = 5000;

        vm.expectRevert();
        vm.prank(nonOwner);
        yieldSource.setUnderlyingWeights(address(curvePool), weights);

        vm.prank(yieldSource.owner());
        yieldSource.setUnderlyingWeights(address(curvePool), weights);
        assertEq(yieldSource.underlyingWeights(address(curvePool), 0), 5000);

        // Test emergencyWithdraw
        MockERC20 testToken = new MockERC20();
        testToken.mint(address(yieldSource), 1000);

        vm.expectRevert();
        vm.prank(nonOwner);
        yieldSource.emergencyWithdraw(address(testToken), nonOwner);

        vm.prank(yieldSource.owner());
        yieldSource.emergencyWithdraw(address(testToken), nonOwner);
        assertEq(testToken.balanceOf(nonOwner), 1000);
    }

    // Test PriceTilter owner-only functions
    function testPriceTilterOnlyOwnerFunctions() public {
        // Test setPriceTiltRatio
        vm.expectRevert();
        vm.prank(nonOwner);
        priceTilter.setPriceTiltRatio(5000);

        vm.prank(priceTilter.owner());
        priceTilter.setPriceTiltRatio(5000);
        assertEq(priceTilter.priceTiltRatio(), 5000);

        // Test registerPair
        vm.expectRevert();
        vm.prank(nonOwner);
        priceTilter.registerPair(address(flaxToken), weth);

        vm.prank(priceTilter.owner());
        priceTilter.registerPair(address(flaxToken), weth);
        address flaxWethPair = uniswapFactory.getPair(address(flaxToken), weth);
        assertTrue(priceTilter.isPairRegistered(flaxWethPair));

        // Test emergencyWithdraw
        MockERC20 testToken = new MockERC20();
        testToken.mint(address(priceTilter), 1000);

        vm.expectRevert();
        vm.prank(nonOwner);
        priceTilter.emergencyWithdraw(address(testToken), nonOwner);

        vm.prank(priceTilter.owner());
        priceTilter.emergencyWithdraw(address(testToken), nonOwner);
        assertEq(testToken.balanceOf(nonOwner), 1000);
    }

    // Test that non-owner cannot perform critical operations
    function testCriticalOperationsProtection() public {
        // Ensure non-owner cannot change system parameters
        vm.startPrank(nonOwner);

        // Cannot change Vault parameters
        vm.expectRevert();
        vault.setFlaxPerSFlax(0);

        // Cannot enable emergency state
        vm.expectRevert();
        vault.setEmergencyState(true);

        // Cannot change slippage protection
        vm.expectRevert();
        yieldSource.setMinSlippageBps(10000); // Would disable protection

        // Cannot register malicious pairs in PriceTilter
        vm.expectRevert();
        priceTilter.registerPair(address(0xDEAD), address(0xBEEF));

        // Cannot change price tilt ratio
        vm.expectRevert();
        priceTilter.setPriceTiltRatio(0); // Would disable price tilting

        vm.stopPrank();
    }

    // Test owner transfer scenarios
    function testOwnershipTransfer() public {
        address newOwner = address(0x9999);

        // Test Vault ownership transfer
        vm.prank(vault.owner());
        vault.transferOwnership(newOwner);
        assertEq(vault.owner(), newOwner);

        // New owner can call owner functions
        vm.prank(newOwner);
        vault.setFlaxPerSFlax(2e17);
        assertEq(vault.flaxPerSFlax(), 2e17);

        // Old owner cannot call functions anymore
        vm.expectRevert();
        vm.prank(address(this)); // Original deployer
        vault.setFlaxPerSFlax(3e17);
    }

    // Test that critical state changes emit events by verifying actual emission
    function testOwnerOperationsEmitEvents() public {
        // Test Vault FlaxPerSFlaxUpdated event
        vm.recordLogs();
        vm.prank(vault.owner());
        vault.setFlaxPerSFlax(1e17);
        
        Vm.Log[] memory entries = vm.getRecordedLogs();
        assertEq(entries.length, 1, "Should emit exactly one event");
        assertEq(entries[0].topics[0], keccak256("FlaxPerSFlaxUpdated(uint256)"), "Wrong event signature");
        assertEq(abi.decode(entries[0].data, (uint256)), 1e17, "Wrong flaxPerSFlax value");

        // Test Vault EmergencyStateChanged event
        vm.recordLogs();
        vm.prank(vault.owner());
        vault.setEmergencyState(true);
        
        entries = vm.getRecordedLogs();
        assertEq(entries.length, 1, "Should emit exactly one event");
        assertEq(entries[0].topics[0], keccak256("EmergencyStateChanged(bool)"), "Wrong event signature");
        assertEq(abi.decode(entries[0].data, (bool)), true, "Wrong emergency state value");

        // Test YieldSource VaultWhitelisted event
        vm.recordLogs();
        vm.prank(yieldSource.owner());
        yieldSource.whitelistVault(address(vault), true);
        
        entries = vm.getRecordedLogs();
        assertEq(entries.length, 1, "Should emit exactly one event");
        assertEq(entries[0].topics[0], keccak256("VaultWhitelisted(address,bool)"), "Wrong event signature");
        assertEq(entries[0].topics[1], bytes32(uint256(uint160(address(vault)))), "Wrong vault address");
        assertEq(abi.decode(entries[0].data, (bool)), true, "Wrong whitelisted value");

        // Test PriceTilter PriceTiltRatioUpdated event
        vm.recordLogs();
        vm.prank(priceTilter.owner());
        priceTilter.setPriceTiltRatio(5000);
        
        entries = vm.getRecordedLogs();
        assertEq(entries.length, 1, "Should emit exactly one event");
        assertEq(entries[0].topics[0], keccak256("PriceTiltRatioUpdated(uint256)"), "Wrong event signature");
        assertEq(abi.decode(entries[0].data, (uint256)), 5000, "Wrong priceTiltRatio value");
    }

    // Events (copied from contracts for testing)
    event FlaxPerSFlaxUpdated(uint256 newRatio);
    event EmergencyStateChanged(bool state);
    event VaultWhitelisted(address indexed vault, bool whitelisted);
    event PriceTiltRatioUpdated(uint256 newRatio);
}