#!/bin/bash
# Test AWS Connection Script
# Verifies AWS credentials and CloudWatch access

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

echo "Testing AWS Connection..."
echo ""

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo -e "${YELLOW}Warning: AWS CLI not installed. Skipping some tests.${NC}"
    echo ""
fi

# Test 1: Check environment variables
echo "1. Checking environment variables..."
if [ -z "${AWS_ACCESS_KEY_ID:-}" ]; then
    echo -e "${RED}✗${NC} AWS_ACCESS_KEY_ID not set"
    exit 1
fi
echo -e "${GREEN}✓${NC} AWS_ACCESS_KEY_ID is set"

if [ -z "${AWS_SECRET_ACCESS_KEY:-}" ]; then
    echo -e "${RED}✗${NC} AWS_SECRET_ACCESS_KEY not set"
    exit 1
fi
echo -e "${GREEN}✓${NC} AWS_SECRET_ACCESS_KEY is set"

if [ -z "${AWS_REGION:-}" ]; then
    echo -e "${RED}✗${NC} AWS_REGION not set"
    exit 1
fi
echo -e "${GREEN}✓${NC} AWS_REGION is set: ${AWS_REGION}"
echo ""

# Test 2: Verify AWS identity
if command -v aws &> /dev/null; then
    echo "2. Verifying AWS identity..."
    IDENTITY=$(AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY_ID" \
               AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY" \
               aws sts get-caller-identity --region "$AWS_REGION" 2>&1)

    if echo "$IDENTITY" | grep -q "arn:aws"; then
        USER_ARN=$(echo "$IDENTITY" | jq -r '.Arn' 2>/dev/null || echo "$IDENTITY")
        echo -e "${GREEN}✓${NC} AWS identity verified: $USER_ARN"
    else
        echo -e "${RED}✗${NC} Failed to verify AWS identity"
        echo "Error: $IDENTITY"
        exit 1
    fi
    echo ""

    # Test 3: Test CloudWatch access
    echo "3. Testing CloudWatch API access..."
    CLOUDWATCH_TEST=$(AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY_ID" \
                     AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY" \
                     aws cloudwatch list-metrics --namespace AWS/Lambda --region "$AWS_REGION" --max-items 1 2>&1)

    if echo "$CLOUDWATCH_TEST" | grep -q "Metrics\|NextToken"; then
        echo -e "${GREEN}✓${NC} CloudWatch API accessible"
    else
        echo -e "${RED}✗${NC} CloudWatch API access failed"
        echo "Error: $CLOUDWATCH_TEST"
        exit 1
    fi
    echo ""

    # Test 4: Test Lambda discovery
    echo "4. Testing Lambda function discovery..."
    LAMBDA_TEST=$(AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY_ID" \
                 AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY" \
                 aws lambda list-functions --region "$AWS_REGION" --max-items 1 2>&1)

    if echo "$LAMBDA_TEST" | grep -q "Functions\|NextMarker"; then
        LAMBDA_COUNT=$(echo "$LAMBDA_TEST" | jq -r '.Functions | length' 2>/dev/null || echo "0")
        echo -e "${GREEN}✓${NC} Lambda functions discoverable (found at least $LAMBDA_COUNT)"
    else
        echo -e "${YELLOW}⚠${NC} Lambda discovery test inconclusive (may not have Lambda functions)"
    fi
    echo ""
else
    echo -e "${YELLOW}Skipping AWS CLI tests (AWS CLI not installed)${NC}"
    echo ""
fi

# Test 5: Test YACE exporter (if running)
echo "5. Testing YACE exporter..."
if curl -s http://localhost:5000/metrics 2>&1 | grep -q "aws_"; then
    echo -e "${GREEN}✓${NC} YACE exporter is running and exposing metrics"
else
    echo -e "${YELLOW}⚠${NC} YACE exporter not responding (may not be started yet)"
fi

echo ""
echo "=========================================="
echo -e "${GREEN}AWS Connection Test Complete!${NC}"
echo "=========================================="
