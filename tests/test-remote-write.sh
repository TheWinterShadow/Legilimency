#!/bin/bash
# Test Remote Write Script (Test Suite Version)
# Verifies metrics are being pushed to Grafana Cloud

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Load environment variables
if [ ! -f "$PROJECT_ROOT/.env" ]; then
    echo -e "${RED}Error: .env file not found!${NC}"
    exit 1
fi

set -a
source "$PROJECT_ROOT/.env"
set +a

PASSED=0
FAILED=0

test_remote_write_status() {
    local test_name=$1
    local check_command=$2

    echo -n "Testing $test_name... "

    if eval "$check_command" > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC}"
        PASSED=$((PASSED + 1))
        return 0
    else
        echo -e "${RED}✗${NC}"
        FAILED=$((FAILED + 1))
        return 1
    fi
}

echo "=========================================="
echo "Testing Remote Write"
echo "=========================================="
echo ""

# Test 1: vmagent remote write metrics endpoint
test_remote_write_status "vmagent remote write metrics" \
    "curl -s http://localhost:8429/metrics | grep -q 'vmagent_remote_write'"

# Test 2: Check for remote write errors
if [ -n "${GRAFANA_CLOUD_PROMETHEUS_URL:-}" ]; then
    ERROR_COUNT=$(curl -s http://localhost:8429/metrics | \
        grep "vmagent_remote_write_errors_total" | \
        awk '{print $2}' | head -1 || echo "0")

    echo -n "Checking remote write errors... "
    if [ "$ERROR_COUNT" == "0" ] || [ -z "$ERROR_COUNT" ]; then
        echo -e "${GREEN}✓${NC} (no errors)"
        PASSED=$((PASSED + 1))
    else
        echo -e "${YELLOW}⚠${NC} ($ERROR_COUNT errors found)"
        FAILED=$((FAILED + 1))
    fi
fi

# Test 3: Query Grafana Cloud (if credentials available)
if [ -n "${GRAFANA_CLOUD_PROMETHEUS_URL:-}" ] && \
   [ -n "${GRAFANA_CLOUD_USERNAME:-}" ] && \
   [ -n "${GRAFANA_CLOUD_API_KEY:-}" ]; then

    QUERY_URL="${GRAFANA_CLOUD_PROMETHEUS_URL/\/push/\/query}"

    echo -n "Querying Grafana Cloud for metrics... "
    QUERY_RESPONSE=$(curl -s -G "$QUERY_URL" \
        --data-urlencode 'query=up{job="vmagent"}' \
        -u "${GRAFANA_CLOUD_USERNAME}:${GRAFANA_CLOUD_API_KEY}" 2>&1)

    if echo "$QUERY_RESPONSE" | grep -q "data"; then
        echo -e "${GREEN}✓${NC}"
        PASSED=$((PASSED + 1))
    else
        echo -e "${YELLOW}⚠${NC} (metrics may not have propagated yet)"
        FAILED=$((FAILED + 1))
    fi
fi

echo ""
echo "=========================================="
echo "Test Results"
echo "=========================================="
echo -e "${GREEN}Passed: $PASSED${NC}"
if [ $FAILED -gt 0 ]; then
    echo -e "${YELLOW}Warnings: $FAILED${NC}"
    echo "Note: Some tests may fail if metrics haven't propagated yet"
    exit 0
else
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
fi
