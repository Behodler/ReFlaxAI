// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/priceTilting/PriceTilterTWAP.sol";
import "./mocks/Mocks.sol";


// Mock Oracle for PriceTilterTWAP tests
contract MockOracle {
    uint256 private consultReturn;
    bool private updateCalled;
    
    event UpdateCalled(address tokenA, address tokenB);
    
    function setConsultReturn(uint256 value) external {
        consultReturn = value;
    }
    
    function consult(address, address, uint256) external view returns (uint256) {
        return consultReturn;
    }
    
    function update(address tokenA, address tokenB) external {
        updateCalled = true;
        emit UpdateCalled(tokenA, tokenB);
    }
    
    function wasUpdateCalled() external view returns (bool) {
        return updateCalled;
    }
    
    function resetUpdateCalled() external {
        updateCalled = false;
    }
}

contract PriceTilterTWAPTest is Test {
    PriceTilterTWAP priceTilter;
    MockERC20 flaxToken;
    MockERC20 weth;
    MockUniswapV2Factory factory;
    MockUniswapV2Pair pair;
    MockUniswapV2Router router;
    MockOracle oracle;
    address user;
    
    function setUp() public {
        // Create mock tokens
        flaxToken = new MockERC20();
        weth = new MockERC20();
        
        // Create mock factory, router and oracle
        factory = new MockUniswapV2Factory();
        router = new MockUniswapV2Router(address(weth));
        oracle = new MockOracle();
        
        // Create mock pair
        pair = new MockUniswapV2Pair(address(flaxToken), address(weth));
        factory.setPair(address(flaxToken), address(weth), address(pair));
        
        // Set up price oracle
        oracle.setConsultReturn(1e17); // 0.1 ETH per FLAX
        
        // Deploy PriceTilter
        priceTilter = new PriceTilterTWAP(
            address(factory),
            address(router),
            address(flaxToken),
            address(oracle)
        );
        
        // Mint flax tokens to PriceTilter
        flaxToken.mint(address(priceTilter), 10000 ether);
        
        // Set up test user
        user = address(0xBEEF);
        vm.deal(user, 100 ether);
        
        // Register the pair
        vm.prank(priceTilter.owner());
        priceTilter.registerPair(address(flaxToken), address(weth));
    }
    
    function testGetPrice() public {
        // Set the oracle response
        oracle.setConsultReturn(2e17); // 0.2 ETH per FLAX
        
        // Call getPrice
        vm.prank(user);
        uint256 price = priceTilter.getPrice(address(flaxToken), address(weth));
        
        // Verify result
        assertEq(price, 2e17, "Price should match oracle response");
        assertTrue(oracle.wasUpdateCalled(), "Oracle update should be called");
    }
    
    function testTiltPrice() public {
        // Set the oracle response (0.1 ETH per FLAX)
        oracle.setConsultReturn(1e17);
        
        // Call tiltPrice with 1 ETH
        vm.startPrank(user);
        uint256 ethAmount = 1 ether;
        uint256 flaxValue = priceTilter.tiltPrice{value: ethAmount}(address(flaxToken), ethAmount);
        vm.stopPrank();
        
        // Expected flax value: ethAmount / ethPerFlax * 1e18 = 1e18 / 1e17 * 1e18 = 10 ether
        uint256 expectedFlaxValue = 10 ether;
        
        // Expected flax amount for liquidity: flaxValue * priceTiltRatio / 10000 = 10e18 * 8000 / 10000 = 8 ether
        uint256 expectedFlaxAmount = 8 ether;
        
        assertEq(flaxValue, expectedFlaxValue, "Flax value calculation incorrect");
        assertEq(router.lastAmountToken(), expectedFlaxAmount, "Incorrect Flax amount added to liquidity");
        assertEq(router.lastAmountETH(), ethAmount, "Incorrect ETH amount added to liquidity");
        assertTrue(oracle.wasUpdateCalled(), "Oracle update should be called");
    }
    
    function testTiltPriceUsesFullEthBalance() public {
        // Set the oracle response (0.1 ETH per FLAX)
        oracle.setConsultReturn(1e17);
        
        // Send some ETH to the contract first
        vm.deal(address(priceTilter), 0.5 ether);
        
        // Call tiltPrice with 1 ETH
        vm.startPrank(user);
        uint256 ethAmount = 1 ether;
        priceTilter.tiltPrice{value: ethAmount}(address(flaxToken), ethAmount);
        vm.stopPrank();
        
        // Should use the total ETH (1.5 ETH)
        uint256 expectedTotalEth = 1.5 ether;
        
        assertEq(router.lastAmountETH(), expectedTotalEth, "Should use total ETH balance");
    }
    
    function testSetPriceTiltRatio() public {
        // Call setPriceTiltRatio
        vm.prank(priceTilter.owner());
        priceTilter.setPriceTiltRatio(9000);
        
        // Verify ratio updated
        assertEq(priceTilter.priceTiltRatio(), 9000, "Ratio should be updated");
        
        // Verify it affects tilt price
        oracle.setConsultReturn(1e17);
        
        vm.prank(user);
        uint256 ethAmount = 1 ether;
        priceTilter.tiltPrice{value: ethAmount}(address(flaxToken), ethAmount);
        
        // Expected flax amount with new ratio: 10e18 * 9000 / 10000 = 9 ether
        uint256 expectedFlaxAmount = 9 ether;
        
        assertEq(router.lastAmountToken(), expectedFlaxAmount, "Flax amount should reflect new ratio");
    }
    
    function testRegisterPair() public {
        // Create new tokens and pair
        MockERC20 tokenA = new MockERC20();
        MockERC20 tokenB = new MockERC20();
        MockUniswapV2Pair newPair = new MockUniswapV2Pair(address(tokenA), address(tokenB));
        factory.setPair(address(tokenA), address(tokenB), address(newPair));
        
        // Reset oracle flag
        oracle.resetUpdateCalled();
        
        // Register the new pair
        vm.prank(priceTilter.owner());
        priceTilter.registerPair(address(tokenA), address(tokenB));
        
        // Verify pair is registered
        assertTrue(priceTilter.isPairRegistered(address(newPair)), "Pair should be registered");
        assertTrue(oracle.wasUpdateCalled(), "Oracle update should be called");
    }
    
    function testEmergencyWithdraw() public {
        // Fund the contract with ETH and tokens
        vm.deal(address(priceTilter), 2 ether);
        flaxToken.mint(address(priceTilter), 5 ether);
        
        // Withdraw ETH
        address recipient = address(0xBEEF);
        vm.prank(priceTilter.owner());
        priceTilter.emergencyWithdraw(address(0), recipient);
        
        assertEq(recipient.balance, 102 ether, "ETH should be withdrawn");
        
        // Withdraw token
        vm.prank(priceTilter.owner());
        priceTilter.emergencyWithdraw(address(flaxToken), recipient);
        
        assertEq(flaxToken.balanceOf(recipient), 10005 ether, "Tokens should be withdrawn");
    }
    
    function testZeroLiquidityReverts() public {
        // Set the oracle response
        oracle.setConsultReturn(1e17);
        
        // Create router that will return zero liquidity
        MockUniswapV2Router zeroRouter = new MockUniswapV2Router(address(weth));
        zeroRouter.setLiquidityToReturn(0);
        
        // Deploy new PriceTilter with zero liquidity router
        PriceTilterTWAP newPriceTilter = new PriceTilterTWAP(
            address(factory),
            address(zeroRouter),
            address(flaxToken),
            address(oracle)
        );
        
        // Register the pair
        vm.prank(newPriceTilter.owner());
        newPriceTilter.registerPair(address(flaxToken), address(weth));
        
        // Mint flax tokens to new PriceTilter
        flaxToken.mint(address(newPriceTilter), 10000 ether);
        
        // Call tiltPrice with 1 ETH - should revert if liquidity is zero
        vm.startPrank(user);
        vm.expectRevert("Liquidity addition failed");
        newPriceTilter.tiltPrice{value: 1 ether}(address(flaxToken), 1 ether);
        vm.stopPrank();
    }
    
    function testTiltPriceRevertsOnInsufficientBalance() public {
        // Set the oracle response
        oracle.setConsultReturn(1e17);
        
        // Create new PriceTilter with no Flax tokens
        PriceTilterTWAP emptyPriceTilter = new PriceTilterTWAP(
            address(factory),
            address(router),
            address(flaxToken),
            address(oracle)
        );
        
        // Register the pair
        vm.prank(emptyPriceTilter.owner());
        emptyPriceTilter.registerPair(address(flaxToken), address(weth));
        
        // Call tiltPrice with 1 ETH - should revert due to insufficient balance
        vm.startPrank(user);
        vm.expectRevert("Insufficient Flax balance");
        emptyPriceTilter.tiltPrice{value: 1 ether}(address(flaxToken), 1 ether);
        vm.stopPrank();
    }
    
    // Negative tests for constructor validation (kills mutations 1, 2, 4, 5, 7, 8, 10, 11)
    function testConstructorRevertsOnZeroFactory() public {
        vm.expectRevert("Invalid factory address");
        new PriceTilterTWAP(
            address(0), // zero factory
            address(router),
            address(flaxToken),
            address(oracle)
        );
    }
    
    function testConstructorRevertsOnZeroRouter() public {
        vm.expectRevert("Invalid router address");
        new PriceTilterTWAP(
            address(factory),
            address(0), // zero router
            address(flaxToken),
            address(oracle)
        );
    }
    
    function testConstructorRevertsOnZeroFlaxToken() public {
        vm.expectRevert("Invalid Flax token address");
        new PriceTilterTWAP(
            address(factory),
            address(router),
            address(0), // zero flax token
            address(oracle)
        );
    }
    
    function testConstructorRevertsOnZeroOracle() public {
        vm.expectRevert("Invalid oracle address");
        new PriceTilterTWAP(
            address(factory),
            address(router),
            address(flaxToken),
            address(0) // zero oracle
        );
    }
    
    // Negative test for setPriceTiltRatio validation (kills mutation 20)
    function testSetPriceTiltRatioRevertsOnExcessiveRatio() public {
        vm.prank(priceTilter.owner());
        vm.expectRevert("Ratio exceeds 100%");
        priceTilter.setPriceTiltRatio(10001); // > 10000 (100%)
    }
} 