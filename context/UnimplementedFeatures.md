# Unimplemented Features

## Vault.sol

### `canWithdraw()` function (Line 174-176)
- **Status**: Placeholder implementation
- **Current behavior**: Always returns `true`
- **Intended purpose**: Future governance rules (e.g., auctions, crowdfunds)
- **Location**: `src/vault/Vault.sol:174-176`

```solidity
function canWithdraw() public view returns (bool) {
    return true; // Placeholder
}
```

This is the only true unimplemented feature in the codebase. According to the documentation, this function is intended to support future governance mechanisms that could restrict withdrawals based on certain conditions like ongoing auctions or crowdfunding campaigns.