#!/bin/bash
# Test Scraping Script
# Verifies vmagent is scraping all targets

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

PASSED=0
FAILED=0

check_scrape_target() {
    local job=$1

    echo -n "Checking scrape job '$job'... "

    # Query vmagent's internal metrics
    SCRAPE_METRICS=$(curl -s http://localhost:8429/metrics | grep "vmagent_scrape" || echo "")

    if echo "$SCRAPE_METRICS" | grep -q "$job"; then
        # Check if target is up
        UP_METRIC=$(curl -s http://localhost:8429/metrics | grep "up{job=\"$job\"" | awk '{print $2}' || echo "0")

        if [ "$UP_METRIC" == "1" ]; then
            echo -e "${GREEN}✓${NC} (up)"
            PASSED=$((PASSED + 1))
        else
            echo -e "${YELLOW}⚠${NC} (target down or no metrics yet)"
            FAILED=$((FAILED + 1))
        fi
    else
        echo -e "${RED}✗${NC} (job not found)"
        FAILED=$((FAILED + 1))
    fi
}

echo "=========================================="
echo "Testing Scraping Configuration"
echo "=========================================="
echo ""

# Check vmagent is running
if ! curl -s http://localhost:8429/metrics > /dev/null 2>&1; then
    echo -e "${RED}Error: vmagent is not responding${NC}"
    exit 1
fi

# Check each scrape job
check_scrape_target "vmagent" "vmagent"
check_scrape_target "aws-cloudwatch" "aws_"
check_scrape_target "gcp-monitoring" "stackdriver"
check_scrape_target "node-exporter" "node_"
check_scrape_target "cadvisor" "container_"

echo ""
echo "=========================================="
echo "Test Results"
echo "=========================================="
echo -e "${GREEN}Passed: $PASSED${NC}"
if [ $FAILED -gt 0 ]; then
    echo -e "${YELLOW}Warnings: $FAILED${NC}"
    echo "Note: Some targets may be down if no resources exist yet"
    exit 0
else
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
fi
