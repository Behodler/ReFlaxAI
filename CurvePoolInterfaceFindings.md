# Curve USDC/USDe Pool Interface Investigation

## Pool Details
- **Address**: `0x1c34204FCFE5314Dcf53BE2671C02c35DB58B4e3` (Arbitrum)
- **Type**: USDC/USDe 2-token pool
- **Implementation**: StableSwapNG (newer Curve implementation)

## Issue Identified
The `calc_token_amount` function is reverting because the pool uses the newer StableSwapNG interface which expects **dynamic arrays** (`uint256[]`) instead of fixed-size arrays (`uint256[2]` or `uint256[4]`).

## Test Results

### Function Interface Compatibility
- ❌ `calc_token_amount(uint256[2], bool)` - **FAILED**
- ❌ `calc_token_amount(uint256[4], bool)` - **FAILED**  
- ✅ `calc_token_amount(uint256[], bool)` - **SUCCESS**

### Other Functions (Working)
- ✅ `get_dy(int128, int128, uint256)` - Exchange rate calculation
- ✅ `get_virtual_price()` - Returns `1010482058704836767` (≈1.01)
- ✅ `fee()` - Returns `4000000` (4% fee in basis points * 1e4)
- ✅ `calc_withdraw_one_coin(uint256, int128)` - Withdrawal calculation
- ✅ `N_COINS()` - Returns `2` (confirming 2-token pool)

### Example Usage
```solidity
// For 1000 USDC deposit (single-sided)
uint256[] memory amounts = new uint256[](2);
amounts[0] = 1000e6; // USDC
amounts[1] = 0;      // USDe
uint256 expectedLP = ICurvePoolNG(pool).calc_token_amount(amounts, true);
```

## Solutions

### 1. Use Dynamic Array Interface
Update your code to use `ICurvePoolNG` interface with dynamic arrays instead of fixed-size arrays.

### 2. Updated Interface Added
A new `ICurvePoolNG` interface has been added to `/src/external/Curve.sol` that includes:
- `calc_token_amount(uint256[], bool)` - Dynamic array version
- `add_liquidity(uint256[], uint256)` - Dynamic array version
- All other StableSwapNG functions

### 3. Implementation Update Required
Update your CVX_CRV_YieldSource or any other code that calls `calc_token_amount` to:
1. Use `ICurvePoolNG` interface for this pool
2. Create dynamic arrays instead of fixed-size arrays
3. Handle the N_COINS getter to determine pool size dynamically

## Pool Characteristics
- **Pool Balance Ratio**: Relatively balanced between USDC and USDe
- **Virtual Price**: ~1.01 (slightly above peg, indicating positive yield)
- **Fee**: 4% (0.04%)
- **Exchange Rate**: 1000 USDC ≈ 997.116 USDe (including fees and slippage)

## Recommendations
1. **Immediate Fix**: Use the new `ICurvePoolNG` interface for the USDC/USDe pool
2. **Future Proofing**: Implement pool type detection to automatically choose the correct interface
3. **Testing**: Update integration tests to use the correct interface
4. **Documentation**: Update any documentation referencing fixed-size array interfaces for newer pools

## Code Example
```solidity
// Instead of this (will fail):
uint256[2] memory amounts = [uint256(1000e6), uint256(0)];
ICurvePool(pool).calc_token_amount(amounts, true);

// Use this (will work):
uint256[] memory amounts = new uint256[](2);
amounts[0] = 1000e6;
amounts[1] = 0;
ICurvePoolNG(pool).calc_token_amount(amounts, true);
```

This change will resolve the `calc_token_amount` revert issue you were experiencing.