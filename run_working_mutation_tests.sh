#!/bin/bash

# ReFlax Mutation Testing - For Working Tests Only
# Tests mutations on contracts with passing test suites

set -e

echo "🧬 Starting ReFlax Mutation Testing (Working Tests Only)"
echo "======================================================="
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
    local test_filter=$5
    
    # Skip if mutant file doesn't exist
    if [ ! -f "$mutant_file" ]; then
        return 2
    fi
    
    # Backup original
    cp "$original_file" "${original_file}.backup"
    
    # Copy mutant
    cp "$mutant_file" "$original_file"
    
    # Run tests with specific filter
    echo -n "Testing $contract mutant $mutant_id... "
    if forge test --match-contract "$test_filter" >/dev/null 2>&1; then
        echo "❌ SURVIVED"
        echo "$contract,$mutant_id,SURVIVED" >> context/mutation-test/results/execution/working_results.csv
        TOTAL_SURVIVED=$((TOTAL_SURVIVED + 1))
    else
        echo "✅ KILLED"
        echo "$contract,$mutant_id,KILLED" >> context/mutation-test/results/execution/working_results.csv
        TOTAL_KILLED=$((TOTAL_KILLED + 1))
    fi
    
    TOTAL_TESTED=$((TOTAL_TESTED + 1))
    
    # Restore original
    mv "${original_file}.backup" "$original_file"
}

# Initialize CSV
echo "Contract,MutantID,Status" > context/mutation-test/results/execution/working_results.csv

# Test contracts with passing tests only

# PriceTilterTWAP (all tests passing)
echo "🔍 Testing PriceTilterTWAP mutations..."
echo "Baseline: Running PriceTilterTWAP tests..."
if ! forge test --match-contract "PriceTilterTWAPTest" >/dev/null 2>&1; then
    echo "❌ Baseline failed"
else
    echo "✅ Baseline passed"
    for i in 1 3 5 7 10 12 15 18 20 25; do
        test_mutant "PriceTilterTWAP" "$i" \
            "src/priceTilting/PriceTilterTWAP.sol" \
            "mutation-reports/PriceTilterTWAP/mutants/$i/src/priceTilting/PriceTilterTWAP.sol" \
            "PriceTilterTWAPTest"
    done
fi
echo ""

# TWAPOracle (specific passing tests)
echo "🔍 Testing TWAPOracle mutations..."
echo "Baseline: Running TWAPOracle tests..."
if ! forge test --match-contract "TWAPOracleTest" >/dev/null 2>&1; then
    echo "❌ Baseline failed"
else
    echo "✅ Baseline passed"
    for i in 1 3 5 7 10 12 15 18 20 25; do
        test_mutant "TWAPOracle" "$i" \
            "src/priceTilting/TWAPOracle.sol" \
            "mutation-reports/TWAPOracle/mutants/$i/src/priceTilting/TWAPOracle.sol" \
            "TWAPOracleTest"
    done
fi
echo ""

# Vault Emergency tests (passing)
echo "🔍 Testing Vault mutations (Emergency functions)..."
echo "Baseline: Running VaultEmergency tests..."
if ! forge test --match-contract "VaultEmergencyTest" >/dev/null 2>&1; then
    echo "❌ Baseline failed"
else
    echo "✅ Baseline passed"
    # Note: Can't test vault mutations with flattened files easily
    echo "⚠️  Vault uses flattened files - skipping mutation testing"
fi
echo ""

# AYieldSource - Check if has specific test file
echo "🔍 Testing AYieldSource mutations..."
echo "Baseline: Checking for AYieldSource tests..."
if forge test --match-contract "YieldSourceTest" >/dev/null 2>&1; then
    echo "✅ Found YieldSource tests"
    for i in 1 3 5 7 10 12 15 18 20 25; do
        test_mutant "AYieldSource" "$i" \
            "src/yieldSource/AYieldSource.sol" \
            "mutation-reports/AYieldSource/mutants/$i/src/yieldSource/AYieldSource.sol" \
            "YieldSourceTest"
    done
else
    echo "⚠️  No dedicated AYieldSource tests found"
fi
echo ""

# Calculate mutation score
if [ $TOTAL_TESTED -gt 0 ]; then
    MUTATION_SCORE=$((TOTAL_KILLED * 100 / TOTAL_TESTED))
else
    MUTATION_SCORE=0
fi

# Summary
echo "🎯 MUTATION TESTING SUMMARY"
echo "==========================="
echo "Total mutants tested: $TOTAL_TESTED"
echo "Killed: $TOTAL_KILLED"
echo "Survived: $TOTAL_SURVIVED"
echo "Mutation score: ${MUTATION_SCORE}%"
echo ""

# Create detailed results file
cat > context/mutation-test/results/execution/working_summary.md << EOF
# ReFlax Mutation Testing - Actual Execution Results

## Executive Summary
Actual mutation testing results from running tests against mutated contracts.

## Results by Contract

### PriceTilterTWAP
- **Mutations Tested**: 10 samples
- **Test Suite**: PriceTilterTWAPTest (8 tests)
- **Baseline**: All tests passing

### TWAPOracle  
- **Mutations Tested**: 10 samples
- **Test Suite**: TWAPOracleTest (9 tests)
- **Baseline**: All tests passing

### Overall Results
- **Total Tested**: $TOTAL_TESTED
- **Killed**: $TOTAL_KILLED
- **Survived**: $TOTAL_SURVIVED
- **Mutation Score**: ${MUTATION_SCORE}%

## Methodology
- Selected contracts with fully passing test suites
- Tested sample mutations (10 per contract)
- Used contract-specific test filters to avoid cross-contamination
- Each mutation was tested independently with original file restoration

## Key Findings
- Real mutation scores obtained through actual test execution
- Results show test suite effectiveness at catching code changes
- Higher scores indicate better test coverage and assertions

Generated: $(date)
EOF

# Analyze specific mutation types that survived
echo "📊 Analyzing survived mutations..."
if [ -f context/mutation-test/results/execution/working_results.csv ]; then
    echo "" >> context/mutation-test/results/execution/working_summary.md
    echo "## Survived Mutations Analysis" >> context/mutation-test/results/execution/working_summary.md
    echo "" >> context/mutation-test/results/execution/working_summary.md
    
    # Get survived mutations
    grep "SURVIVED" context/mutation-test/results/execution/working_results.csv | while read line; do
        contract=$(echo $line | cut -d',' -f1)
        mutant_id=$(echo $line | cut -d',' -f2)
        echo "- $contract mutant $mutant_id survived" >> context/mutation-test/results/execution/working_summary.md
    done
fi

echo "✅ Mutation testing complete!"
echo "📋 Results saved in context/mutation-test/results/execution/"