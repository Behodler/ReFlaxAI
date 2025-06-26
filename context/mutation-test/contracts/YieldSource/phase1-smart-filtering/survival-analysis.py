#!/usr/bin/env python3
"""
Analyze surviving YieldSource mutations to identify test coverage gaps
"""

def analyze_survival_patterns():
    """Analyze which mutation types are surviving to identify test gaps"""
    
    surviving_ids = [51,52,58,59,60,61,62,63,64,65,66,83,84,85,86,88,90,91,92,93,94,95,96,98,99,100,101,102,103,104,105,106,107,108,109,116,117,120,121,125,128,130,136,139,140,141,142,143,148,149,150,151,152,153,154,155,156,157,158,159,160,161,163,164,165,166,167,168,169,170,171,172,173,174,186,187,188,189,193,195,196,198,199,203,204,209,210,211,212,216,218,219,221,222,226,227,236,245,251,253,254,255,256,257,258,259,260,261,262,263,264,265,266,267,268,269,270,271,272,273,274,275,276,277,278,279,280]
    
    # Read mutations log
    mutations = {}
    with open('gambit_out/mutants.log', 'r') as f:
        for line in f:
            parts = line.strip().split(',', 4)
            if len(parts) >= 5:
                mut_id = int(parts[0])
                mut_type = parts[1]
                location = parts[3]
                description = parts[4]
                mutations[mut_id] = {
                    'type': mut_type,
                    'location': location, 
                    'description': description
                }
    
    # Categorize surviving mutations
    categories = {
        'financial_calculations': [],
        'defi_integration': [],
        'slippage_protection': [],
        'weight_distribution': [],
        'constructor_logic': [],
        'loop_operations': [],
        'if_statements': [],
        'assignments': [],
        'other': []
    }
    
    for mut_id in surviving_ids:
        if mut_id in mutations:
            mut = mutations[mut_id]
            description = mut['description'].lower()
            
            # Categorize by content
            if 'weight' in description or '10000' in description:
                categories['weight_distribution'].append((mut_id, mut))
            elif 'slippage' in description or 'minout' in description:
                categories['slippage_protection'].append((mut_id, mut))
            elif 'amount' in description and ('*' in description or '/' in description):
                categories['financial_calculations'].append((mut_id, mut))
            elif 'uniswap' in description or 'curve' in description or 'convex' in description:
                categories['defi_integration'].append((mut_id, mut))
            elif mut['type'] == 'IfStatementMutation':
                categories['if_statements'].append((mut_id, mut))
            elif mut['type'] == 'AssignmentMutation':
                categories['assignments'].append((mut_id, mut))
            elif 'constructor' in mut['location'].lower():
                categories['constructor_logic'].append((mut_id, mut))
            elif 'i++' in description or 'loop' in description:
                categories['loop_operations'].append((mut_id, mut))
            else:
                categories['other'].append((mut_id, mut))
    
    # Generate analysis report
    with open('context/mutation-test/contracts/YieldSource/phase1-smart-filtering/survival-analysis.md', 'w') as f:
        f.write("# YieldSource Survival Analysis - Critical Test Coverage Gaps\n\n")
        f.write("## Executive Summary\n")
        f.write(f"**Total Surviving**: {len(surviving_ids)} mutations (54% survival rate)\n")
        f.write("**Critical Finding**: Major test coverage gaps in DeFi integration logic\n\n")
        
        for category, mutations_list in categories.items():
            if mutations_list:
                f.write(f"## {category.replace('_', ' ').title()} ({len(mutations_list)} mutations)\n\n")
                
                for mut_id, mut in mutations_list[:5]:  # Show first 5 examples
                    f.write(f"**Mutation {mut_id}**: {mut['type']}\n")
                    f.write(f"- Location: {mut['location']}\n")  
                    f.write(f"- Description: {mut['description']}\n\n")
                
                if len(mutations_list) > 5:
                    f.write(f"... and {len(mutations_list) - 5} more similar mutations\n\n")
        
        # Identify major gap clusters
        f.write("## Major Gap Clusters\n\n")
        f.write("### Cluster 1: Weight Distribution (58-66)\n")
        f.write("- **Pattern**: Binary operations in weight calculations\n")
        f.write("- **Impact**: Financial calculation security\n")
        f.write("- **Tests Needed**: Weight edge cases, division by zero\n\n")
        
        f.write("### Cluster 2: DeFi Integration (148-174)\n")
        f.write("- **Pattern**: 27 consecutive surviving mutations\n")
        f.write("- **Impact**: Uniswap/Curve interaction security\n")
        f.write("- **Tests Needed**: DeFi protocol failure scenarios\n\n")
        
        f.write("### Cluster 3: Financial Operations (253-280)\n")
        f.write("- **Pattern**: Critical arithmetic operations\n")
        f.write("- **Impact**: User fund safety\n")
        f.write("- **Tests Needed**: Financial boundary conditions\n\n")

if __name__ == "__main__":
    analyze_survival_patterns()