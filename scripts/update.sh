#!/bin/bash
# Update Script
# Pulls latest Docker images and restarts the monitoring stack

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "Updating monitoring stack..."
echo ""

cd "$PROJECT_ROOT"

# Step 1: Pull latest images
echo "Step 1: Pulling latest Docker images..."
if docker-compose pull; then
    echo -e "${GREEN}✓${NC} Images pulled successfully"
else
    echo -e "${YELLOW}⚠${NC} Some images may have failed to pull"
fi
echo ""

# Step 2: Restart containers
echo "Step 2: Restarting containers..."
if docker-compose up -d; then
    echo -e "${GREEN}✓${NC} Containers restarted"
else
    echo -e "${YELLOW}⚠${NC} Some containers may have failed to restart"
fi
echo ""

# Step 3: Wait for health checks
echo "Step 3: Waiting for services to become healthy..."
sleep 10
MAX_WAIT=60
ELAPSED=0
while [ $ELAPSED -lt $MAX_WAIT ]; do
    HEALTHY=$(docker-compose ps | grep -c "healthy" || true)
    TOTAL=$(docker-compose ps | grep -c "Up" || true)
    if [ "$HEALTHY" -eq "$TOTAL" ] && [ "$TOTAL" -gt 0 ]; then
        echo -e "${GREEN}✓${NC} All services are healthy"
        break
    fi
    sleep 5
    ELAPSED=$((ELAPSED + 5))
    echo -n "."
done
echo ""

echo ""
echo "Update complete!"
echo ""
echo "Check status: docker-compose ps"
echo "View logs: docker-compose logs -f"
echo ""
