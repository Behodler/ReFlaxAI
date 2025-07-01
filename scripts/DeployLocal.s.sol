// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console.sol";

// Core ReFlax contracts
import "../src/vault/Vault.sol";
import "../src/yieldSource/CVX_CRV_YieldSource.sol";
import "../src/priceTilting/PriceTilterTWAP.sol";
import "../src/priceTilting/TWAPOracle.sol";

// Mock contracts for local deployment
import "../test/mocks/LocalDeployment/MockTokens.sol";
import "../test/mocks/LocalDeployment/MockUniswapV3Router.sol";
import "../test/mocks/LocalDeployment/MockCurvePool.sol";
import "../test/mocks/LocalDeployment/MockConvexBooster.sol";
import "../test/mocks/LocalDeployment/MockUniswapV2Factory.sol";

contract LocalDeploymentScript is Script {
    struct DeploymentConfig {
        // Token prices in USD (6 decimals)
        uint256 usdcPrice;
        uint256 usdtPrice;
        uint256 ethPrice;
        uint256 flaxPrice;
        uint256 crvPrice;
        uint256 cvxPrice;
        
        // Initial liquidity amounts
        uint256 initialPoolLiquidity;
        uint256 initialFlaxEthLiquidity;
        
        // Yield rates (basis points)
        uint256 curveApyBps;
        uint256 convexBoostBps;
        
        // Test account funding amounts
        uint256 largeAccountFunding;
        uint256 mediumAccountFunding;
        uint256 smallAccountFunding;
    }

    struct DeployedContracts {
        // Tokens
        address usdc;
        address usdt;
        address weth;
        address crv;
        address cvx;
        address flax;
        address sFlax;
        address curveLP;
        
        // Mock external contracts
        address uniswapV3Router;
        address curvePool;
        address convexBooster;
        address uniswapV2Factory;
        address uniswapV2Router;
        address flaxEthPair;
        
        // Core ReFlax contracts
        address vault;
        address yieldSource;
        address priceTilter;
        address twapOracle;
        
        // Test accounts
        address[4] testAccounts;
    }

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        console.log("=== Starting Local ReFlax Deployment ===");
        console.log("Deployer:", vm.addr(deployerPrivateKey));
        console.log("Network:", block.chainid);
        
        DeploymentConfig memory config = _getDeploymentConfig();
        DeployedContracts memory deployed = _deployAllContracts(config);
        _configureContracts(deployed, config);
        _fundTestAccounts(deployed, config);
        _logDeploymentSummary(deployed);

        vm.stopBroadcast();
        console.log("=== Local ReFlax Deployment Complete ===");
    }

    function _getDeploymentConfig() internal pure returns (DeploymentConfig memory) {
        return DeploymentConfig({
            // Token prices (USD with 6 decimals)
            usdcPrice: 1_000_000,      // $1.00
            usdtPrice: 1_000_000,      // $1.00
            ethPrice: 2000_000_000,    // $2000.00
            flaxPrice: 500_000,        // $0.50
            crvPrice: 300_000,         // $0.30
            cvxPrice: 2_500_000,       // $2.50
            
            // Initial liquidity
            initialPoolLiquidity: 100_000 * 1e6,     // $100K in stablecoins
            initialFlaxEthLiquidity: 10 ether,        // 10 ETH worth
            
            // APY rates
            curveApyBps: 700,          // 7% Curve LP APY
            convexBoostBps: 400,       // 4% Convex boost
            
            // Test account funding
            largeAccountFunding: 10_000 * 1e6,       // $10K
            mediumAccountFunding: 1_000 * 1e6,       // $1K
            smallAccountFunding: 100 * 1e6           // $100
        });
    }

    function _deployAllContracts(DeploymentConfig memory config) 
        internal 
        returns (DeployedContracts memory deployed) 
    {
        console.log("Deploying tokens...");
        deployed = _deployTokens(deployed);
        
        console.log("Deploying mock external contracts...");
        deployed = _deployMockExternalContracts(deployed, config);
        
        console.log("Deploying core ReFlax contracts...");
        deployed = _deployCoreContracts(deployed);
        
        console.log("Setting up test accounts...");
        deployed = _setupTestAccounts(deployed);
        
        return deployed;
    }

    function _deployTokens(DeployedContracts memory deployed) 
        internal 
        returns (DeployedContracts memory) 
    {
        // Deploy tokens directly to avoid contract size limits
        deployed.usdc = address(new MockUSDC());
        deployed.usdt = address(new MockUSDT());
        deployed.weth = address(new MockWETH());
        deployed.crv = address(new MockCRV());
        deployed.cvx = address(new MockCVX());
        deployed.flax = address(new MockFlax());
        deployed.sFlax = address(new MockSFlax());
        deployed.curveLP = address(new MockCurveLP("Curve USDC/USDT LP", "crvUSDCUSDT"));
        
        console.log("  USDC:", deployed.usdc);
        console.log("  USDT:", deployed.usdt);
        console.log("  WETH:", deployed.weth);
        console.log("  CRV:", deployed.crv);
        console.log("  CVX:", deployed.cvx);
        console.log("  Flax:", deployed.flax);
        console.log("  sFlax:", deployed.sFlax);
        console.log("  CurveLP:", deployed.curveLP);
        
        return deployed;
    }

    function _deployMockExternalContracts(
        DeployedContracts memory deployed, 
        DeploymentConfig memory config
    ) internal returns (DeployedContracts memory) {
        // Deploy Uniswap V3 Router
        deployed.uniswapV3Router = address(new MockUniswapV3Router());
        console.log("  UniswapV3Router:", deployed.uniswapV3Router);
        
        // Deploy Curve Pool
        address[] memory coins = new address[](2);
        coins[0] = deployed.usdc;
        coins[1] = deployed.usdt;
        deployed.curvePool = address(new MockCurvePool(deployed.curveLP, coins));
        console.log("  CurvePool:", deployed.curvePool);
        
        // Deploy Convex Booster
        deployed.convexBooster = address(new MockConvexBooster(deployed.crv, address(0)));
        console.log("  ConvexBooster:", deployed.convexBooster);
        
        // Deploy Uniswap V2 Factory and Router
        deployed.uniswapV2Factory = address(new MockUniswapV2Factory());
        deployed.uniswapV2Router = address(new MockUniswapV2Router(deployed.uniswapV2Factory, deployed.weth));
        console.log("  UniswapV2Factory:", deployed.uniswapV2Factory);
        console.log("  UniswapV2Router:", deployed.uniswapV2Router);
        
        // Create Flax/ETH pair
        deployed.flaxEthPair = MockUniswapV2Factory(deployed.uniswapV2Factory)
            .createPair(deployed.flax, deployed.weth);
        console.log("  FlaxETHPair:", deployed.flaxEthPair);
        
        return deployed;
    }

    function _deployCoreContracts(DeployedContracts memory deployed) 
        internal 
        returns (DeployedContracts memory) 
    {
        // Deploy TWAP Oracle
        deployed.twapOracle = address(new TWAPOracle(
            deployed.uniswapV2Factory,
            deployed.weth
        ));
        console.log("  TWAPOracle:", deployed.twapOracle);
        
        // Deploy PriceTilter
        deployed.priceTilter = address(new PriceTilterTWAP(
            deployed.uniswapV2Factory,
            deployed.uniswapV2Router,
            deployed.flax,
            deployed.twapOracle
        ));
        console.log("  PriceTilter:", deployed.priceTilter);
        
        // Deploy YieldSource
        address[] memory poolTokens = new address[](2);
        poolTokens[0] = deployed.usdc;
        poolTokens[1] = deployed.usdt;
        
        string[] memory poolTokenSymbols = new string[](2);
        poolTokenSymbols[0] = "USDC";
        poolTokenSymbols[1] = "USDT";
        
        address[] memory rewardTokens = new address[](2);
        rewardTokens[0] = deployed.crv;
        rewardTokens[1] = deployed.cvx;
        
        deployed.yieldSource = address(new CVX_CRV_YieldSource(
            deployed.usdc,
            deployed.flax,
            deployed.priceTilter,
            deployed.twapOracle,
            "USDC/USDT LP",
            deployed.curvePool,
            deployed.curveLP,
            deployed.convexBooster,
            address(0), // convex reward pool - use zero for mock
            0, // pool ID
            deployed.uniswapV3Router,
            poolTokens,
            poolTokenSymbols,
            rewardTokens
        ));
        console.log("  YieldSource:", deployed.yieldSource);
        
        // Deploy Vault
        deployed.vault = address(new TestVault(
            deployed.usdc,
            deployed.yieldSource,
            deployed.flax,
            deployed.sFlax
        ));
        console.log("  Vault:", deployed.vault);
        
        return deployed;
    }

    function _setupTestAccounts(DeployedContracts memory deployed) 
        internal 
        returns (DeployedContracts memory) 
    {
        // Generate deterministic test accounts
        deployed.testAccounts[0] = vm.addr(1); // Large depositor
        deployed.testAccounts[1] = vm.addr(2); // Medium depositor  
        deployed.testAccounts[2] = vm.addr(3); // Small depositor
        deployed.testAccounts[3] = vm.addr(4); // New user
        
        console.log("  Test Account 1 (Large):", deployed.testAccounts[0]);
        console.log("  Test Account 2 (Medium):", deployed.testAccounts[1]);
        console.log("  Test Account 3 (Small):", deployed.testAccounts[2]);
        console.log("  Test Account 4 (New):", deployed.testAccounts[3]);
        
        return deployed;
    }

    function _configureContracts(
        DeployedContracts memory deployed, 
        DeploymentConfig memory config
    ) internal {
        console.log("Configuring contracts...");
        
        // Configure Uniswap V3 Router with realistic prices and slippage
        MockUniswapV3Router v3Router = MockUniswapV3Router(payable(deployed.uniswapV3Router));
        
        // Set token prices
        v3Router.setTokenPrice(deployed.usdc, config.usdcPrice);
        v3Router.setTokenPrice(deployed.usdt, config.usdtPrice);
        v3Router.setTokenPrice(address(0), config.ethPrice); // ETH
        v3Router.setTokenPrice(deployed.flax, config.flaxPrice);
        v3Router.setTokenPrice(deployed.crv, config.crvPrice);
        v3Router.setTokenPrice(deployed.cvx, config.cvxPrice);
        
        // Set up trading pairs with realistic slippage
        v3Router.setPair(
            deployed.usdc, deployed.usdt, 
            1e18, // 1:1 ratio
            config.initialPoolLiquidity * 2, // $200K liquidity
            10 // 0.1% base slippage
        );
        
        v3Router.setPair(
            deployed.crv, address(0),
            (config.ethPrice * 1e18) / config.crvPrice, // CRV/ETH price
            50 ether, // 50 ETH liquidity
            50 // 0.5% base slippage
        );
        
        v3Router.setPair(
            deployed.cvx, address(0),
            (config.ethPrice * 1e18) / config.cvxPrice, // CVX/ETH price
            20 ether, // 20 ETH liquidity
            30 // 0.3% base slippage
        );
        
        // Configure Curve Pool
        MockCurvePool curvePool = MockCurvePool(deployed.curvePool);
        MockCurveLP(deployed.curveLP).setPool(deployed.curvePool);
        
        // Set realistic pool balances
        uint256[] memory initialBalances = new uint256[](2);
        initialBalances[0] = config.initialPoolLiquidity; // USDC
        initialBalances[1] = config.initialPoolLiquidity; // USDT
        curvePool.set_balances(initialBalances);
        
        // Configure Convex Booster
        MockConvexBooster booster = MockConvexBooster(deployed.convexBooster);
        booster.addPool(deployed.curveLP, address(0), 0);
        
        // Configure PriceTilter with registered pair
        PriceTilterTWAP priceTilter = PriceTilterTWAP(payable(deployed.priceTilter));
        priceTilter.registerPair(deployed.flax, deployed.weth);
        
        // Set up initial Flax/ETH pair reserves for realistic pricing
        MockUniswapV2Pair flaxEthPair = MockUniswapV2Pair(deployed.flaxEthPair);
        uint256 flaxAmount = (config.initialFlaxEthLiquidity * config.ethPrice) / config.flaxPrice;
        flaxEthPair.setReserves(
            uint112(flaxAmount), // Flax reserves
            uint112(config.initialFlaxEthLiquidity), // ETH reserves
            uint32(block.timestamp)
        );
        
        // Fund router and pools with initial tokens for swaps
        _fundContractsForSwaps(deployed, config);
        
        console.log("Configuration complete");
    }

    function _fundContractsForSwaps(
        DeployedContracts memory deployed,
        DeploymentConfig memory config
    ) internal {
        // Fund Uniswap V3 Router with tokens for swaps
        MockERC20(deployed.usdc).mint(deployed.uniswapV3Router, 1_000_000 * 1e6);
        MockERC20(deployed.usdt).mint(deployed.uniswapV3Router, 1_000_000 * 1e6);
        MockERC20(deployed.crv).mint(deployed.uniswapV3Router, 10_000_000 * 1e18);
        MockERC20(deployed.cvx).mint(deployed.uniswapV3Router, 1_000_000 * 1e18);
        MockERC20(deployed.flax).mint(deployed.uniswapV3Router, 10_000_000 * 1e18);
        
        // Fund router with ETH
        vm.deal(deployed.uniswapV3Router, 1000 ether);
        
        // Fund Curve Pool with initial tokens
        MockERC20(deployed.usdc).mint(deployed.curvePool, config.initialPoolLiquidity);
        MockERC20(deployed.usdt).mint(deployed.curvePool, config.initialPoolLiquidity);
        
        // Fund Flax/ETH pair
        MockERC20(deployed.flax).mint(deployed.flaxEthPair, 1_000_000 * 1e18);
        vm.deal(deployed.flaxEthPair, 100 ether);
    }

    function _fundTestAccounts(
        DeployedContracts memory deployed,
        DeploymentConfig memory config
    ) internal {
        console.log("Funding test accounts...");
        
        uint256[4] memory fundingAmounts = [
            config.largeAccountFunding,
            config.mediumAccountFunding,
            config.smallAccountFunding,
            0 // New user starts with no tokens
        ];
        
        for (uint256 i = 0; i < 4; i++) {
            address account = deployed.testAccounts[i];
            uint256 amount = fundingAmounts[i];
            
            if (amount > 0) {
                // Fund with stablecoins
                MockERC20(deployed.usdc).mint(account, amount);
                MockERC20(deployed.usdt).mint(account, amount / 2);
                
                // Fund with some ETH
                vm.deal(account, (amount * 1e12) / config.ethPrice); // Convert USD to ETH
                
                // Fund with some reward tokens
                MockERC20(deployed.flax).mint(account, amount * 10); // 10x in Flax
                MockERC20(deployed.sFlax).mint(account, amount / 10); // Small sFlax balance
                
                console.log("  Funded account", i + 1, "with amount", amount);
            }
        }
    }

    function _logDeploymentSummary(DeployedContracts memory deployed) internal {
        console.log("");
        console.log("=== DEPLOYMENT SUMMARY ===");
        console.log("");
        console.log("Core Contracts:");
        console.log("  Vault:", deployed.vault);
        console.log("  YieldSource:", deployed.yieldSource);
        console.log("  PriceTilter:", deployed.priceTilter);
        console.log("  TWAPOracle:", deployed.twapOracle);
        console.log("");
        console.log("Tokens:");
        console.log("  USDC:", deployed.usdc);
        console.log("  USDT:", deployed.usdt);
        console.log("  WETH:", deployed.weth);
        console.log("  CRV:", deployed.crv);
        console.log("  CVX:", deployed.cvx);
        console.log("  Flax:", deployed.flax);
        console.log("  sFlax:", deployed.sFlax);
        console.log("");
        console.log("External Contracts:");
        console.log("  UniswapV3Router:", deployed.uniswapV3Router);
        console.log("  CurvePool:", deployed.curvePool);
        console.log("  ConvexBooster:", deployed.convexBooster);
        console.log("  FlaxETHPair:", deployed.flaxEthPair);
        console.log("");
        console.log("Test Accounts:");
        for (uint256 i = 0; i < 4; i++) {
            console.log("  Account", i + 1, ":", deployed.testAccounts[i]);
        }
        console.log("");
        console.log("Usage:");
        console.log("  Connect your frontend to http://localhost:8545");
        console.log("  Use the deployed contract addresses above");
        console.log("  Test accounts are pre-funded and ready to use");
        console.log("");
        
        // Save addresses to JSON file
        _saveAddresses(deployed);
    }
    
    function _saveAddresses(DeployedContracts memory deployed) internal {
        // Create JSON string manually (Solidity doesn't have JSON libraries)
        string memory json = '{\n';
        json = string(abi.encodePacked(json, '  "timestamp": "', vm.toString(block.timestamp), '",\n'));
        json = string(abi.encodePacked(json, '  "blockNumber": "', vm.toString(block.number), '",\n'));
        json = string(abi.encodePacked(json, '  "tokens": {\n'));
        json = string(abi.encodePacked(json, '    "usdc": "', vm.toString(deployed.usdc), '",\n'));
        json = string(abi.encodePacked(json, '    "usdt": "', vm.toString(deployed.usdt), '",\n'));
        json = string(abi.encodePacked(json, '    "weth": "', vm.toString(deployed.weth), '",\n'));
        json = string(abi.encodePacked(json, '    "crv": "', vm.toString(deployed.crv), '",\n'));
        json = string(abi.encodePacked(json, '    "cvx": "', vm.toString(deployed.cvx), '",\n'));
        json = string(abi.encodePacked(json, '    "flax": "', vm.toString(deployed.flax), '",\n'));
        json = string(abi.encodePacked(json, '    "sFlax": "', vm.toString(deployed.sFlax), '",\n'));
        json = string(abi.encodePacked(json, '    "curveLP": "', vm.toString(deployed.curveLP), '"\n'));
        json = string(abi.encodePacked(json, '  },\n'));
        json = string(abi.encodePacked(json, '  "externalContracts": {\n'));
        json = string(abi.encodePacked(json, '    "uniswapV3Router": "', vm.toString(deployed.uniswapV3Router), '",\n'));
        json = string(abi.encodePacked(json, '    "uniswapV2Factory": "', vm.toString(deployed.uniswapV2Factory), '",\n'));
        json = string(abi.encodePacked(json, '    "uniswapV2Router": "', vm.toString(deployed.uniswapV2Router), '",\n'));
        json = string(abi.encodePacked(json, '    "curvePool": "', vm.toString(deployed.curvePool), '",\n'));
        json = string(abi.encodePacked(json, '    "convexBooster": "', vm.toString(deployed.convexBooster), '",\n'));
        json = string(abi.encodePacked(json, '    "flaxEthPair": "', vm.toString(deployed.flaxEthPair), '"\n'));
        json = string(abi.encodePacked(json, '  },\n'));
        json = string(abi.encodePacked(json, '  "reflaxContracts": {\n'));
        json = string(abi.encodePacked(json, '    "vault": "', vm.toString(deployed.vault), '",\n'));
        json = string(abi.encodePacked(json, '    "yieldSource": "', vm.toString(deployed.yieldSource), '",\n'));
        json = string(abi.encodePacked(json, '    "priceTilter": "', vm.toString(deployed.priceTilter), '",\n'));
        json = string(abi.encodePacked(json, '    "twapOracle": "', vm.toString(deployed.twapOracle), '"\n'));
        json = string(abi.encodePacked(json, '  },\n'));
        json = string(abi.encodePacked(json, '  "testAccounts": [\n'));
        for (uint256 i = 0; i < 4; i++) {
            json = string(abi.encodePacked(json, '    "', vm.toString(deployed.testAccounts[i]), '"'));
            if (i < 3) {
                json = string(abi.encodePacked(json, ','));
            }
            json = string(abi.encodePacked(json, '\n'));
        }
        json = string(abi.encodePacked(json, '  ]\n'));
        json = string(abi.encodePacked(json, '}\n'));
        
        // Write to file
        vm.writeFile("scripts/deployedAddresses.json", json);
        console.log("Saved addresses to scripts/deployedAddresses.json");
    }
}

// Simple Vault implementation for testing
contract TestVault is Vault {
    constructor(
        address _inputToken,
        address _yieldSource,
        address _flaxToken,
        address _sFlaxToken
    ) Vault(_flaxToken, _sFlaxToken, _inputToken, _yieldSource, address(0)) {}
    
    function canWithdraw(address) external pure returns (bool) {
        return true; // Always allow withdrawals in local deployment
    }
}