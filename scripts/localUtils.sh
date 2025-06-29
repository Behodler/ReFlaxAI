#!/bin/bash

# ReFlax Local Deployment Utilities
# Provides tools for managing local deployment state, health checks, and development workflows

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
RPC_URL="http://localhost:8545"
SNAPSHOTS_DIR="./local-deployment-snapshots"
LOGS_DIR="./local-deployment-logs"
CONFIG_FILE="./context/local-deployment/DeploymentConfig.json"

# Ensure directories exist
mkdir -p "$SNAPSHOTS_DIR"
mkdir -p "$LOGS_DIR"

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_anvil() {
    if ! curl -s -X POST -H "Content-Type: application/json" \
         --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
         "$RPC_URL" > /dev/null 2>&1; then
        log_error "Anvil not running on $RPC_URL"
        log_info "Start Anvil with: anvil --host 0.0.0.0 --port 8545"
        exit 1
    fi
}

get_block_number() {
    cast block-number --rpc-url "$RPC_URL" 2>/dev/null || echo "0"
}

get_timestamp() {
    date +"%Y%m%d_%H%M%S"
}

# Main utility functions

deploy_fresh() {
    log_info "Deploying fresh ReFlax environment..."
    check_anvil
    
    export SCENARIO="fresh"
    if forge script scripts/deployLocal.js --rpc-url "$RPC_URL" --broadcast > "$LOGS_DIR/deploy_$(get_timestamp).log" 2>&1; then
        log_success "Fresh deployment completed"
        create_snapshot "fresh_$(get_timestamp)"
    else
        log_error "Deployment failed. Check log: $LOGS_DIR/deploy_$(get_timestamp).log"
        exit 1
    fi
}

deploy_scenario() {
    local scenario="$1"
    if [ -z "$scenario" ]; then
        log_error "Usage: deploy_scenario <scenario_name>"
        log_info "Available scenarios: fresh, active, stressed, migration, development"
        exit 1
    fi
    
    log_info "Deploying $scenario scenario..."
    check_anvil
    
    export SCENARIO="$scenario"
    if forge script scripts/deployLocal.js --rpc-url "$RPC_URL" --broadcast > "$LOGS_DIR/deploy_${scenario}_$(get_timestamp).log" 2>&1; then
        log_success "$scenario deployment completed"
        create_snapshot "${scenario}_$(get_timestamp)"
    else
        log_error "Deployment failed. Check log: $LOGS_DIR/deploy_${scenario}_$(get_timestamp).log"
        exit 1
    fi
}

create_snapshot() {
    local name="$1"
    if [ -z "$name" ]; then
        name="snapshot_$(get_timestamp)"
    fi
    
    check_anvil
    log_info "Creating snapshot: $name"
    
    local block_number=$(get_block_number)
    local snapshot_file="$SNAPSHOTS_DIR/${name}.json"
    
    # Create snapshot metadata
    cat > "$snapshot_file" << EOF
{
  "name": "$name",
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "blockNumber": $block_number,
  "description": "Snapshot created at block $block_number",
  "rpcUrl": "$RPC_URL"
}
EOF
    
    # Use anvil_dumpState if available, otherwise use block number
    if cast rpc anvil_dumpState --rpc-url "$RPC_URL" > "$SNAPSHOTS_DIR/${name}_state.json" 2>/dev/null; then
        log_success "State snapshot created: $name"
    else
        log_warning "Full state dump not available, using block number reference"
    fi
    
    log_info "Snapshot metadata saved to: $snapshot_file"
}

restore_snapshot() {
    local name="$1"
    if [ -z "$name" ]; then
        log_error "Usage: restore_snapshot <snapshot_name>"
        list_snapshots
        exit 1
    fi
    
    check_anvil
    
    local snapshot_file="$SNAPSHOTS_DIR/${name}.json"
    local state_file="$SNAPSHOTS_DIR/${name}_state.json"
    
    if [ ! -f "$snapshot_file" ]; then
        log_error "Snapshot not found: $name"
        list_snapshots
        exit 1
    fi
    
    log_info "Restoring snapshot: $name"
    
    if [ -f "$state_file" ] && cast rpc anvil_loadState "$(cat "$state_file")" --rpc-url "$RPC_URL" > /dev/null 2>&1; then
        log_success "Snapshot restored: $name"
    else
        log_warning "Full state restore not available. Consider redeploying scenario."
    fi
}

