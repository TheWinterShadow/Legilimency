#!/bin/bash
# Pre-commit Setup Script
# Installs and configures pre-commit hooks for the project

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
echo "  Pre-commit Setup"
echo "=========================================="
echo ""

# Check if Python/pip is available
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}Error: Python 3 is required but not installed.${NC}"
    exit 1
fi

if ! command -v pip3 &> /dev/null && ! command -v pip &> /dev/null; then
    echo -e "${RED}Error: pip is required but not installed.${NC}"
    exit 1
fi

PIP_CMD="pip3"
if ! command -v pip3 &> /dev/null; then
    PIP_CMD="pip"
fi

# Check if pre-commit is installed
echo "Step 1: Checking pre-commit installation..."
if ! command -v pre-commit &> /dev/null; then
    echo "Installing pre-commit..."
    $PIP_CMD install pre-commit --user

    # Add to PATH if needed
    export PATH="$HOME/.local/bin:$PATH"

    if ! command -v pre-commit &> /dev/null; then
        echo -e "${YELLOW}Warning: pre-commit installed but not in PATH${NC}"
        echo "Add this to your shell profile: export PATH=\"\$HOME/.local/bin:\$PATH\""
        PRE_COMMIT_CMD="$HOME/.local/bin/pre-commit"
    else
        PRE_COMMIT_CMD="pre-commit"
    fi
else
    PRE_COMMIT_CMD="pre-commit"
fi
echo -e "${GREEN}✓${NC} pre-commit is available"

# Install git hooks
echo ""
echo "Step 2: Installing git hooks..."
if [ -d ".git" ]; then
    $PRE_COMMIT_CMD install
    echo -e "${GREEN}✓${NC} Git hooks installed"

    # Also install commit-msg hook for conventional commits (optional)
    # $PRE_COMMIT_CMD install --hook-type commit-msg
else
    echo -e "${RED}Error: Not a git repository${NC}"
    exit 1
fi

# Install hook environments
echo ""
echo "Step 3: Installing hook environments (this may take a while)..."
$PRE_COMMIT_CMD install-hooks
echo -e "${GREEN}✓${NC} Hook environments installed"

# Run initial validation
echo ""
echo "Step 4: Running initial validation..."
if $PRE_COMMIT_CMD run --all-files; then
    echo -e "${GREEN}✓${NC} All checks passed"
else
    echo -e "${YELLOW}⚠${NC} Some checks failed - please review and fix"
fi

echo ""
echo "=========================================="
echo "  Setup Complete!"
echo "=========================================="
echo ""
echo "Pre-commit hooks are now installed and will run automatically"
echo "before each commit."
echo ""
echo "Useful commands:"
echo "  pre-commit run --all-files    # Run all hooks on all files"
echo "  pre-commit run <hook-id>      # Run specific hook"
echo "  pre-commit autoupdate         # Update hook versions"
echo "  git commit --no-verify        # Skip hooks (use sparingly)"
echo ""
echo "To uninstall: pre-commit uninstall"
echo ""
