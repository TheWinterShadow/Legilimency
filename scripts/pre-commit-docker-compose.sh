#!/bin/bash
# Pre-commit hook helper: Validate Docker Compose
# Creates temporary .env if needed for validation

set -euo pipefail

CLEANUP=0

if [ ! -f ".env" ]; then
    cat > .env << 'ENVEOF'
GRAFANA_CLOUD_PROMETHEUS_URL=https://test.grafana.net/api/prom/push
GRAFANA_CLOUD_USERNAME=123456
GRAFANA_CLOUD_API_KEY=glc_test
AWS_ACCESS_KEY_ID=AKIATEST123456789012
AWS_SECRET_ACCESS_KEY=testsecretkey12345678901234567890
AWS_REGION=us-east-1
AWS_REGIONS_TO_MONITOR=us-east-1
GCP_PROJECT_ID=test
GCP_KEY_PATH=./test-key.json
ENVEOF
    echo '{}' > test-key.json
    CLEANUP=1
fi

docker compose config > /dev/null 2>&1
RESULT=$?

if [ "$CLEANUP" = "1" ]; then
    rm -f .env test-key.json
fi

exit $RESULT
