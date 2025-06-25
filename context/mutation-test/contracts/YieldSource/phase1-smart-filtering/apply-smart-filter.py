#!/usr/bin/env python3
"""
Smart Filter for CVX_CRV_YieldSource Mutations
Based on proven Vault methodology - focus on high-value business logic
"""

import re

def should_exclude_mutation(line):
    """
    Apply smart filtering to exclude low-value mutations
    Returns True if mutation should be EXCLUDED
    """
    
    # Parse mutation line
    parts = line.strip().split(',', 4)
    if len(parts) < 5:
        return False
        
    mutation_id = parts[0]
    mutation_type = parts[1] 
    file_path = parts[2]
    location = parts[3]
    description = parts[4]
    
    # Category 1: Constructor Infrastructure (Low Value)
    constructor_patterns = [
        r'oracle\.update.*assert\(true\)',           # Oracle update infrastructure
        r'\.approve.*assert\(true\)',                # Token approval setup
        r'poolTokens\.push.*assert\(true\)',         # Array setup
        r'poolTokenSymbols\.push.*assert\(true\)',   # Array setup
        r'rewardTokens\.push.*assert\(true\)',       # Array setup
        r'i\+\+.*assert\(true\)',                    # Loop increment
        r'underlyingWeights\[pool\].*assert\(true\)' # Weight storage
    ]
    
    for pattern in constructor_patterns:
        if re.search(pattern, description):
            return True
    
    # Category 2: Obvious Require Statement Mutations (Low Value)
    obvious_requires = [
        r'require.*== true,true',                    # Always true
        r'require.*== false,false',                  # Always false
        r'RequireMutation.*,true$',                  # Generic true mutation
        r'RequireMutation.*,false$'                  # Generic false mutation
    ]
    
    for pattern in obvious_requires:
        if re.search(pattern, description):
            return True
    
    # Category 3: Equivalent Math Operations (Low Value)
    equivalent_math = [
        r'10000 / poolTokens\.length,poolTokens\.length / 10000',  # Order swap on division
        r'/ ,\*\*',                                  # Division to power (obvious)
        r'weights\[i\],0',                          # Zero assignment (obvious)
        r'weights\[i\],1'                           # One assignment (obvious)
    ]
    
    for pattern in equivalent_math:
        if re.search(pattern, description):
            return True
    
    # Category 4: Loop Infrastructure (Low Value) 
    loop_infrastructure = [
        r'poolTokens\.length < i',                   # Obvious loop bound swap
        r'weights\.length < i',                      # Obvious loop bound swap
        r'rewardTokens\.length < i',                 # Obvious loop bound swap
        r'\+\+,--'                                   # Increment to decrement
    ]
    
    for pattern in loop_infrastructure:
        if re.search(pattern, description):
            return True
    
    # Category 5: Null/Zero Checks (Low Value)
    null_checks = [
        r'address\(.*\) != address\(0\),true',       # Always true null check
        r'address\(.*\) != address\(0\),false',      # Always false null check
        r'allocatedAmount > 0,0 > allocatedAmount'   # Obvious comparison swap
    ]
    
    for pattern in null_checks:
        if re.search(pattern, description):
            return True
    
    # All other mutations are HIGH VALUE - include them
    return False

def apply_smart_filter():
    """Apply smart filtering to mutations"""
    
    excluded_mutations = []
    included_mutations = []
    
    with open('gambit_out/mutants.log', 'r') as f:
        for line in f:
            if should_exclude_mutation(line):
                excluded_mutations.append(line.strip())
            else:
                included_mutations.append(line.strip())
    
    # Write results
    with open('context/mutation-test/contracts/YieldSource/phase1-smart-filtering/excluded-mutations.txt', 'w') as f:
        for mutation in excluded_mutations:
            f.write(mutation + '\n')
    
    with open('context/mutation-test/contracts/YieldSource/phase1-smart-filtering/included-mutations.txt', 'w') as f:
        for mutation in included_mutations:
            f.write(mutation + '\n')
    
    # Statistics
    total = len(excluded_mutations) + len(included_mutations)
    excluded_count = len(excluded_mutations)
    included_count = len(included_mutations)
    excluded_percent = (excluded_count / total) * 100
    
    print(f"Smart Filtering Results:")
    print(f"Total mutations: {total}")
    print(f"Excluded (low-value): {excluded_count} ({excluded_percent:.1f}%)")
    print(f"Included (high-value): {included_count} ({100-excluded_percent:.1f}%)")
    
    # Create summary report
    with open('context/mutation-test/contracts/YieldSource/phase1-smart-filtering/filter-summary.md', 'w') as f:
        f.write(f"# Smart Filter Results for CVX_CRV_YieldSource\n\n")
        f.write(f"## Summary\n")
        f.write(f"- **Total Mutations**: {total}\n")
        f.write(f"- **Excluded**: {excluded_count} ({excluded_percent:.1f}%)\n")
        f.write(f"- **Included**: {included_count} ({100-excluded_percent:.1f}%)\n\n")
        f.write(f"## Filtering Efficiency\n")
        f.write(f"- **Time Savings**: ~{excluded_percent:.0f}% reduction in testing time\n")
        f.write(f"- **Focus**: DeFi integration and financial calculation logic\n")
        f.write(f"- **Quality**: High-value mutations only\n\n")
        f.write(f"## Exclusion Categories Applied\n")
        f.write(f"1. Constructor infrastructure (approvals, array setup)\n")
        f.write(f"2. Obvious require mutations (true/false)\n")
        f.write(f"3. Equivalent math operations\n")
        f.write(f"4. Loop infrastructure patterns\n")
        f.write(f"5. Null/zero validation checks\n")

if __name__ == "__main__":
    apply_smart_filter()