list_snapshots() {
    log_info "Available snapshots:"
    if [ "$(ls -A "$SNAPSHOTS_DIR"/*.json 2>/dev/null)" ]; then
        for snapshot in "$SNAPSHOTS_DIR"/*.json; do
            if [[ "$snapshot" != *"_state.json" ]]; then
                local name=$(basename "$snapshot" .json)
                local timestamp=$(jq -r '.timestamp' "$snapshot" 2>/dev/null || echo "unknown")
                local block=$(jq -r '.blockNumber' "$snapshot" 2>/dev/null || echo "unknown")
                echo "  $name (Block: $block, Time: $timestamp)"
            fi
        done
    else
        echo "  No snapshots found"
    fi
}

health_check() {
    log_info "Running health check..."
    check_anvil
    
    local errors=0
    
    # Check if we can get block number
    local block_number=$(get_block_number)
    if [ "$block_number" = "0" ]; then
        log_error "Cannot get block number"
        ((errors++))
    else
        log_success "Blockchain active (Block: $block_number)"
    fi
    
    # Check for deployed contracts (if addresses file exists)
    if [ -f "./deployed_addresses.json" ]; then
        local vault_address=$(jq -r '.vault' ./deployed_addresses.json 2>/dev/null)
        if [ "$vault_address" != "null" ] && [ "$vault_address" != "" ]; then
            if cast code "$vault_address" --rpc-url "$RPC_URL" | grep -q "0x"; then
                log_success "Vault contract deployed at: $vault_address"
            else
                log_error "Vault contract not found at: $vault_address"
                ((errors++))
            fi
        fi
    fi
    
    if [ $errors -eq 0 ]; then
        log_success "Health check passed"
    else
        log_error "Health check failed with $errors errors"
        exit 1
    fi
}

fast_forward() {
    local seconds="$1"
    if [ -z "$seconds" ]; then
        log_error "Usage: fast_forward <seconds>"
        log_info "Example: fast_forward 86400  # Fast forward 1 day"
        exit 1
    fi
    
    check_anvil
    log_info "Fast forwarding $seconds seconds..."
    
    if cast rpc evm_increaseTime "$seconds" --rpc-url "$RPC_URL" > /dev/null; then
        cast rpc evm_mine --rpc-url "$RPC_URL" > /dev/null
        log_success "Time advanced by $seconds seconds"
    else
        log_error "Failed to fast forward time"
        exit 1
    fi
}

set_stressed_conditions() {
    log_info "Applying stressed market conditions..."
    check_anvil
    
    # This would require deployed contract addresses
    # For now, we'll just log the action
    log_warning "Stressed conditions require contract interaction - implement based on deployed addresses"
    log_info "This would:"
    log_info "  - Increase slippage parameters"
    log_info "  - Reduce pool liquidity"
    log_info "  - Trigger price volatility"
}

reset_to_fresh() {
    log_info "Resetting to fresh state..."
    
    # Try to restore fresh snapshot first
    if [ -f "$SNAPSHOTS_DIR/fresh_baseline.json" ]; then
        restore_snapshot "fresh_baseline"
    else
        log_info "No fresh baseline found, deploying fresh environment..."
        deploy_fresh
    fi
}

monitor_logs() {
    local duration="${1:-60}"
    log_info "Monitoring blockchain logs for $duration seconds..."
    check_anvil
    
    # Monitor new blocks
    local start_block=$(get_block_number)
    log_info "Starting from block: $start_block"
    
    timeout "$duration" bash -c '
        while true; do
            current_block=$(cast block-number --rpc-url '"$RPC_URL"' 2>/dev/null || echo "0")
            if [ "$current_block" != "$last_block" ]; then
                echo "New block: $current_block"
                last_block=$current_block
            fi
            sleep 1
        done
    ' || true
    
    local end_block=$(get_block_number)
    log_info "Monitoring complete. Blocks processed: $((end_block - start_block))"
}

clean_deployment() {
    log_warning "Cleaning deployment artifacts..."
    
    # Remove logs older than 7 days
    find "$LOGS_DIR" -name "*.log" -mtime +7 -delete 2>/dev/null || true
    
    # Remove old snapshots (keep last 10)
    ls -t "$SNAPSHOTS_DIR"/*.json 2>/dev/null | tail -n +11 | xargs rm -f 2>/dev/null || true
    
    log_success "Cleanup complete"
}

show_usage() {
    echo "ReFlax Local Deployment Utilities"
    echo ""
    echo "Usage: $0 <command> [arguments]"
    echo ""
    echo "Commands:"
    echo "  deploy-fresh                    Deploy fresh environment"
    echo "  deploy-scenario <name>          Deploy specific scenario"
    echo "  create-snapshot [name]          Create state snapshot"
    echo "  restore-snapshot <name>         Restore state snapshot"
    echo "  list-snapshots                  List available snapshots"
    echo "  health-check                    Run system health check"
    echo "  fast-forward <seconds>          Fast forward blockchain time"
    echo "  set-stressed                    Apply stressed market conditions"
    echo "  reset-fresh                     Reset to fresh state"
    echo "  monitor-logs [duration]         Monitor blockchain activity"
    echo "  clean                          Clean old logs and snapshots"
    echo ""
    echo "Examples:"
    echo "  $0 deploy-scenario active"
    echo "  $0 create-snapshot before_test"
    echo "  $0 fast-forward 86400"
    echo "  $0 health-check"
}

# Main command dispatcher
case "${1:-}" in
    deploy-fresh)
        deploy_fresh
        ;;
    deploy-scenario)
        deploy_scenario "$2"
        ;;
    create-snapshot)
        create_snapshot "$2"
        ;;
    restore-snapshot)
        restore_snapshot "$2"
        ;;
    list-snapshots)
        list_snapshots
        ;;
    health-check)
        health_check
        ;;
    fast-forward)
        fast_forward "$2"
        ;;
    set-stressed)
        set_stressed_conditions
        ;;
    reset-fresh)
        reset_to_fresh
        ;;
    monitor-logs)
        monitor_logs "$2"
        ;;
    clean)
        clean_deployment
        ;;
    *)
        show_usage
        exit 1
        ;;
esac