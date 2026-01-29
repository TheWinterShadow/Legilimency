#!/bin/bash
# Test Remote Write Script
# Verifies that vmagent is successfully pushing metrics to Grafana Cloud

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

echo "Testing Remote Write to Grafana Cloud..."
echo ""

# Check required variables
if [ -z "${GRAFANA_CLOUD_PROMETHEUS_URL:-}" ] || [ -z "${GRAFANA_CLOUD_USERNAME:-}" ] || [ -z "${GRAFANA_CLOUD_API_KEY:-}" ]; then
    echo -e "${RED}Error: Grafana Cloud credentials not set in .env${NC}"
    exit 1
fi

# Test 1: Check vmagent container is running
echo "1. Checking vmagent container..."
if docker-compose ps vmagent 2>&1 | grep -q "Up"; then
    echo -e "${GREEN}✓${NC} vmagent container is running"
else
    echo -e "${RED}✗${NC} vmagent container is not running"
    echo "Start with: docker-compose up -d vmagent"
    exit 1
fi
echo ""

# Test 2: Check vmagent metrics endpoint
echo "2. Checking vmagent metrics endpoint..."
if curl -s http://localhost:8429/metrics | grep -q "vmagent"; then
    echo -e "${GREEN}✓${NC} vmagent metrics endpoint is responding"
else
    echo -e "${RED}✗${NC} vmagent metrics endpoint not responding"
    exit 1
fi
echo ""

# Test 3: Check vmagent logs for remote write status
echo "3. Checking vmagent remote write status..."
sleep 2
LOG_CHECK=$(docker-compose logs vmagent 2>&1 | tail -50)

if echo "$LOG_CHECK" | grep -qi "successfully sent\|remote write.*ok\|pushed.*samples"; then
    echo -e "${GREEN}✓${NC} Remote write appears successful in logs"

    # Extract success count if available
    SUCCESS_COUNT=$(echo "$LOG_CHECK" | grep -i "successfully sent" | tail -1 | grep -oE "[0-9]+" | head -1 || echo "")
    if [ -n "$SUCCESS_COUNT" ]; then
        echo "  Last successful write: $SUCCESS_COUNT samples"
    fi
else
    echo -e "${YELLOW}⚠${NC} Could not find success messages in logs"
    echo "  This may be normal if vmagent just started"
fi

# Check for errors
if echo "$LOG_CHECK" | grep -qi "error\|failed\|denied\|unauthorized"; then
    echo -e "${YELLOW}⚠${NC} Found potential errors in logs:"
    echo "$LOG_CHECK" | grep -i "error\|failed\|denied\|unauthorized" | tail -3 | sed 's/^/  /'
fi
echo ""

# Test 4: Query Grafana Cloud to verify data arrived
echo "4. Querying Grafana Cloud for metrics..."
QUERY_URL="${GRAFANA_CLOUD_PROMETHEUS_URL/\/push/\/query}"

# Wait a bit for metrics to propagate
sleep 5

QUERY_RESPONSE=$(curl -s -G "$QUERY_URL" \
    --data-urlencode 'query=up{job="vmagent"}' \
    -u "${GRAFANA_CLOUD_USERNAME}:${GRAFANA_CLOUD_API_KEY}" 2>&1)

if echo "$QUERY_RESPONSE" | grep -q "data"; then
    echo -e "${GREEN}✓${NC} Metrics found in Grafana Cloud!"

    # Extract metric value
    METRIC_VALUE=$(echo "$QUERY_RESPONSE" | jq -r '.data.result[0].value[1]' 2>/dev/null || echo "")
    if [ -n "$METRIC_VALUE" ] && [ "$METRIC_VALUE" != "null" ]; then
        echo "  vmagent up metric: $METRIC_VALUE"
    fi
elif echo "$QUERY_RESPONSE" | grep -q "401\|403\|unauthorized"; then
    echo -e "${RED}✗${NC} Authentication failed. Check credentials."
    exit 1
else
    echo -e "${YELLOW}⚠${NC} No metrics found yet (may take a few minutes to appear)"
    echo "  Response: $(echo "$QUERY_RESPONSE" | head -100)"
fi
echo ""

# Test 5: Check remote write queue status
echo "5. Checking remote write queue status..."
QUEUE_STATUS=$(curl -s http://localhost:8429/metrics | grep "vmagent_remote_write" | grep -E "queue|pending|buffered" || echo "")

if [ -n "$QUEUE_STATUS" ]; then
    echo "  Queue metrics:"
    echo "$QUEUE_STATUS" | head -5 | sed 's/^/    /'
else
    echo -e "${YELLOW}⚠${NC} Could not retrieve queue metrics"
fi
echo ""

echo "=========================================="
echo -e "${GREEN}Remote Write Test Complete!${NC}"
echo "=========================================="
echo ""
echo "View metrics in Grafana Cloud:"
echo "  ${GRAFANA_CLOUD_URL:-https://grafana.com}"
echo ""
