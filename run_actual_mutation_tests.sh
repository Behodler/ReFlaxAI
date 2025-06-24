#!/bin/bash

# ReFlax Mutation Testing Execution Script
# This script actually runs tests against mutations to get real scores

set -e

echo "🧬 Starting ReFlax Mutation Testing Execution"
echo "============================================="

# Create results directory
mkdir -p context/mutation-test/results/execution

# Track overall results
TOTAL_MUTANTS=0
TOTAL_KILLED=0
TOTAL_SURVIVED=0
TOTAL_ERRORS=0

echo "📊 Testing strategy: Copy mutant → Run tests → Record results"
echo ""

# Test function for a single mutant
test_mutant() {
    local contract_dir=$1
    local mutant_id=$2
    local original_file=$3
    local mutant_file=$4
    
    echo "Testing mutant $mutant_id..."
    
    # Backup original
    cp "$original_file" "${original_file}.backup"
    
    # Copy mutant
    cp "$mutant_file" "$original_file"
    
    # Run tests and capture result
    if forge test --no-match-contract "EmergencyRebaseIntegrationTest" >/dev/null 2>&1; then
        echo "SURVIVED,$mutant_id" >> "context/mutation-test/results/execution/${contract_dir}_results.csv"
        return 1  # Survived
    else
        echo "KILLED,$mutant_id" >> "context/mutation-test/results/execution/${contract_dir}_results.csv"
        return 0  # Killed
    fi
}

# Restore function
restore_original() {
    local original_file=$1
    if [ -f "${original_file}.backup" ]; then
        mv "${original_file}.backup" "$original_file"
    fi
}

# Test mutations for a contract if mutant files exist
test_contract_mutations() {
    local contract_name=$1
    local contract_dir="mutation-reports/$contract_name"
    local original_file=""
    
    echo "🔍 Processing $contract_name mutations..."
    
    # Determine original file path
    case $contract_name in
        "CVX_CRV_YieldSource")
            original_file="src/yieldSource/CVX_CRV_YieldSource.sol"
            ;;
        "PriceTilterTWAP")
            original_file="src/priceTilting/PriceTilterTWAP.sol"
            ;;
        "TWAPOracle")
            original_file="src/priceTilting/TWAPOracle.sol"
            ;;
        "AYieldSource")
            original_file="src/yieldSource/AYieldSource.sol"
            ;;
        *)
            echo "❌ Unknown contract: $contract_name"
            return
            ;;
    esac
    
    # Check if mutants directory exists
    if [ ! -d "$contract_dir/mutants" ]; then
        echo "⚠️  No mutants directory found for $contract_name"
        return
    fi
    
    # Initialize results file
    echo "STATUS,MUTANT_ID" > "context/mutation-test/results/execution/${contract_name}_results.csv"
    
    local killed=0
    local survived=0
    local errors=0
    local tested=0
    
    # Test first 20 mutants as a sample (to avoid long execution)
    for mutant_dir in "$contract_dir/mutants"/{1..20}; do
        if [ -d "$mutant_dir" ]; then
            local mutant_id=$(basename "$mutant_dir")
            local mutant_file=""
            
            # Find the mutant file
            if [ -f "$mutant_dir/$original_file" ]; then
                mutant_file="$mutant_dir/$original_file"
            elif [ -f "$mutant_dir/src/yieldSource/CVX_CRV_YieldSource.sol" ]; then
                mutant_file="$mutant_dir/src/yieldSource/CVX_CRV_YieldSource.sol"
            else
                echo "⚠️  Mutant file not found for $mutant_id"
                continue
            fi
            
            tested=$((tested + 1))
            
            # Test the mutant with error handling
            if test_mutant "$contract_name" "$mutant_id" "$original_file" "$mutant_file"; then
                killed=$((killed + 1))
            else
                survived=$((survived + 1))
            fi
            
            # Always restore original
            restore_original "$original_file"
        fi
        
        # Limit to first 20 for initial testing
        if [ $tested -eq 20 ]; then
            break
        fi
    done
    
    # Calculate mutation score
    if [ $tested -gt 0 ]; then
        local score=$((killed * 100 / tested))
        echo "📈 $contract_name Results: $killed killed, $survived survived, Score: ${score}%"
    else
        echo "❌ No mutants tested for $contract_name"
    fi
    
    # Update totals
    TOTAL_MUTANTS=$((TOTAL_MUTANTS + tested))
    TOTAL_KILLED=$((TOTAL_KILLED + killed))
    TOTAL_SURVIVED=$((TOTAL_SURVIVED + survived))
}

# Ensure we're in the right directory
cd /home/justin/code/BehodlerReborn/Grok/reflax

# Run baseline test first
echo "🧪 Running baseline tests..."
if ! forge test --no-match-contract "EmergencyRebaseIntegrationTest" >/dev/null 2>&1; then
    echo "❌ Baseline tests failed! Fix tests before running mutation testing."
    exit 1
fi
echo "✅ Baseline tests passed"
echo ""

# Test each contract
for contract in CVX_CRV_YieldSource PriceTilterTWAP TWAPOracle AYieldSource; do
    test_contract_mutations "$contract"
    echo ""
done

# Final summary
echo "🎯 MUTATION TESTING SUMMARY"
echo "=========================="
echo "Total mutants tested: $TOTAL_MUTANTS"
echo "Killed: $TOTAL_KILLED"  
echo "Survived: $TOTAL_SURVIVED"
if [ $TOTAL_MUTANTS -gt 0 ]; then
    OVERALL_SCORE=$((TOTAL_KILLED * 100 / TOTAL_MUTANTS))
    echo "Overall mutation score: ${OVERALL_SCORE}%"
else
    echo "Overall mutation score: No mutants tested"
fi

# Create summary file
cat > context/mutation-test/results/execution/summary.md << EOF
# ReFlax Mutation Testing - Actual Execution Results

## Summary
- **Total Mutants Tested**: $TOTAL_MUTANTS (sample of 875 total)
- **Killed**: $TOTAL_KILLED
- **Survived**: $TOTAL_SURVIVED  
- **Overall Score**: ${OVERALL_SCORE:-0}%

## Methodology
- Tested first 20 mutants per contract as representative sample
- Used forge test suite excluding integration tests
- Recorded kill/survive status for each mutant

Generated: $(date)
EOF

echo ""
echo "✅ Mutation testing execution complete!"
echo "📋 Results saved in context/mutation-test/results/execution/"