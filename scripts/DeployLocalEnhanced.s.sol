// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console.sol";
// Import core contracts directly
import "../src/vault/Vault.sol";
import "../test/mocks/LocalDeployment/MockTokens.sol";

/**
 * @title Enhanced Local Deployment Script with SFlax Integration Support
 * @notice Extends the base deployment to include all missing SFlax integration components
 * @dev Addresses the gaps identified in reflax-ui story 020 where 52% of UI tests fail
 */
contract EnhancedLocalDeploymentScript is Script {

    struct EnhancedConfig {
        // Enhanced boost configuration
        uint256 maxBoostPercentage;     // Maximum boost in basis points (5000 = 50%)
        uint256 boostRatePerSFlax;      // Boost per sFlax token in basis points (100 = 1%)
        uint256 initialFlaxPerSFlax;    // Initial exchange rate (1.1e18 = 1.1 Flax per sFlax)
        
        // Test configuration
        uint256 testSFlaxAmount;        // sFlax balance for testing
        uint256 testRewardsAmount;      // Initial rewards for testing
        bool enableRewardAccrual;       // Whether to set up reward accrual
    }

    struct ValidationResults {
        bool boostCalculationWorking;
        bool flaxPerSFlaxConfigured;
        bool vaultApprovedBurner;
        bool testAccountsSetup;
        bool addressServerUpdated;
    }

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        console.log("=== Starting Enhanced ReFlax Deployment with SFlax Integration ===");
        console.log("Deployer:", vm.addr(deployerPrivateKey));
        console.log("Network:", block.chainid);
        
        // Check if base deployment exists, if not create it first
        if (!_baseDeploymentExists()) {
            console.log("Base deployment not found, running base deployment first...");
            _runBaseDeployment();
        } else {
            console.log("Base deployment found, enhancing existing deployment...");
        }
        
        // Load the deployed contracts and enhance the deployment
        DeployedContracts memory contracts = _loadDeployedContracts();
        EnhancedConfig memory config = _getEnhancedConfig();
        
        _enhanceSFlaxIntegration(contracts, config);
        _setupTestAccountsWithDeposits(contracts, config);
        _configureRewardAccrual(contracts, config);
        _validateEnhancedDeployment(contracts, config);
        _updateAddressServer(contracts);
        _logEnhancedDeploymentSummary(contracts, config);

        vm.stopBroadcast();
        console.log("=== Enhanced ReFlax Deployment Complete ===");
    }

    function _baseDeploymentExists() internal view returns (bool) {
        try vm.readFile("scripts/deployedAddresses.json") returns (string memory) {
            return true;
        } catch {
            return false;
        }
    }

    function _runBaseDeployment() internal {
        console.log("This enhanced script assumes the base deployment has been run first.");
        console.log("Please run: forge script scripts/DeployLocal.s.sol:LocalDeploymentScript --rpc-url http://localhost:8545 --broadcast");
        revert("Base deployment required first");
    }

    function _getEnhancedConfig() internal pure returns (EnhancedConfig memory) {
        return EnhancedConfig({
            maxBoostPercentage: 5000,        // 50% max boost
            boostRatePerSFlax: 100,          // 1% per sFlax token 
            initialFlaxPerSFlax: 11 * 1e17,  // 1.1 Flax per sFlax (not fallback 1)
            testSFlaxAmount: 100 * 1e18,     // 100 sFlax for testing
            testRewardsAmount: 1000 * 1e18,  // 1000 Flax rewards for testing
            enableRewardAccrual: true
        });
    }

    function _loadDeployedContracts() internal view returns (DeployedContracts memory contracts) {
        // Read deployed addresses from JSON file
        string memory json = vm.readFile("scripts/deployedAddresses.json");
        
        // Parse core contract addresses
        contracts.vault = vm.parseJsonAddress(json, ".reflaxContracts.vault");
        contracts.yieldSource = vm.parseJsonAddress(json, ".reflaxContracts.yieldSource");
        contracts.priceTilter = vm.parseJsonAddress(json, ".reflaxContracts.priceTilter");
        contracts.twapOracle = vm.parseJsonAddress(json, ".reflaxContracts.twapOracle");
        
        // Parse token addresses
        contracts.usdc = vm.parseJsonAddress(json, ".tokens.usdc");
        contracts.flax = vm.parseJsonAddress(json, ".tokens.flax");
        contracts.sFlax = vm.parseJsonAddress(json, ".tokens.sFlax");
        
        // Parse test accounts
        contracts.testAccounts[0] = vm.parseJsonAddress(json, ".testAccounts[0]");
        contracts.testAccounts[1] = vm.parseJsonAddress(json, ".testAccounts[1]");
        contracts.testAccounts[2] = vm.parseJsonAddress(json, ".testAccounts[2]");
        contracts.testAccounts[3] = vm.parseJsonAddress(json, ".testAccounts[3]");
        
        return contracts;
    }

    function _enhanceSFlaxIntegration(
        DeployedContracts memory contracts, 
        EnhancedConfig memory config
    ) internal {
        console.log("Enhancing sFlax integration...");
        
        // Configure vault with proper boost parameters
        Vault vault = Vault(payable(contracts.vault));
        
        // Set boost parameters
        vault.setBoostParameters(config.maxBoostPercentage, config.boostRatePerSFlax);
        console.log("  Set boost parameters: max =", config.maxBoostPercentage, "rate =", config.boostRatePerSFlax);
        
        // Configure proper flaxPerSFlax exchange rate (not fallback 1)
        vault.setFlaxPerSFlax(config.initialFlaxPerSFlax);
        console.log("  Set flaxPerSFlax rate:", config.initialFlaxPerSFlax);
        
        // Configure sFlax burner permissions
        MockSFlax sFlax = MockSFlax(contracts.sFlax);
        sFlax.setApprovedBurner(contracts.vault, true);
        console.log("  Approved vault as sFlax burner");
        
        // Verify vault is properly configured
        require(vault.getMaxBoostPercentage() == config.maxBoostPercentage, "Max boost not set");
        require(vault.flaxPerSFlax() == config.initialFlaxPerSFlax, "FlaxPerSFlax not set");
        require(sFlax.approvedBurners(contracts.vault), "Vault not approved as burner");
        
        console.log("sFlax integration enhancement complete");
    }

    function _setupTestAccountsWithDeposits(
        DeployedContracts memory contracts,
        EnhancedConfig memory config
    ) internal {
        console.log("Setting up test accounts with vault deposits...");
        
        Vault vault = Vault(payable(contracts.vault));
        MockERC20 usdc = MockERC20(contracts.usdc);
        MockSFlax sFlax = MockSFlax(contracts.sFlax);
        
        uint256[4] memory depositAmounts = [
            10000 * 1e6,  // Large depositor: $10K
            1000 * 1e6,   // Medium depositor: $1K  
            100 * 1e6,    // Small depositor: $100
            0             // New user: no deposit initially
        ];
        
        for (uint256 i = 0; i < 3; i++) { // Skip the new user (index 3)
            address account = contracts.testAccounts[i];
            uint256 depositAmount = depositAmounts[i];
            
            if (depositAmount > 0) {
                // Fund account and make deposit
                vm.startPrank(account);
                
                // Approve and deposit into vault
                usdc.approve(address(vault), depositAmount);
                vault.deposit(depositAmount);
                
                // Give account sFlax for boost testing
                vm.stopPrank();
                sFlax.mint(account, config.testSFlaxAmount);
                
                console.log("  Account", i + 1, "deposited:", depositAmount, "USDC, received:", config.testSFlaxAmount, "sFlax");
            }
        }
        
        console.log("Test account setup complete");
    }

    function _configureRewardAccrual(
        DeployedContracts memory contracts,
        EnhancedConfig memory config
    ) internal {
        if (!config.enableRewardAccrual) return;
        
        console.log("Configuring reward accrual for testing...");
        
        // Fund the vault with Flax tokens for reward distribution
        MockERC20 flax = MockERC20(contracts.flax);
        flax.mint(contracts.vault, config.testRewardsAmount);
        
        console.log("  Funded vault with", config.testRewardsAmount, "Flax for rewards");
        console.log("Reward accrual configuration complete");
    }

    function _validateEnhancedDeployment(
        DeployedContracts memory contracts,
        EnhancedConfig memory config
    ) internal view {
        console.log("Validating enhanced deployment...");
        
        ValidationResults memory results;
        Vault vault = Vault(payable(contracts.vault));
        MockSFlax sFlax = MockSFlax(contracts.sFlax);
        
        // Validate boost calculations
        uint256 testSFlaxAmount = 10 * 1e18; // 10 sFlax
        uint256 boostPercentage = vault.calculateBoostPercentage(testSFlaxAmount);
        results.boostCalculationWorking = boostPercentage > 0 && boostPercentage <= config.maxBoostPercentage;
        
        // Validate flaxPerSFlax is not fallback 1
        results.flaxPerSFlaxConfigured = vault.flaxPerSFlax() != 1e18 && vault.flaxPerSFlax() == config.initialFlaxPerSFlax;
        
        // Validate vault is approved burner
        results.vaultApprovedBurner = sFlax.approvedBurners(contracts.vault);
        
        // Validate test accounts have deposits
        results.testAccountsSetup = vault.getEffectiveDeposit(contracts.testAccounts[0]) > 0;
        
        // Log validation results
        console.log("Validation Results:");
        console.log("  Boost Calculation Working:", results.boostCalculationWorking);
        console.log("  FlaxPerSFlax Configured:", results.flaxPerSFlaxConfigured);
        console.log("  Vault Approved as Burner:", results.vaultApprovedBurner);
        console.log("  Test Accounts Setup:", results.testAccountsSetup);
        
        require(results.boostCalculationWorking, "Boost calculation failed");
        require(results.flaxPerSFlaxConfigured, "FlaxPerSFlax not properly configured");
        require(results.vaultApprovedBurner, "Vault not approved as burner");
        require(results.testAccountsSetup, "Test accounts not properly setup");
        
        console.log("All validations passed!");
    }

    function _updateAddressServer(DeployedContracts memory contracts) internal {
        console.log("Address server will be updated when deployment script saves addresses");
        // The address server automatically serves the deployedAddresses.json file
        // No additional contracts were deployed, so existing addresses remain valid
    }

    function _logEnhancedDeploymentSummary(
        DeployedContracts memory contracts,
        EnhancedConfig memory config
    ) internal view {
        console.log("");
        console.log("=== ENHANCED DEPLOYMENT SUMMARY ===");
        console.log("");
        console.log("Enhanced Features Added:");
        console.log("  Max Boost Percentage:", config.maxBoostPercentage, "bps");
        console.log("  Boost Rate Per sFlax:", config.boostRatePerSFlax, "bps");
        console.log("  Initial FlaxPerSFlax:", config.initialFlaxPerSFlax);
        console.log("");
        
        Vault vault = Vault(payable(contracts.vault));
        
        console.log("Boost Calculation Examples:");
        console.log("  1 sFlax burn gives:", vault.calculateBoostPercentage(1e18), "bps boost");
        console.log("  10 sFlax burn gives:", vault.calculateBoostPercentage(10e18), "bps boost");
        console.log("  100 sFlax burn gives:", vault.calculateBoostPercentage(100e18), "bps boost");
        console.log("");
        
        console.log("Test Account Deposits:");
        for (uint256 i = 0; i < 3; i++) {
            uint256 deposit = vault.getEffectiveDeposit(contracts.testAccounts[i]);
            if (deposit > 0) {
                console.log("  Account", i + 1, "deposit:", deposit, "USDC");
            }
        }
        console.log("");
        
        console.log("Integration Status:");
        console.log("  All Priority 1 critical items: DEPLOYED");
        console.log("  Boost calculations: FUNCTIONAL");
        console.log("  flaxPerSFlax rate: CONFIGURED (not fallback)");  
        console.log("  sFlax burner permissions: SET");
        console.log("  Test data: READY");
        console.log("");
        console.log("Ready for UI integration testing!");
    }

    // Import the DeployedContracts struct from the base script
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
}