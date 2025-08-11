#!/bin/bash
# Test script for Tastytrade CLI option commands
# This script tests all the main CLI commands to ensure they work

echo "============================================================"
echo "Testing Tastytrade CLI Option Commands"
echo "============================================================"

# Color codes for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to test a command
test_command() {
    local description="$1"
    local command="$2"
    
    echo -e "\n${description}..."
    if eval "$command" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Success${NC}"
        return 0
    else
        echo -e "${RED}✗ Failed${NC}"
        return 1
    fi
}

# Test login first
echo -e "\n1. Testing authentication"
test_command "Login to sandbox" "bundle exec exe/tastytrade login --test --no-interactive"

# Test option chain display
echo -e "\n2. Testing option chain display"
test_command "Basic chain" "bundle exec exe/tastytrade option chain SPY --test --strikes 2 --expirations 1"
test_command "Compact format" "bundle exec exe/tastytrade option chain SPY --test --strikes 2 --format compact"
test_command "With filters" "bundle exec exe/tastytrade option chain SPY --test --dte 30 --strikes 5"

# Test option quote
echo -e "\n3. Testing option quotes"
test_command "Quote with normalized symbol" "bundle exec exe/tastytrade option quote SPY250811C00620000 --test"

# Test single option orders
echo -e "\n4. Testing single option orders (dry-run)"
test_command "Buy call" "bundle exec exe/tastytrade option buy call SPY --test --strike 620 --expiration 2025-08-11 --dry-run"
test_command "Sell put" "bundle exec exe/tastytrade option sell put SPY --test --strike 620 --expiration 2025-08-11 --dry-run"

# Test multi-leg strategies
echo -e "\n5. Testing multi-leg strategies (dry-run)"
test_command "Vertical spread" "bundle exec exe/tastytrade option spread SPY --test --type call --long-strike 619 --short-strike 621 --expiration 2025-08-11 --dry-run"
test_command "Strangle" "bundle exec exe/tastytrade option strangle SPY --test --call-strike 625 --put-strike 615 --expiration 2025-08-11 --dry-run"
test_command "Straddle" "bundle exec exe/tastytrade option straddle SPY --test --strike 620 --expiration 2025-08-11 --dry-run"

# Test advanced strategies (NEW)
echo -e "\n6. Testing advanced strategies (dry-run)"
test_command "Iron Butterfly" "bundle exec exe/tastytrade option iron_butterfly SPY --test --center-strike 620 --wing-width 10 --expiration 2025-08-11 --dry-run"
test_command "Call Butterfly" "bundle exec exe/tastytrade option butterfly SPY --test --type call --center-strike 620 --wing-width 10 --expiration 2025-08-11 --dry-run"
test_command "Put Butterfly" "bundle exec exe/tastytrade option butterfly SPY --test --type put --center-strike 620 --wing-width 10 --expiration 2025-08-11 --dry-run"
test_command "Call Calendar" "bundle exec exe/tastytrade option calendar SPY --test --type call --strike 620 --short-dte 30 --long-dte 60 --dry-run"
test_command "Put Calendar" "bundle exec exe/tastytrade option calendar SPY --test --type put --strike 620 --short-dte 30 --long-dte 60 --dry-run"
test_command "Call Diagonal" "bundle exec exe/tastytrade option diagonal SPY --test --type call --short-strike 620 --long-strike 625 --short-dte 30 --long-dte 60 --dry-run"
test_command "Put Diagonal" "bundle exec exe/tastytrade option diagonal SPY --test --type put --short-strike 620 --long-strike 615 --short-dte 30 --long-dte 60 --dry-run"

echo -e "\n============================================================"
echo "Testing Complete!"
echo "All strategies including advanced ones tested!"
echo "============================================================"