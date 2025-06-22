# Name Of Rule
depositIncreasesEffectiveBalance

## Rule Violation details
User original deposits should increase - certora/specs/Vault.spec line 164

## Analysis Summary

### Local verification results:
- Fixed ERC20 method havoc issues by adding transferFrom, transfer, approve to methods block
- Still failing with message "User original deposits should increase"
- The invariant rebaseMultiplierValid is being violated by YieldSource functions
- Need to constrain the invariant to only apply to Vault contract

### Key findings:
1. External protocol calls (Oracle, Uniswap, Convex) are being havoc'd as expected
2. The depositIncreasesEffectiveBalance rule is now failing on a different assertion
3. The rebaseMultiplierValid invariant needs to be scoped to Vault only
Caller
In  
CALL TRACE

CVX_CRV_YieldSource.deposit(uint256)
Call Site

CVX_CRV_YieldSource.sol : Line 206
                    
oracle.update(address(inputToken), address(0))

                
Callee

[?].[?]
Summary

AUTO havoc
Comments

callee resolution
both callee contract and sighash are unresolved
havoc cause
The Prover could not resolve the callee, thus, havoc'd the call
havoc scope
a havoc that havocs all contracts except CVX_CRV_YieldSource (ce4604a000000000000000000000001a)
summary application reason
chosen automatically by the Prover
Caller

CVX_CRV_YieldSource.deposit(uint256)
Call Site

CVX_CRV_YieldSource.sol : Line 212
                    
oracle.update(address(poolTokens[i]), address(0))

                
Callee

[?].[?]
Summary

AUTO havoc
Comments

callee resolution
both callee contract and sighash are unresolved
havoc cause
The Prover could not resolve the callee, thus, havoc'd the call
havoc scope
a havoc that havocs all contracts except CVX_CRV_YieldSource (ce4604a000000000000000000000001a)
summary application reason
chosen automatically by the Prover
Caller

CVX_CRV_YieldSource.deposit(uint256)
Call Site

CVX_CRV_YieldSource.sol : Line 219
                    
oracle.update(rewardTokens[i], address(0))

                
Callee

[?].[?]
Summary

AUTO havoc
Comments

callee resolution
both callee contract and sighash are unresolved
havoc cause
The Prover could not resolve the callee, thus, havoc'd the call
havoc scope
a havoc that havocs all contracts except CVX_CRV_YieldSource (ce4604a000000000000000000000001a)
summary application reason
chosen automatically by the Prover
Caller
In  
CALL TRACE

CVX_CRV_YieldSource.deposit(uint256)
Call Site

SafeERC20.sol : Line 50
                    
