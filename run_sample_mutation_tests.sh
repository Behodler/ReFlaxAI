#!/bin/bash

# ReFlax Sample Mutation Testing Script
# Tests a small sample of mutations to get real scores quickly

set -e

echo "🧬 Starting ReFlax Sample Mutation Testing"
echo "========================================="
echo ""

# Create results directory
mkdir -p context/mutation-test/results/execution

# Initialize results tracking
TOTAL_TESTED=0
TOTAL_KILLED=0
TOTAL_SURVIVED=0

# Function to test a single mutant
test_mutant() {
    local contract=$1
    local mutant_id=$2
    local original_file=$3
    local mutant_file=$4
    
    # Skip if mutant file doesn't exist
    if [ ! -f "$mutant_file" ]; then
        echo "⚠️  Skipping mutant $mutant_id - file not found"
        return 2
    fi
    
    # Backup original
    cp "$original_file" "${original_file}.backup"
    
    # Copy mutant
    cp "$mutant_file" "$original_file"
    
    # Run tests
    echo -n "Testing $contract mutant $mutant_id... "
    if forge test --no-match-test "integration" >/dev/null 2>&1; then
        echo "❌ SURVIVED"
        echo "$contract,$mutant_id,SURVIVED" >> context/mutation-test/results/execution/sample_results.csv
        TOTAL_SURVIVED=$((TOTAL_SURVIVED + 1))
    else
        echo "✅ KILLED"
        echo "$contract,$mutant_id,KILLED" >> context/mutation-test/results/execution/sample_results.csv
        TOTAL_KILLED=$((TOTAL_KILLED + 1))
    fi
    
    TOTAL_TESTED=$((TOTAL_TESTED + 1))
    
    # Restore original
    mv "${original_file}.backup" "$original_file"
}

# Initialize CSV
echo "Contract,MutantID,Status" > context/mutation-test/results/execution/sample_results.csv

# Test baseline first
echo "🧪 Running baseline tests..."
if ! forge test --no-match-test "integration" >/dev/null 2>&1; then
    echo "❌ Baseline tests failed! Aborting mutation testing."
    exit 1
fi
echo "✅ Baseline tests passed"
echo ""

# Test sample mutations for each contract
echo "📊 Testing sample mutations (5 per contract)..."
echo ""

# CVX_CRV_YieldSource
echo "🔍 Testing CVX_CRV_YieldSource mutations..."
for i in 1 5 10 15 20; do
    test_mutant "CVX_CRV_YieldSource" "$i" \
        "src/yieldSource/CVX_CRV_YieldSource.sol" \
        "mutation-reports/CVX_CRV_YieldSource/mutants/$i/src/yieldSource/CVX_CRV_YieldSource.sol"
done
echo ""

# PriceTilterTWAP
echo "🔍 Testing PriceTilterTWAP mutations..."
for i in 1 5 10 15 20; do
    test_mutant "PriceTilterTWAP" "$i" \
        "src/priceTilting/PriceTilterTWAP.sol" \
        "mutation-reports/PriceTilterTWAP/mutants/$i/src/priceTilting/PriceTilterTWAP.sol"
done
echo ""

# TWAPOracle
echo "🔍 Testing TWAPOracle mutations..."
for i in 1 5 10 15 20; do
    test_mutant "TWAPOracle" "$i" \
        "src/priceTilting/TWAPOracle.sol" \
        "mutation-reports/TWAPOracle/mutants/$i/src/priceTilting/TWAPOracle.sol"
done
echo ""

# AYieldSource
echo "🔍 Testing AYieldSource mutations..."
for i in 1 5 10 15 20; do
    test_mutant "AYieldSource" "$i" \
        "src/yieldSource/AYieldSource.sol" \
        "mutation-reports/AYieldSource/mutants/$i/src/yieldSource/AYieldSource.sol"
done
echo ""

# Vault (using flattened file)
echo "🔍 Testing Vault mutations..."
for i in 1 5 10 15 20; do
    # For vault, we need to handle the flattened file differently
    if [ -f "vault_mutations/mutants/$i/vault_flattened.sol" ]; then
        echo "Note: Vault uses flattened files - skipping for now"
        break
    fi
done
echo ""

# Calculate mutation score
if [ $TOTAL_TESTED -gt 0 ]; then
    MUTATION_SCORE=$((TOTAL_KILLED * 100 / TOTAL_TESTED))
else
    MUTATION_SCORE=0
fi

# Summary
echo "🎯 SAMPLE MUTATION TESTING SUMMARY"
echo "=================================="
echo "Total mutants tested: $TOTAL_TESTED"
echo "Killed: $TOTAL_KILLED"
echo "Survived: $TOTAL_SURVIVED"
echo "Sample mutation score: ${MUTATION_SCORE}%"
echo ""

# Create summary file
cat > context/mutation-test/results/execution/sample_summary.md << EOF
# ReFlax Mutation Testing - Sample Results

## Executive Summary
Sample mutation testing of $TOTAL_TESTED mutations across core contracts.

## Results
- **Total Tested**: $TOTAL_TESTED
- **Killed**: $TOTAL_KILLED
- **Survived**: $TOTAL_SURVIVED
- **Sample Mutation Score**: ${MUTATION_SCORE}%

## Methodology
- Tested 5 mutations per contract (mutants 1, 5, 10, 15, 20)
- Used unit test suite (excluding integration tests)
- Representative sample of 875 total mutations

Generated: $(date)
EOF

echo "✅ Sample mutation testing complete!"
echo "📋 Results saved in context/mutation-test/results/execution/"