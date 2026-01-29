#!/bin/bash
# Interactive Grafana Cloud Setup Script
# Guides user through Grafana Cloud account setup and credential collection

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$PROJECT_ROOT/.env"

echo "=========================================="
echo "Grafana Cloud Setup"
echo "=========================================="
echo ""
echo "This script will help you configure Grafana Cloud credentials."
echo ""

# Check if .env already exists
if [ -f "$ENV_FILE" ]; then
    echo -e "${YELLOW}Warning: .env file already exists.${NC}"
    read -p "Do you want to update Grafana Cloud credentials? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Exiting without changes."
        exit 0
    fi
fi

echo ""
echo "Step 1: Grafana Cloud Account"
echo "----------------------------"
echo "If you don't have a Grafana Cloud account:"
echo "  1. Visit: https://grafana.com/auth/sign-up"
echo "  2. Sign up for a free account"
echo "  3. Create a new stack (or use existing)"
echo ""
read -p "Press Enter when you have a Grafana Cloud account..."

echo ""
echo "Step 2: Get Remote Write URL and Credentials"
echo "--------------------------------------------"
echo "1. Log in to Grafana Cloud: https://grafana.com/login"
echo "2. Go to: Your Stack → Details → Send metrics"
echo "3. Copy the following values:"
echo "   - Remote Write URL"
echo "   - Username (numeric ID)"
echo "   - API Key (Metrics Publisher)"
echo ""

read -p "Enter Remote Write URL: " PROM_URL
read -p "Enter Username (numeric ID): " USERNAME
read -p "Enter API Key (Metrics Publisher): " API_KEY

echo ""
echo "Step 3: Get Grafana Cloud Instance URL and API Token"
echo "-----------------------------------------------------"
echo "For dashboard provisioning, you'll need:"
echo "1. Your Grafana Cloud instance URL (e.g., https://YOUR-STACK.grafana.net)"
echo "2. An API token with Admin permissions"
echo ""
echo "To create an API token:"
echo "  1. Go to: https://grafana.com/orgs/YOUR_ORG/api-keys"
echo "  2. Click 'New API Key'"
echo "  3. Name: 'Dashboard Provisioner'"
echo "  4. Role: Admin"
echo "  5. Copy the token"
echo ""

read -p "Enter Grafana Cloud Instance URL: " GRAFANA_URL
read -p "Enter API Token (Admin): " API_TOKEN

# Validate inputs
if [ -z "$PROM_URL" ] || [ -z "$USERNAME" ] || [ -z "$API_KEY" ] || [ -z "$GRAFANA_URL" ] || [ -z "$API_TOKEN" ]; then
    echo "Error: All fields are required!"
    exit 1
fi

# Create or update .env file
echo ""
echo "Step 4: Saving credentials to .env file"
echo "----------------------------------------"

if [ ! -f "$ENV_FILE" ]; then
    # Create .env from .env.example if it doesn't exist
    if [ -f "$PROJECT_ROOT/.env.example" ]; then
        cp "$PROJECT_ROOT/.env.example" "$ENV_FILE"
        echo "Created .env from .env.example"
    else
        touch "$ENV_FILE"
        echo "Created new .env file"
    fi
fi

# Update Grafana Cloud variables in .env
# Use sed to update or add variables
update_env_var() {
    local var_name=$1
    local var_value=$2

    if grep -q "^${var_name}=" "$ENV_FILE"; then
        # Update existing variable
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS
            sed -i '' "s|^${var_name}=.*|${var_name}=${var_value}|" "$ENV_FILE"
        else
            # Linux
            sed -i "s|^${var_name}=.*|${var_name}=${var_value}|" "$ENV_FILE"
        fi
    else
        # Add new variable
        echo "${var_name}=${var_value}" >> "$ENV_FILE"
    fi
}

update_env_var "GRAFANA_CLOUD_PROMETHEUS_URL" "$PROM_URL"
update_env_var "GRAFANA_CLOUD_USERNAME" "$USERNAME"
update_env_var "GRAFANA_CLOUD_API_KEY" "$API_KEY"
update_env_var "GRAFANA_CLOUD_URL" "$GRAFANA_URL"
update_env_var "GRAFANA_CLOUD_API_TOKEN" "$API_TOKEN"

echo -e "${GREEN}✓${NC} Credentials saved to .env file"

# Test connection
echo ""
echo "Step 5: Testing connection"
echo "---------------------------"
echo "Testing remote write connection..."

# Extract query URL from push URL
QUERY_URL="${PROM_URL/\/push/\/query}"

if curl -s -G "$QUERY_URL" \
    --data-urlencode 'query=up{job="vmagent"}' \
    -u "$USERNAME:$API_KEY" | grep -q "data"; then
    echo -e "${GREEN}✓${NC} Connection successful!"
else
    echo -e "${YELLOW}⚠${NC} Could not verify connection. This is normal if vmagent hasn't started yet."
fi

echo ""
echo "=========================================="
echo "Setup Complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "  1. Fill in AWS and GCP credentials in .env"
echo "  2. Run: ./scripts/setup.sh"
echo ""
