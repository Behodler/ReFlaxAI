# Compilation Speed Optimization Strategies for ReFlax

## Current Bottlenecks

### 1. **viaIR Optimization (Primary Bottleneck)**
- Currently enabled in `foundry.toml` with `viaIR = true`
- This uses Solidity's Yul intermediate representation optimizer
- Can increase compilation time by 3-10x compared to legacy optimizer
- Produces more gas-efficient bytecode but at significant compile-time cost

### 2. **OpenZeppelin Library Size**
- Full OpenZeppelin library contains 290 Solidity files
- Your project only uses 4 contracts: IERC20, SafeERC20, Ownable, ReentrancyGuard
- Compiler still needs to process entire dependency tree

### 3. **Optimizer Settings**
- Current optimizer runs set to 200
- Each optimization run adds compilation time

## Recommended Solutions (in order of impact)

### 1. **Create Development Profile** ⚡ High Impact
Add to `foundry.toml`:
```toml
[profile.dev]
viaIR = false
optimizer = true
optimizer_runs = 200

[profile.production]
viaIR = true
optimizer = true
optimizer_runs = 1000
```

**Usage:**
- Development: `forge build --profile dev` (50-80% faster)
- Production: `forge build --profile production`

### 2. **Minimize OpenZeppelin Dependencies** ⚡ Medium Impact
Create a minimal OpenZeppelin directory:
```
lib/openzeppelin-minimal/
├── IERC20.sol
├── IERC1363.sol
├── SafeERC20.sol
├── Ownable.sol
├── Context.sol
└── ReentrancyGuard.sol
```

Update remappings to use minimal version for development.

### 3. **Use Forge Cache Effectively** ⚡ Medium Impact
```bash
# Only rebuild changed files
forge build

# Clear cache if corrupted
forge clean && forge build

# Use watch mode for development
forge build --watch
```

### 4. **Parallel Compilation**
```bash
# Check if using all available cores
forge build --jobs $(nproc)
```

### 5. **Selective Test Compilation** ⚡ Quick Win
```bash
# Skip test compilation when working on src
forge build --skip test

# Skip script compilation
forge build --skip script
```

### 6. **Consider Foundry Compilation Cache**
Enable aggressive caching:
```toml
[profile.default]
cache = true
cache_path = "cache"
```

### 7. **Hardware Optimization**
- Use SSD for project directory
- Ensure sufficient RAM (8GB+ recommended)
- Close other heavy applications during compilation

## Quick Implementation Guide

### Step 1: Immediate Fix (2 minutes)
Add development profile to `foundry.toml`:
```toml
[profile.dev]
viaIR = false
```

Then use: `forge build --profile dev`

### Step 2: Medium-term Fix (30 minutes)
1. Create minimal OpenZeppelin directory
2. Copy only required contracts
3. Update remappings for development

### Step 3: Workflow Optimization
1. Use `--skip test` during source development
2. Use `--watch` mode for automatic rebuilds
3. Only use production profile for final deployment

## Expected Results

- **Development builds**: 70-80% faster with viaIR disabled
- **Test iterations**: 30-40% faster with selective compilation
- **Overall workflow**: 2-5x improvement in development speed

## Trade-offs

- **viaIR disabled**: Slightly larger bytecode, less gas optimization
- **Minimal dependencies**: Need to maintain separate OpenZeppelin copy
- **Lower optimizer runs**: Less gas-efficient code (only for dev)

## Recommendation Priority

1. **Disable viaIR for development** - Biggest immediate impact
2. **Use selective compilation flags** - Quick wins
3. **Minimize dependencies** - If still too slow after #1
4. **Hardware/cache optimization** - Final resort