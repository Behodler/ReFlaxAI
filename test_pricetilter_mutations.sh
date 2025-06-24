#!/bin/bash

# Test specific PriceTilterTWAP mutations that previously survived
echo "🧬 Testing PriceTilterTWAP Mutations"
echo "=================================="

# Survived mutations from Phase 2: 1, 2, 4, 5, 7, 8, 10, 11, 20
survived_mutations=(1 2 4 5 7 8 10 11 20)

cd /home/justin/code/BehodlerReborn/Grok/reflax

# Backup original file
cp src/priceTilting/PriceTilterTWAP.sol src/priceTilting/PriceTilterTWAP.sol.backup

echo "Testing survived mutations: ${survived_mutations[@]}"
echo ""

killed=0
survived=0

for mutant_id in "${survived_mutations[@]}"; do
    echo "Testing mutant $mutant_id..."
    
    # Copy mutant to source
    cp mutation-reports/PriceTilterTWAP/mutants/$mutant_id/src/priceTilting/PriceTilterTWAP.sol src/priceTilting/PriceTilterTWAP.sol
    
    # Run tests targeting the mutation
    if forge test --match-contract "PriceTilterTWAPTest" --no-match-contract "EmergencyRebaseIntegrationTest" >/dev/null 2>&1; then
        echo "  ❌ SURVIVED - tests passed with mutation"
        survived=$((survived + 1))
    else
        echo "  ✅ KILLED - tests failed with mutation"
        killed=$((killed + 1))
    fi
    
    # Restore original
    cp src/priceTilting/PriceTilterTWAP.sol.backup src/priceTilting/PriceTilterTWAP.sol
done

echo ""
echo "Results: $killed killed, $survived survived"
echo "Score: $((killed * 100 / 9))%"

# Cleanup
rm src/priceTilting/PriceTilterTWAP.sol.backup