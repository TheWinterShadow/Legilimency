#!/bin/bash
# Local Validation Script
# Runs all validation checks without requiring pre-commit framework
# Usage: ./scripts/validate.sh [--fix]

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_ROOT"

# Track failures
FAILURES=0

print_header() {
    echo ""
    echo -e "${BLUE}=== $1 ===${NC}"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
    FAILURES=$((FAILURES + 1))
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_skip() {
    echo -e "${YELLOW}○${NC} $1 (skipped)"
}

# Parse arguments
# shellcheck disable=SC2034  # FIX_MODE reserved for future auto-fix functionality
FIX_MODE=false
if [[ "${1:-}" == "--fix" ]]; then
    # shellcheck disable=SC2034
    FIX_MODE=true
    echo "Running in fix mode (auto-fix not yet implemented)"
fi

echo "=========================================="
echo "  Project Validation"
echo "=========================================="

# 1. JSON Validation
print_header "JSON Validation"

# Dashboards
for f in dashboards/*.json; do
    if [ -f "$f" ]; then
        if python3 -m json.tool "$f" > /dev/null 2>&1; then
            print_success "$(basename "$f")"
        else
            print_error "$(basename "$f") - Invalid JSON"
        fi
    fi
done

# IAM Policy
if python3 -m json.tool cloud-connectors/aws/iam-policy.json > /dev/null 2>&1; then
    print_success "iam-policy.json"
else
    print_error "iam-policy.json - Invalid JSON"
fi

# Contact points
if python3 -m json.tool configs/grafana-cloud/contact-points.json > /dev/null 2>&1; then
    print_success "contact-points.json"
else
    print_error "contact-points.json - Invalid JSON"
fi

# 2. Shell Script Validation
print_header "Shell Script Validation"

for f in scripts/*.sh tests/*.sh; do
    if [ -f "$f" ]; then
        if bash -n "$f" 2>/dev/null; then
            print_success "$(basename "$f")"
        else
            print_error "$(basename "$f") - Syntax error"
        fi
    fi
done

# Shellcheck if available
if command -v shellcheck &> /dev/null; then
    print_header "Shell Script Linting (shellcheck)"
    for f in scripts/*.sh tests/*.sh; do
        if [ -f "$f" ]; then
            if shellcheck -x --severity=error "$f" 2>/dev/null; then
                print_success "$(basename "$f")"
            else
                print_warning "$(basename "$f") - Has warnings (run shellcheck for details)"
            fi
        fi
    done
else
    print_skip "shellcheck not installed"
fi

# 3. Docker Compose Validation
print_header "Docker Compose Validation"

# Create temporary .env if needed
TEMP_ENV=false
if [ ! -f ".env" ]; then
    TEMP_ENV=true
    cat > .env << 'EOF'
GRAFANA_CLOUD_PROMETHEUS_URL=https://test.grafana.net/api/prom/push
GRAFANA_CLOUD_USERNAME=123456
GRAFANA_CLOUD_API_KEY=glc_test
AWS_ACCESS_KEY_ID=AKIATEST
AWS_SECRET_ACCESS_KEY=testsecret
AWS_REGION=us-east-1
AWS_REGIONS_TO_MONITOR=us-east-1
GCP_PROJECT_ID=test
GCP_KEY_PATH=./configs/test-key.json
EOF
    mkdir -p configs
    echo '{"type":"service_account"}' > configs/test-key.json
fi

if docker compose config > /dev/null 2>&1; then
    print_success "docker-compose.yml"
else
    print_error "docker-compose.yml - Invalid configuration"
fi

# Cleanup temp env
if [ "$TEMP_ENV" = true ]; then
    rm -f .env configs/test-key.json
fi

# 4. Terraform Validation
print_header "Terraform Validation"

if command -v terraform &> /dev/null; then
    # AWS
    if [ -d "terraform/aws" ]; then
        cd terraform/aws
        if terraform init -backend=false > /dev/null 2>&1 && terraform validate > /dev/null 2>&1; then
            print_success "terraform/aws"
        else
            print_error "terraform/aws - Invalid configuration"
        fi
        cd "$PROJECT_ROOT"
    fi

    # GCP
    if [ -d "terraform/gcp" ]; then
        cd terraform/gcp
        if terraform init -backend=false > /dev/null 2>&1 && terraform validate > /dev/null 2>&1; then
            print_success "terraform/gcp"
        else
            print_error "terraform/gcp - Invalid configuration"
        fi
        cd "$PROJECT_ROOT"
    fi
else
    print_skip "terraform not installed"
fi

# 5. YAML Validation (basic)
print_header "YAML Validation"

if command -v yamllint &> /dev/null; then
    for f in docker-compose.yml configs/prometheus.yml configs/yace-config.yml .github/workflows/*.yml; do
        if [ -f "$f" ]; then
            if yamllint -d relaxed "$f" > /dev/null 2>&1; then
                print_success "$(basename "$f")"
            else
                print_warning "$(basename "$f") - Has warnings"
            fi
        fi
    done
else
    # Fallback: basic Python YAML check
    if python3 -c "import yaml" 2>/dev/null; then
        for f in docker-compose.yml configs/prometheus.yml; do
            if [ -f "$f" ]; then
                if python3 -c "import yaml; yaml.safe_load(open('$f'))" 2>/dev/null; then
                    print_success "$(basename "$f")"
                else
                    print_error "$(basename "$f") - Invalid YAML"
                fi
            fi
        done
    else
        print_skip "yamllint and PyYAML not available"
    fi
fi

# 6. Secret Detection
print_header "Secret Detection"

# Check for potential AWS keys (exclude test files, workflows, and examples)
if grep -rE 'AKIA[0-9A-Z]{16}' --include='*.yml' --include='*.json' --include='*.sh' . 2>/dev/null | \
   grep -v '.example' | grep -v '.md' | grep -v '.baseline' | \
   grep -v '.github/workflows' | grep -v 'AKIATEST' | grep -v 'AKIAIOSFODNN7EXAMPLE'; then
    print_error "Potential AWS access key found in code"
else
    print_success "No AWS keys detected in code"
fi

# Check .env.example for real secrets (exclude obvious placeholders)
if [ -f ".env.example" ]; then
    # Look for real-looking secrets (not placeholders like xxx or REPLACE_WITH)
    if grep -E "(glc_[a-zA-Z0-9]{30,}|glsa_[a-zA-Z0-9]{30,})" .env.example 2>/dev/null | \
       grep -v 'REPLACE' | grep -v 'xxxx' | grep -v 'YOUR_' > /dev/null 2>&1; then
        print_error "Possible real Grafana secrets in .env.example"
    else
        print_success ".env.example appears safe"
    fi
fi

# 7. File Checks
print_header "File Checks"

# Check for .env file (should not exist in repo)
if [ -f ".env" ] && git ls-files --error-unmatch .env > /dev/null 2>&1; then
    print_error ".env file is tracked by git!"
else
    print_success ".env is not tracked by git"
fi

# Check executables have shebangs
for f in scripts/*.sh tests/*.sh; do
    if [ -f "$f" ]; then
        if head -1 "$f" | grep -q '^#!'; then
            print_success "$(basename "$f") has shebang"
        else
            print_error "$(basename "$f") missing shebang"
        fi
    fi
done

# Summary
echo ""
echo "=========================================="
if [ $FAILURES -eq 0 ]; then
    echo -e "${GREEN}All validations passed!${NC}"
    exit 0
else
    echo -e "${RED}$FAILURES validation(s) failed${NC}"
    exit 1
fi
