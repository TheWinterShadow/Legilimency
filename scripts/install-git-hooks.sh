#!/bin/bash
# Install Git Hooks Script
# Installs a simple pre-commit hook without requiring the pre-commit framework
#
# Usage: ./scripts/install-git-hooks.sh
#
# To uninstall: rm .git/hooks/pre-commit

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HOOKS_DIR="$PROJECT_ROOT/.git/hooks"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "Installing Git pre-commit hook..."

# Check if we're in a git repo
if [ ! -d "$PROJECT_ROOT/.git" ]; then
    echo "Error: Not a git repository"
    exit 1
fi

# Create hooks directory if it doesn't exist
mkdir -p "$HOOKS_DIR"

# Create the pre-commit hook
cat > "$HOOKS_DIR/pre-commit" << 'HOOK_EOF'
#!/bin/bash
# Pre-commit hook for Raspberry Pi Monitoring project
# Runs validation checks before allowing commits

set -e

# Get the project root
PROJECT_ROOT="$(git rev-parse --show-toplevel)"
cd "$PROJECT_ROOT"

echo "Running pre-commit checks..."

# Track if any checks fail
FAILED=0

# 1. Check JSON files
echo -n "Checking JSON files... "
for f in dashboards/*.json cloud-connectors/aws/iam-policy.json configs/grafana-cloud/contact-points.json; do
    if [ -f "$f" ]; then
        if ! python3 -m json.tool "$f" > /dev/null 2>&1; then
            echo "FAILED"
            echo "  Invalid JSON: $f"
            FAILED=1
        fi
    fi
done
[ $FAILED -eq 0 ] && echo "OK"

# 2. Check shell script syntax
echo -n "Checking shell scripts... "
SHELL_FAILED=0
for f in scripts/*.sh tests/*.sh; do
    if [ -f "$f" ]; then
        if ! bash -n "$f" 2>/dev/null; then
            echo "FAILED"
            echo "  Syntax error: $f"
            SHELL_FAILED=1
            FAILED=1
        fi
    fi
done
[ $SHELL_FAILED -eq 0 ] && echo "OK"

# 3. Check for secrets (exclude test files, workflows, and validation scripts)
echo -n "Checking for secrets... "
# Get staged files, excluding known safe files
STAGED_FILES=$(git diff --cached --name-only | \
    grep -v '\.example$' | grep -v '\.md$' | grep -v '^\.github/workflows/' | \
    grep -v 'validate\.sh$' | grep -v 'install-git-hooks\.sh$' | \
    grep -v 'pre-commit-' || true)
# Check remaining files for AWS keys, excluding those with test key patterns
SECRETS_FOUND=""
if [ -n "$STAGED_FILES" ]; then
    for f in $STAGED_FILES; do
        if [ -f "$f" ] && grep -q 'AKIA[0-9A-Z]\{16\}' "$f" 2>/dev/null; then
            # Check if file contains only test/example keys
            if ! grep -q 'AKIATEST\|AKIAIOSFODNN7EXAMPLE' "$f" 2>/dev/null; then
                SECRETS_FOUND="$SECRETS_FOUND $f"
            fi
        fi
    done
fi
if [ -n "$SECRETS_FOUND" ]; then
    echo "FAILED"
    echo "  Potential AWS access key found in staged files!"
    echo "  Files:$SECRETS_FOUND"
    FAILED=1
else
    echo "OK"
fi

# 4. Check .env is not being committed
echo -n "Checking .env not staged... "
if git diff --cached --name-only | grep -q '^\.env$'; then
    echo "FAILED"
    echo "  .env file is staged for commit! Remove with: git reset HEAD .env"
    FAILED=1
else
    echo "OK"
fi

# 5. Check Docker Compose (if docker is available)
if command -v docker &> /dev/null; then
    echo -n "Checking docker-compose.yml... "
    if git diff --cached --name-only | grep -q 'docker-compose.yml'; then
        # Need to create temp .env for validation
        if [ ! -f ".env" ]; then
            cat > .env.tmp << 'EOF'
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
            echo '{}' > configs/test-key.json.tmp
            mv .env.tmp .env
            mv configs/test-key.json.tmp configs/test-key.json 2>/dev/null || true
            CLEANUP_ENV=1
        fi

        if docker compose config > /dev/null 2>&1; then
            echo "OK"
        else
            echo "FAILED"
            echo "  docker-compose.yml is invalid"
            FAILED=1
        fi

        # Cleanup
        if [ "${CLEANUP_ENV:-0}" = "1" ]; then
            rm -f .env configs/test-key.json
        fi
    else
        echo "OK (not modified)"
    fi
fi

# Summary
echo ""
if [ $FAILED -eq 0 ]; then
    echo "All pre-commit checks passed!"
    exit 0
else
    echo "Pre-commit checks failed. Please fix the issues above."
    echo "To bypass (not recommended): git commit --no-verify"
    exit 1
fi
HOOK_EOF

# Make the hook executable
chmod +x "$HOOKS_DIR/pre-commit"

echo -e "${GREEN}✓${NC} Pre-commit hook installed successfully!"
echo ""
echo "The hook will run automatically before each commit."
echo ""
echo "To uninstall: rm .git/hooks/pre-commit"
echo "To bypass (not recommended): git commit --no-verify"
echo ""
echo -e "${YELLOW}Note:${NC} For more comprehensive checks, install pre-commit framework:"
echo "  pip install pre-commit && pre-commit install"
