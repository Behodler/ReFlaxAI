// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title ArbitrumConstants
 * @notice Contains Arbitrum mainnet addresses for integration testing
 */
library ArbitrumConstants {
    // Core Tokens
    address public constant USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831; // Native USDC on Arbitrum
    address public constant USDT = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9; // USDT on Arbitrum
    address public constant CRV = 0x11cDb42B0EB46D95f990BeDD4695A6e3fA034978; // CRV on Arbitrum
    address public constant CVX = 0xb952A807345991BD529FDded05009F5e80Fe8F45; // CVX on Arbitrum
    address public constant WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1; // WETH on Arbitrum
    
    // Curve Pools - from old_reflax
    address public constant USDC_USDe_CRV_POOL = 0x1c34204FCFE5314Dcf53BE2671C02c35DB58B4e3; // USDC/USDe pool
    address public constant USDe_USDx_CRV_POOL = 0x096A8865367686290639bc50bF8D85C0110d9Fea; // USDe/USDx pool
    address public constant USDCUSDe_LP = 0x1c34204FCFE5314Dcf53BE2671C02c35DB58B4e3; // LP token is same as pool address for newer Curve pools
    
    // Additional tokens from old_reflax
    address public constant USDe = 0x5d3a1Ff2b6BAb83b63cd9AD0787074081a52ef34;
    address public constant USDx = 0xb2F30A7C980f052f02563fb518dcc39e6bf38175;
    
    // Convex
    address public constant CONVEX_BOOSTER = 0xF403C135812408BFbE8713b5A23a04b3D48AAE31;
    address public constant CONVEX_POOL = 0xe062e302091f44d7483d9D6e0Da9881a0817E2be; // From old_reflax
    uint256 public constant CONVEX_POOL_ID = 34; // From old_reflax
    address public constant USDC_USDe_REWARDS = 0xe062e302091f44d7483d9D6e0Da9881a0817E2be; // Using CONVEX_POOL as rewards address
    uint256 public constant USDC_USDe_CONVEX_PID = 34; // Using CONVEX_POOL_ID
    
    // Uniswap V3
    address public constant UNISWAP_V3_ROUTER = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
    address public constant UNISWAP_V3_QUOTER_V2 = 0x61fFE014bA17989E743c5F6cB21bF9697530B21e;
    
    // Uniswap V2 (from old_reflax)
    address public constant UNISWAP_V2_ROUTER = 0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24;
    address public constant UNISWAP_V2_FACTORY = 0xf1D7CC64Fb4452F05c498126312eBE29f30Fbcf9; // Camelot Factory on Arbitrum
    address public constant SUSHI_V2_ROUTER = 0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506; // From old_reflax
    
    // Whale addresses (from old_reflax)
    address public constant USDC_WHALE = 0x2Df1c51E09aECF9cacB7bc98cB1742757f163dF7;
    address public constant USDe_WHALE = 0xA4ffe78ba40B7Ec0C348fFE36a8dE4F9d6198d2d;
    
    // Additional reference addresses from old_reflax
    address public constant USDC_ETH_UNISWAP_V2_PAIR = 0xF64Dfe17C8b87F012FCf50FbDA1D62bfA148366a;
}