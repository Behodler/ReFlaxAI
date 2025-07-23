#!/bin/bash

# ReFlax Local Environment Cleanup Script
# Stops all running services and cleans up processes

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== ReFlax Local Environment Cleanup ===${NC}"
echo ""

# Function to safely kill processes on a port
kill_port() {
    local port=$1
    local service_name=$2
    
    local pids=$(lsof -ti:$port 2>/dev/null || true)
    if [ ! -z "$pids" ]; then
        echo -e "${BLUE}[INFO]${NC} Stopping $service_name on port $port..."
        echo $pids | xargs kill -9 2>/dev/null || true
        sleep 1
        
        # Verify processes are stopped
        local remaining=$(lsof -ti:$port 2>/dev/null || true)
        if [ -z "$remaining" ]; then
            echo -e "${GREEN}[SUCCESS]${NC} $service_name stopped"
        else
            echo -e "${YELLOW}[WARNING]${NC} Some $service_name processes may still be running"
        fi
    else
        echo -e "${BLUE}[INFO]${NC} No $service_name processes found on port $port"
    fi
}

# Function to kill processes by name
kill_by_name() {
    local process_name=$1
    local service_name=$2
    
    local pids=$(pgrep -f "$process_name" 2>/dev/null || true)
    if [ ! -z "$pids" ]; then
        echo -e "${BLUE}[INFO]${NC} Stopping $service_name processes..."
        echo $pids | xargs kill -9 2>/dev/null || true
        sleep 1
        
        # Verify processes are stopped
        local remaining=$(pgrep -f "$process_name" 2>/dev/null || true)
        if [ -z "$remaining" ]; then
            echo -e "${GREEN}[SUCCESS]${NC} $service_name processes stopped"
        else
            echo -e "${YELLOW}[WARNING]${NC} Some $service_name processes may still be running"
        fi
    else
        echo -e "${BLUE}[INFO]${NC} No $service_name processes found"
    fi
}

# Stop services by port
kill_port 8545 "Anvil node"
kill_port 3011 "Address server"

# Stop services by process name
kill_by_name "anvil" "Anvil"
kill_by_name "addressServer.js" "Address server"

# Clean up any deployment artifacts (optional)
echo -e "${BLUE}[INFO]${NC} Cleaning up deployment artifacts..."
if [ -f "scripts/deployedAddresses.json" ]; then
    rm -f "scripts/deployedAddresses.json"
    echo -e "${BLUE}[INFO]${NC} Removed deployed addresses file"
fi

# Clean up broadcast files (optional - keeping for debugging)
# if [ -d "broadcast" ]; then
#     rm -rf broadcast
#     echo -e "${BLUE}[INFO]${NC} Removed broadcast directory"
# fi

echo ""
echo -e "${GREEN}[SUCCESS]${NC} ReFlax local environment cleanup complete!"
echo -e "${BLUE}[INFO]${NC} You can now start fresh with: npm start"
echo ""