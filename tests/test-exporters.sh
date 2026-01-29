#!/bin/bash
# Test Exporters Script
# Verifies all exporters are responding on correct ports

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

PASSED=0
FAILED=0

test_endpoint() {
    local name=$1
    local url=$2
    local expected_content=$3

    echo -n "Testing $name... "

    if curl -s --max-time 5 "$url" | grep -q "$expected_content"; then
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
echo "Testing Exporters"
echo "=========================================="
echo ""

# Test vmagent
test_endpoint "vmagent" "http://localhost:8429/metrics" "vmagent"

# Test YACE
test_endpoint "YACE (AWS)" "http://localhost:5000/metrics" "aws_"

# Test Stackdriver Exporter
test_endpoint "Stackdriver Exporter (GCP)" "http://localhost:9255/metrics" "stackdriver"

# Test Node Exporter
test_endpoint "Node Exporter" "http://localhost:9100/metrics" "node_"

# Test cAdvisor
test_endpoint "cAdvisor" "http://localhost:8081/metrics" "container_"

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
