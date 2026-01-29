#!/bin/bash
# Dashboard Provisioning Script
# Uploads all Grafana dashboards to Grafana Cloud

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DASHBOARDS_DIR="$PROJECT_ROOT/dashboards"

# Load environment variables
if [ ! -f "$PROJECT_ROOT/.env" ]; then
    echo -e "${RED}Error: .env file not found!${NC}"
    echo "Please run ./scripts/grafana-cloud-setup.sh first"
    exit 1
fi

set -a
source "$PROJECT_ROOT/.env"
set +a

# Check required variables
if [ -z "${GRAFANA_CLOUD_URL:-}" ] || [ -z "${GRAFANA_CLOUD_API_TOKEN:-}" ]; then
    echo -e "${RED}Error: GRAFANA_CLOUD_URL and GRAFANA_CLOUD_API_TOKEN must be set in .env${NC}"
    exit 1
fi

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo -e "${RED}Error: jq is required but not installed.${NC}"
    echo "Install with: sudo apt-get install jq (or brew install jq on macOS)"
    exit 1
fi

GRAFANA_URL="${GRAFANA_CLOUD_URL}"
API_KEY="${GRAFANA_CLOUD_API_TOKEN}"
FOLDER_NAME="Homelab Monitoring"

echo "=========================================="
echo "Dashboard Provisioning"
echo "=========================================="
echo ""
echo "Grafana URL: $GRAFANA_URL"
echo "Folder: $FOLDER_NAME"
echo ""

# Create or get folder ID
echo "Step 1: Creating/verifying folder..."
FOLDER_RESPONSE=$(curl -s -X GET "${GRAFANA_URL}/api/folders" \
    -H "Authorization: Bearer ${API_KEY}" \
    -H "Content-Type: application/json" 2>&1)

if echo "$FOLDER_RESPONSE" | grep -q "Invalid API key\|401\|403"; then
    echo -e "${RED}Error: Invalid API token or insufficient permissions${NC}"
    exit 1
fi

FOLDER_ID=$(echo "$FOLDER_RESPONSE" | jq -r ".[] | select(.title==\"${FOLDER_NAME}\") | .id" | head -1)

if [ -z "$FOLDER_ID" ] || [ "$FOLDER_ID" == "null" ]; then
    echo "Creating folder: $FOLDER_NAME"
    FOLDER_CREATE_RESPONSE=$(curl -s -X POST "${GRAFANA_URL}/api/folders" \
        -H "Authorization: Bearer ${API_KEY}" \
        -H "Content-Type: application/json" \
        -d "{\"title\": \"${FOLDER_NAME}\"}" 2>&1)

    FOLDER_ID=$(echo "$FOLDER_CREATE_RESPONSE" | jq -r '.id')

    if [ -z "$FOLDER_ID" ] || [ "$FOLDER_ID" == "null" ]; then
        echo -e "${RED}Error: Failed to create folder${NC}"
        echo "Response: $FOLDER_CREATE_RESPONSE"
        exit 1
    fi

    echo -e "${GREEN}✓${NC} Folder created (ID: $FOLDER_ID)"
else
    echo -e "${GREEN}✓${NC} Folder exists (ID: $FOLDER_ID)"
fi

# Upload dashboards
echo ""
echo "Step 2: Uploading dashboards..."
echo ""

DASHBOARD_FILES=("$DASHBOARDS_DIR"/*.json)
SUCCESS_COUNT=0
FAIL_COUNT=0

for dashboard_file in "${DASHBOARD_FILES[@]}"; do
    if [ ! -f "$dashboard_file" ]; then
        continue
    fi

    DASHBOARD_NAME=$(basename "$dashboard_file" .json)
    echo -n "Uploading $DASHBOARD_NAME... "

    # Read and prepare dashboard JSON
    DASHBOARD_JSON=$(cat "$dashboard_file")

    # Wrap in Grafana API format
    PAYLOAD=$(jq -n \
        --arg folderId "$FOLDER_ID" \
        --argjson dashboard "$DASHBOARD_JSON" \
        '{dashboard: $dashboard, folderId: ($folderId | tonumber), overwrite: true}')

    # Upload dashboard
    RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "${GRAFANA_URL}/api/dashboards/db" \
        -H "Authorization: Bearer ${API_KEY}" \
        -H "Content-Type: application/json" \
        -d "$PAYLOAD" 2>&1)

    HTTP_CODE=$(echo "$RESPONSE" | tail -1)
    BODY=$(echo "$RESPONSE" | sed '$d')

    if [ "$HTTP_CODE" == "200" ] || [ "$HTTP_CODE" == "201" ]; then
        echo -e "${GREEN}✓${NC}"
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    else
        echo -e "${RED}✗${NC} (HTTP $HTTP_CODE)"
        echo "  Error: $(echo "$BODY" | jq -r '.message // .error // "Unknown error"' 2>/dev/null || echo "$BODY")"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
done

echo ""
echo "=========================================="
echo "Provisioning Complete!"
echo "=========================================="
echo ""
echo "Successfully uploaded: $SUCCESS_COUNT dashboards"
if [ $FAIL_COUNT -gt 0 ]; then
    echo -e "${YELLOW}Failed: $FAIL_COUNT dashboards${NC}"
fi
echo ""
echo "View dashboards at: ${GRAFANA_URL}/dashboards"
echo ""
