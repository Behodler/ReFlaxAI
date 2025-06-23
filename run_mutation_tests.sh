#!/bin/bash

set -e

echo "**ReFlax Mutation:** Running mutation tests for Vault contract..."

# Configuration
MUTATIONS_DIR="vault_mutations"
RESULTS_FILE="mutation_test_results.json"
TEMP_DIR="temp_mutant_test"
ORIGINAL_FILE="src/vault/Vault.sol"
BACKUP_FILE="src/vault/Vault.sol.backup"

# Create backup of original file
cp "$ORIGINAL_FILE" "$BACKUP_FILE"

# Initialize results
echo '{"total_mutations": 263, "killed": 0, "survived": 0, "compilation_errors": 0, "timeout": 0, "results": []}' > "$RESULTS_FILE"

# Counter variables
killed=0
survived=0
compilation_errors=0
timeout_count=0

echo "Testing mutations..."

for i in {1..263}; do
    echo -n "Testing mutation $i... "
    
    # Extract contract name from flattened file (remove everything before "contract Vault")
    awk '/^contract Vault /{flag=1} flag' "$MUTATIONS_DIR/mutants/$i/vault_flattened.sol" > "$TEMP_DIR.sol"
    
    # Replace original file with mutant
    cp "$TEMP_DIR.sol" "$ORIGINAL_FILE"
    
    # Try to compile first
    if ! forge build > /dev/null 2>&1; then
        echo "COMPILATION ERROR"
        ((compilation_errors++))
        continue
    fi
    
    # Run tests with timeout
    if timeout 60s forge test --match-contract VaultTest > /dev/null 2>&1; then
        echo "SURVIVED"
        ((survived++))
        # Add to results as survived mutation
        jq --arg id "$i" --arg status "survived" '.results += [{"id": $id, "status": $status}]' "$RESULTS_FILE" > temp.json && mv temp.json "$RESULTS_FILE"
    else
        echo "KILLED"
        ((killed++))
        # Add to results as killed mutation
        jq --arg id "$i" --arg status "killed" '.results += [{"id": $id, "status": $status}]' "$RESULTS_FILE" > temp.json && mv temp.json "$RESULTS_FILE"
    fi
    
    # Restore original file
    cp "$BACKUP_FILE" "$ORIGINAL_FILE"
    
    # Progress update every 50 mutations
    if (( i % 50 == 0 )); then
        echo "Progress: $i/263 mutations tested"
    fi
done

# Update final counts
jq --arg killed "$killed" --arg survived "$survived" --arg comp_errors "$compilation_errors" \
   '.killed = ($killed | tonumber) | .survived = ($survived | tonumber) | .compilation_errors = ($comp_errors | tonumber)' \
   "$RESULTS_FILE" > temp.json && mv temp.json "$RESULTS_FILE"

# Calculate mutation score
if (( killed + survived > 0 )); then
    mutation_score=$(( (killed * 100) / (killed + survived) ))
else
    mutation_score=0
fi

echo ""
echo "=== MUTATION TESTING RESULTS ==="
echo "Total mutations: 263"
echo "Killed: $killed"
echo "Survived: $survived"
echo "Compilation errors: $compilation_errors"
echo "Mutation score: ${mutation_score}%"
echo ""

# Clean up
rm -f "$TEMP_DIR.sol"
rm -f "$BACKUP_FILE"

echo "Results saved to $RESULTS_FILE"

# Return non-zero exit code if mutation score is below target
if (( mutation_score < 85 )); then
    echo "WARNING: Mutation score ($mutation_score%) is below target (85%)"
    exit 1
fi