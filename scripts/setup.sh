#!/bin/bash
# Raspberry Pi Multi-Cloud Monitoring Setup Script
# This script automates the complete setup of the monitoring stack

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Functions
print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_info() {
    echo -e "  ${NC}$1"
}

# Step 1: Check prerequisites
echo "Step 1: Checking prerequisites..."
if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed. Please install Docker first."
    exit 1
fi
print_success "Docker is installed"

if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    print_error "Docker Compose is not installed. Please install Docker Compose first."
    exit 1
fi
print_success "Docker Compose is available"

# Step 2: Check .env file
echo ""
echo "Step 2: Checking configuration..."
if [ ! -f "$PROJECT_ROOT/.env" ]; then
    print_error ".env file not found!"
    print_info "Please copy .env.example to .env and fill in your credentials:"
    print_info "  cp .env.example .env"
    print_info "  nano .env"
    exit 1
fi
print_success ".env file exists"

# Load environment variables
set -a
source "$PROJECT_ROOT/.env"
set +a

# Step 3: Validate required environment variables
echo ""
echo "Step 3: Validating environment variables..."
REQUIRED_VARS=(
    "GRAFANA_CLOUD_PROMETHEUS_URL"
    "GRAFANA_CLOUD_USERNAME"
    "GRAFANA_CLOUD_API_KEY"
    "AWS_ACCESS_KEY_ID"
    "AWS_SECRET_ACCESS_KEY"
    "AWS_REGION"
    "GCP_PROJECT_ID"
    "GCP_KEY_PATH"
)

MISSING_VARS=()
for var in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!var:-}" ]; then
        MISSING_VARS+=("$var")
    fi
done

if [ ${#MISSING_VARS[@]} -ne 0 ]; then
    print_error "Missing required environment variables:"
    for var in "${MISSING_VARS[@]}"; do
        print_info "  - $var"
    done
    exit 1
fi
print_success "All required environment variables are set"

# Step 4: Test AWS credentials
echo ""
echo "Step 4: Testing AWS credentials..."
if command -v aws &> /dev/null; then
    if AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY_ID" AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY" \
       aws sts get-caller-identity --region "$AWS_REGION" &> /dev/null; then
        print_success "AWS credentials are valid"
    else
        print_warning "AWS credentials test failed. Continuing anyway..."
    fi
else
    print_warning "AWS CLI not installed. Skipping credential test."
fi

# Step 5: Test GCP credentials
echo ""
echo "Step 5: Testing GCP credentials..."
if [ -f "$PROJECT_ROOT/$GCP_KEY_PATH" ]; then
    print_success "GCP service account key file exists"
    if command -v gcloud &> /dev/null; then
        if GOOGLE_APPLICATION_CREDENTIALS="$PROJECT_ROOT/$GCP_KEY_PATH" \
           gcloud auth activate-service-account --key-file="$PROJECT_ROOT/$GCP_KEY_PATH" &> /dev/null; then
            print_success "GCP credentials are valid"
        else
            print_warning "GCP credentials test failed. Continuing anyway..."
        fi
    else
        print_warning "gcloud CLI not installed. Skipping credential test."
    fi
else
    print_error "GCP service account key file not found at: $GCP_KEY_PATH"
    exit 1
fi

# Step 6: Pull Docker images
echo ""
echo "Step 6: Pulling Docker images..."
cd "$PROJECT_ROOT"
if docker-compose pull 2>&1 | grep -q "error\|Error\|ERROR"; then
    print_error "Failed to pull some Docker images"
    exit 1
fi
print_success "Docker images pulled successfully"

# Step 7: Start containers
echo ""
echo "Step 7: Starting containers..."
if docker-compose up -d; then
    print_success "Containers started"
else
    print_error "Failed to start containers"
    exit 1
fi

# Step 8: Wait for health checks
echo ""
echo "Step 8: Waiting for services to become healthy..."
sleep 30
MAX_WAIT=120
ELAPSED=0
while [ $ELAPSED -lt $MAX_WAIT ]; do
    HEALTHY=$(docker-compose ps | grep -c "healthy" || true)
    TOTAL=$(docker-compose ps | grep -c "Up" || true)
    if [ "$HEALTHY" -eq "$TOTAL" ] && [ "$TOTAL" -gt 0 ]; then
        print_success "All services are healthy"
        break
    fi
    sleep 5
    ELAPSED=$((ELAPSED + 5))
    echo -n "."
done
echo ""

if [ $ELAPSED -ge $MAX_WAIT ]; then
    print_warning "Some services may not be healthy yet. Check status with: docker-compose ps"
fi

# Step 9: Verify metrics collection
echo ""
echo "Step 9: Verifying metrics collection..."
sleep 10

# Check vmagent metrics endpoint
if curl -s http://localhost:8429/metrics | grep -q "vmagent"; then
    print_success "vmagent is collecting metrics"
else
    print_warning "vmagent metrics endpoint not responding"
fi

# Check YACE metrics endpoint
if curl -s http://localhost:5000/metrics | grep -q "aws_"; then
    print_success "YACE is exposing AWS metrics"
else
    print_warning "YACE metrics endpoint not responding or no AWS metrics yet"
fi

# Check Stackdriver exporter metrics endpoint
if curl -s http://localhost:9255/metrics | grep -q "stackdriver"; then
    print_success "Stackdriver exporter is exposing GCP metrics"
else
    print_warning "Stackdriver exporter metrics endpoint not responding or no GCP metrics yet"
fi

# Step 10: Test remote write to Grafana Cloud
echo ""
echo "Step 10: Testing remote write to Grafana Cloud..."
sleep 10
if docker-compose logs vmagent 2>&1 | tail -20 | grep -q "successfully sent\|remote write"; then
    print_success "vmagent appears to be writing to Grafana Cloud"
else
    print_warning "Could not verify remote write. Check logs with: docker-compose logs vmagent"
fi

# Step 11: Summary
echo ""
echo "=========================================="
echo "Setup Complete!"
echo "=========================================="
echo ""
print_success "Monitoring stack is running"
echo ""
echo "Next steps:"
echo "  1. View container status: docker-compose ps"
echo "  2. View logs: docker-compose logs -f"
echo "  3. Upload dashboards: ./scripts/provision-dashboards.sh"
echo "  4. Access Grafana Cloud: ${GRAFANA_CLOUD_URL:-https://grafana.com}"
echo ""
echo "Useful commands:"
echo "  - Stop stack: docker-compose down"
echo "  - Restart stack: docker-compose restart"
echo "  - View logs: docker-compose logs -f [service-name]"
echo "  - Check health: ./scripts/monitor-health.sh"
echo ""
