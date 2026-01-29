#!/bin/bash
# Health Monitoring Script
# Checks the health of all monitoring stack components

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_ROOT"

echo "=========================================="
echo "Monitoring Stack Health Check"
echo "=========================================="
echo ""

# Check Docker Compose
echo "1. Docker Compose Status"
echo "------------------------"
if docker-compose ps | grep -q "Up"; then
    echo -e "${GREEN}✓${NC} Docker Compose is running"
    docker-compose ps | grep "Up" | while read line; do
        SERVICE=$(echo "$line" | awk '{print $1}')
        STATUS=$(echo "$line" | awk '{print $NF}')
        if [ "$STATUS" == "healthy" ]; then
            echo -e "  ${GREEN}✓${NC} $SERVICE: healthy"
        elif [ "$STATUS" == "unhealthy" ]; then
            echo -e "  ${RED}✗${NC} $SERVICE: unhealthy"
        else
            echo -e "  ${YELLOW}⚠${NC} $SERVICE: $STATUS"
        fi
    done
else
    echo -e "${RED}✗${NC} Docker Compose is not running"
fi
echo ""

# Check vmagent
echo "2. vmagent"
echo "----------"
if curl -s http://localhost:8429/metrics > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Metrics endpoint responding"

    # Check remote write status
    REMOTE_WRITE_ERRORS=$(curl -s http://localhost:8429/metrics | grep "vmagent_remote_write_errors_total" | awk '{print $2}' | head -1 || echo "0")
    if [ "$REMOTE_WRITE_ERRORS" != "0" ] && [ -n "$REMOTE_WRITE_ERRORS" ]; then
        echo -e "  ${YELLOW}⚠${NC} Remote write errors: $REMOTE_WRITE_ERRORS"
    else
        echo -e "  ${GREEN}✓${NC} Remote write: OK"
    fi
else
    echo -e "${RED}✗${NC} Metrics endpoint not responding"
fi
echo ""

# Check YACE
echo "3. YACE (AWS CloudWatch Exporter)"
echo "----------------------------------"
if curl -s http://localhost:5000/metrics > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Metrics endpoint responding"

    AWS_METRICS=$(curl -s http://localhost:5000/metrics | grep -c "aws_" || echo "0")
    if [ "$AWS_METRICS" -gt 0 ]; then
        echo -e "  ${GREEN}✓${NC} Exposing $AWS_METRICS AWS metrics"
    else
        echo -e "  ${YELLOW}⚠${NC} No AWS metrics found (may be normal if no resources)"
    fi
else
    echo -e "${RED}✗${NC} Metrics endpoint not responding"
fi
echo ""

# Check Stackdriver Exporter
echo "4. Stackdriver Exporter (GCP)"
echo "-----------------------------"
if curl -s http://localhost:9255/metrics > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Metrics endpoint responding"

    GCP_METRICS=$(curl -s http://localhost:9255/metrics | grep -c "stackdriver" || echo "0")
    if [ "$GCP_METRICS" -gt 0 ]; then
        echo -e "  ${GREEN}✓${NC} Exposing $GCP_METRICS GCP metrics"
    else
        echo -e "  ${YELLOW}⚠${NC} No GCP metrics found (may be normal if no resources)"
    fi
else
    echo -e "${RED}✗${NC} Metrics endpoint not responding"
fi
echo ""

# Check Node Exporter
echo "5. Node Exporter"
echo "---------------"
if curl -s http://localhost:9100/metrics > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Metrics endpoint responding"
else
    echo -e "${RED}✗${NC} Metrics endpoint not responding"
fi
echo ""

# Check cAdvisor
echo "6. cAdvisor"
echo "-----------"
if curl -s http://localhost:8081/metrics > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Metrics endpoint responding"
else
    echo -e "${RED}✗${NC} Metrics endpoint not responding"
fi
echo ""

# System Resources
echo "7. System Resources"
echo "-------------------"
if command -v free &> /dev/null; then
    MEMORY_USAGE=$(free | grep Mem | awk '{printf "%.1f", $3/$2 * 100.0}')
    echo "  Memory usage: ${MEMORY_USAGE}%"
fi

if command -v df &> /dev/null; then
    DISK_USAGE=$(df -h / | tail -1 | awk '{print $5}' | sed 's/%//')
    echo "  Disk usage: ${DISK_USAGE}%"
fi
echo ""

echo "=========================================="
echo "Health Check Complete"
echo "=========================================="
echo ""
echo "For detailed logs: docker-compose logs -f [service-name]"
echo ""
