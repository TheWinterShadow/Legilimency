#!/bin/bash
# Test GCP Connection Script
# Verifies GCP credentials and Cloud Monitoring API access

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

echo "Testing GCP Connection..."
echo ""

# Test 1: Check environment variables
echo "1. Checking environment variables..."
if [ -z "${GCP_PROJECT_ID:-}" ]; then
    echo -e "${RED}✗${NC} GCP_PROJECT_ID not set"
    exit 1
fi
echo -e "${GREEN}✓${NC} GCP_PROJECT_ID is set: ${GCP_PROJECT_ID}"

if [ -z "${GCP_KEY_PATH:-}" ]; then
    echo -e "${RED}✗${NC} GCP_KEY_PATH not set"
    exit 1
fi
echo -e "${GREEN}✓${NC} GCP_KEY_PATH is set: ${GCP_KEY_PATH}"
echo ""

# Test 2: Check service account key file
echo "2. Checking service account key file..."
KEY_FILE="$PROJECT_ROOT/$GCP_KEY_PATH"
if [ ! -f "$KEY_FILE" ]; then
    echo -e "${RED}✗${NC} Service account key file not found: $KEY_FILE"
    exit 1
fi
echo -e "${GREEN}✓${NC} Service account key file exists"

# Validate JSON structure
if ! jq -e . "$KEY_FILE" &> /dev/null; then
    echo -e "${RED}✗${NC} Service account key file is not valid JSON"
    exit 1
fi
echo -e "${GREEN}✓${NC} Service account key file is valid JSON"

# Extract service account email
SERVICE_ACCOUNT_EMAIL=$(jq -r '.client_email' "$KEY_FILE" 2>/dev/null || echo "")
if [ -z "$SERVICE_ACCOUNT_EMAIL" ] || [ "$SERVICE_ACCOUNT_EMAIL" == "null" ]; then
    echo -e "${RED}✗${NC} Could not extract service account email from key file"
    exit 1
fi
echo -e "${GREEN}✓${NC} Service account: $SERVICE_ACCOUNT_EMAIL"
echo ""

# Test 3: Verify project ID matches
KEY_PROJECT_ID=$(jq -r '.project_id' "$KEY_FILE" 2>/dev/null || echo "")
if [ "$KEY_PROJECT_ID" != "$GCP_PROJECT_ID" ] && [ -n "$KEY_PROJECT_ID" ]; then
    echo -e "${YELLOW}⚠${NC} Warning: Project ID in key file ($KEY_PROJECT_ID) differs from GCP_PROJECT_ID ($GCP_PROJECT_ID)"
fi
echo ""

# Test 4: Test gcloud CLI (if installed)
if command -v gcloud &> /dev/null; then
    echo "3. Testing gcloud authentication..."
    if GOOGLE_APPLICATION_CREDENTIALS="$KEY_FILE" \
       gcloud auth activate-service-account --key-file="$KEY_FILE" 2>&1; then
        echo -e "${GREEN}✓${NC} gcloud authentication successful"
    else
        echo -e "${YELLOW}⚠${NC} gcloud authentication test inconclusive"
    fi

    echo ""
    echo "4. Testing Cloud Monitoring API access..."
    MONITORING_TEST=$(GOOGLE_APPLICATION_CREDENTIALS="$KEY_FILE" \
                     gcloud monitoring metrics list --project="$GCP_PROJECT_ID" --limit=1 2>&1)

    if echo "$MONITORING_TEST" | grep -q "compute\|run\|pubsub"; then
        echo -e "${GREEN}✓${NC} Cloud Monitoring API accessible"
    elif echo "$MONITORING_TEST" | grep -q "PERMISSION_DENIED\|403"; then
        echo -e "${RED}✗${NC} Permission denied. Check service account has Monitoring Viewer role"
        exit 1
    else
        echo -e "${YELLOW}⚠${NC} Cloud Monitoring API test inconclusive (may not have metrics yet)"
    fi
    echo ""
else
    echo -e "${YELLOW}Skipping gcloud CLI tests (gcloud not installed)${NC}"
    echo ""
fi

# Test 5: Test Stackdriver exporter (if running)
echo "5. Testing Stackdriver exporter..."
if curl -s http://localhost:9255/metrics 2>&1 | grep -q "stackdriver"; then
    echo -e "${GREEN}✓${NC} Stackdriver exporter is running and exposing metrics"
else
    echo -e "${YELLOW}⚠${NC} Stackdriver exporter not responding (may not be started yet)"
fi

echo ""
echo "=========================================="
echo -e "${GREEN}GCP Connection Test Complete!${NC}"
echo "=========================================="