assembly ("memory-safe") {let success := call(gas(), token, 0, add(data, 0x20), mload(data), 0, 0x20)// bubble errorsif iszero(success) {let ptr := mload(0x40)returndatacopy(ptr, 0, returndatasize())revert(ptr, returndatasize())}returnSize := returndatasize()returnValue := mload(0)}

                
Callee

[?].[?]
Summary

AUTO havoc
Comments

callee resolution
both callee contract and sighash are unresolved
havoc cause
The Prover could not resolve the callee, thus, havoc'd the call
havoc scope
a havoc that havocs all contracts except CVX_CRV_YieldSource (ce4604a000000000000000000000001a)
summary application reason
chosen automatically by the Prover
Caller
In  
CALL TRACE

CVX_CRV_YieldSource.deposit(uint256)
Call Site

CVX_CRV_YieldSource.sol : Line 253
                    
oracle.consult(address(inputToken), address(poolTokens[i]), allocatedAmount)

                
Callee

[?].[?]
Summary

AUTO havoc
Comments

callee resolution
both callee contract and sighash are unresolved
havoc cause
The Prover could not resolve the callee, thus, havoc'd the call
havoc scope
a havoc that only havocs the return value
summary application reason
chosen automatically by the Prover
Caller
In  
CALL TRACE

CVX_CRV_YieldSource.deposit(uint256)
Call Site

CVX_CRV_YieldSource.sol : Line 255
                    
IUniswapV3Router(uniswapV3Router).exactInputSingle(IUniswapV3Router.ExactInputSingleParams({tokenIn: address(inputToken),tokenOut: address(poolTokens[i]),fee: UNISWAP_FEE,recipient: address(this),amountIn: allocatedAmount,amountOutMinimum: minOut,sqrtPriceLimitX96: 0}))

                
Callee

[?].[?]
Summary

AUTO havoc
Comments

callee resolution
both callee contract and sighash are unresolved
havoc cause
The Prover could not resolve the callee, thus, havoc'd the call
havoc scope
a havoc that havocs all contracts except CVX_CRV_YieldSource (ce4604a000000000000000000000001a)
summary application reason
chosen automatically by the Prover
Caller
In  
CALL TRACE

CVX_CRV_YieldSource.deposit(uint256)
Call Site

CVX_CRV_YieldSource.sol : Line 504
                    
curvePool.call(data)

                
Callee

[?].[?]
Summary

AUTO havoc
Comments

callee resolution
both callee contract and sighash are unresolved
havoc cause
The Prover could not resolve the callee, thus, havoc'd the call
havoc scope
a havoc that havocs all contracts except CVX_CRV_YieldSource (ce4604a000000000000000000000001a)
summary application reason
chosen automatically by the Prover
Caller
In  
CALL TRACE

CVX_CRV_YieldSource.deposit(uint256)
Call Site

CVX_CRV_YieldSource.sol : Line 276
                    
IConvexBooster(convexBooster).deposit(poolId, lpAmount, true)

                
Callee

[?].[?]
Summary

AUTO havoc
Comments

callee resolution
both callee contract and sighash are unresolved
havoc cause
The Prover could not resolve the callee, thus, havoc'd the call
havoc scope
a havoc that havocs all contracts except CVX_CRV_YieldSource (ce4604a000000000000000000000001a)
summary application reason
chosen automatically by the Prover
Caller
In  
CALL TRACE

Vault.deposit(uint256)
Call Site

SafeERC20.sol : Line 50
                    
assembly ("memory-safe") {let success := call(gas(), token, 0, add(data, 0x20), mload(data), 0, 0x20)// bubble errorsif iszero(success) {let ptr := mload(0x40)returndatacopy(ptr, 0, returndatasize())revert(ptr, returndatasize())}returnSize := returndatasize()returnValue := mload(0)}

                
Callee

[?].transferFrom(address, address, uint256)
Summary

DISPATCHER(optimistic = true)
Comments

callee resolution
callee contract unresolved; callee sighash resolved
resolved callees
[MockERC20.transferFrom(address,address,uint256)]
summary application reason
declared at Vault.spec:30:68; applied to calls where no callee could be resolved
Caller
In  
CALL TRACE

Vault.deposit(uint256)
Call Site

Vault.sol : Line 232
                    
inputToken.approve(yieldSource, amount)

                
Callee

[?].approve(address, uint256)
Summary

DISPATCHER(optimistic = true)
Comments

callee resolution
callee contract unresolved; callee sighash resolved
resolved callees
[MockERC20.approve(address,uint256)]
summary application reason
declared at Vault.spec:32:54; applied to calls where no callee could be resolved
Caller
In  
CALL TRACE

Vault.deposit(uint256)
Call Site

Vault.sol : Line 233
                    
IYieldsSource(yieldSource).deposit(amount)

                
Callee

[?].deposit(uint256)
Summary

DISPATCHER(optimistic = true)
Comments

callee resolution
callee contract unresolved; callee sighash resolved
callee resolution hint (1)
To resolve the call, try '--link Vault:yieldSource=[CVX_CRV_YieldSource | Vault]'
resolved callees
[CVX_CRV_YieldSource.deposit(uint256) | Vault.deposit(uint256)]
summary application reason
declared at Vault.spec:35:45; applied to calls where no callee could be resolved


