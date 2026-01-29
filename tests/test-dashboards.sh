#!/bin/bash
# Test Dashboards Script
# Validates dashboard JSON syntax and structure

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DASHBOARDS_DIR="$PROJECT_ROOT/dashboards"

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo -e "${RED}Error: jq is required but not installed.${NC}"
    echo "Install with: sudo apt-get install jq (or brew install jq on macOS)"
    exit 1
fi

PASSED=0
FAILED=0

validate_dashboard() {
    local dashboard_file=$1
    local dashboard_name
    dashboard_name=$(basename "$dashboard_file")

    echo -n "Validating $dashboard_name... "

    # Check file exists
    if [ ! -f "$dashboard_file" ]; then
        echo -e "${RED}✗${NC} (file not found)"
        FAILED=$((FAILED + 1))
        return 1
    fi

    # Validate JSON syntax
    if ! jq empty "$dashboard_file" 2>/dev/null; then
        echo -e "${RED}✗${NC} (invalid JSON)"
        FAILED=$((FAILED + 1))
        return 1
    fi

    # Check required dashboard fields
    REQUIRED_FIELDS=("title" "panels" "schemaVersion")
    for field in "${REQUIRED_FIELDS[@]}"; do
        if ! jq -e ".$field" "$dashboard_file" > /dev/null 2>&1; then
            echo -e "${RED}✗${NC} (missing required field: $field)"
            FAILED=$((FAILED + 1))
            return 1
        fi
    done

    # Check panels array
    PANEL_COUNT=$(jq '.panels | length' "$dashboard_file" 2>/dev/null || echo "0")
    if [ "$PANEL_COUNT" == "0" ]; then
        echo -e "${YELLOW}⚠${NC} (no panels)"
        FAILED=$((FAILED + 1))
        return 1
    fi

    echo -e "${GREEN}✓${NC} ($PANEL_COUNT panels)"
    PASSED=$((PASSED + 1))
    return 0
}

echo "=========================================="
echo "Testing Dashboards"
echo "=========================================="
echo ""

# Find all dashboard JSON files
DASHBOARD_FILES=("$DASHBOARDS_DIR"/*.json)

if [ ${#DASHBOARD_FILES[@]} -eq 0 ] || [ ! -f "${DASHBOARD_FILES[0]}" ]; then
    echo -e "${RED}Error: No dashboard files found in $DASHBOARDS_DIR${NC}"
    exit 1
fi

# Validate each dashboard
for dashboard_file in "${DASHBOARD_FILES[@]}"; do
    validate_dashboard "$dashboard_file"
done

echo ""
echo "=========================================="
echo "Test Results"
echo "=========================================="
echo -e "${GREEN}Passed: $PASSED${NC}"
if [ $FAILED -gt 0 ]; then
    echo -e "${RED}Failed: $FAILED${NC}"
    exit 1
else
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
fi
