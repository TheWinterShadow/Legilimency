#!/bin/bash
# Pre-commit hook helper: Check .env.example has no real secrets

set -euo pipefail

# Check for real-looking Grafana API keys (not obvious placeholders)
if grep -E "glc_[a-zA-Z0-9]{20,}" .env.example 2>/dev/null | \
   grep -v "REPLACE" | grep -v "YOUR_" | grep -v "xxxx" | grep -q .; then
    echo "Possible real Grafana API key in .env.example!"
    exit 1
fi

# Check for real-looking Grafana service account tokens
if grep -E "glsa_[a-zA-Z0-9]{20,}" .env.example 2>/dev/null | \
   grep -v "REPLACE" | grep -v "YOUR_" | grep -v "xxxx" | grep -q .; then
    echo "Possible real Grafana token in .env.example!"
    exit 1
fi

# Check for real AWS access keys (exclude known example/test keys)
if grep -E "AKIA[A-Z0-9]{16}" .env.example 2>/dev/null | \
   grep -v "AKIAIOSFODNN7EXAMPLE" | grep -v "AKIATEST" | grep -q .; then
    echo "Possible real AWS key in .env.example!"
    exit 1
fi

echo "No real secrets detected in .env.example"
exit 0
