#!/bin/bash
# Backup Script
# Backs up configuration files and credentials securely

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BACKUP_DIR="$PROJECT_ROOT/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="monitoring-backup-${TIMESTAMP}"
BACKUP_PATH="$BACKUP_DIR/$BACKUP_NAME"

echo "Creating backup..."
echo ""

# Create backup directory
mkdir -p "$BACKUP_PATH"

# Backup configuration files
echo "Backing up configuration files..."
cp -r "$PROJECT_ROOT/configs" "$BACKUP_PATH/" 2>/dev/null || true
cp "$PROJECT_ROOT/docker-compose.yml" "$BACKUP_PATH/" 2>/dev/null || true
cp "$PROJECT_ROOT/.env.example" "$BACKUP_PATH/" 2>/dev/null || true
echo -e "${GREEN}✓${NC} Configuration files backed up"

# Backup .env file (with warning)
if [ -f "$PROJECT_ROOT/.env" ]; then
    echo ""
    echo -e "${YELLOW}Warning: .env file contains sensitive credentials${NC}"
    read -p "Backup .env file? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        cp "$PROJECT_ROOT/.env" "$BACKUP_PATH/.env"
        echo -e "${GREEN}✓${NC} .env file backed up"
        echo -e "${YELLOW}⚠${NC} Keep backup secure - it contains credentials!"
    else
        echo "Skipping .env backup"
    fi
fi

# Backup GCP service account key (if exists)
if [ -f "$PROJECT_ROOT/configs/gcp-service-account-key.json" ]; then
    echo ""
    echo -e "${YELLOW}Warning: GCP service account key contains sensitive credentials${NC}"
    read -p "Backup GCP service account key? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        mkdir -p "$BACKUP_PATH/configs"
        cp "$PROJECT_ROOT/configs/gcp-service-account-key.json" "$BACKUP_PATH/configs/"
        echo -e "${GREEN}✓${NC} GCP service account key backed up"
        echo -e "${YELLOW}⚠${NC} Keep backup secure - it contains credentials!"
    else
        echo "Skipping GCP key backup"
    fi
fi

# Create backup info file
cat > "$BACKUP_PATH/backup-info.txt" << EOF
Backup created: $(date)
Project: Raspberry Pi Multi-Cloud Monitoring
Backup contents:
- Configuration files (configs/)
- Docker Compose file
- Environment template (.env.example)
EOF

if [ -f "$BACKUP_PATH/.env" ]; then
    echo "- Environment file (.env) - CONTAINS SENSITIVE DATA" >> "$BACKUP_PATH/backup-info.txt"
fi

if [ -f "$BACKUP_PATH/configs/gcp-service-account-key.json" ]; then
    echo "- GCP service account key - CONTAINS SENSITIVE DATA" >> "$BACKUP_PATH/backup-info.txt"
fi

# Create tar archive
echo ""
echo "Creating archive..."
cd "$BACKUP_DIR"
tar -czf "${BACKUP_NAME}.tar.gz" "$BACKUP_NAME" 2>/dev/null || {
    echo "Warning: Could not create tar archive (tar may not be installed)"
    echo "Backup files are in: $BACKUP_PATH"
    exit 0
}

# Remove uncompressed directory
rm -rf "$BACKUP_NAME"

echo -e "${GREEN}✓${NC} Backup created: ${BACKUP_NAME}.tar.gz"
echo ""
echo "Backup location: $BACKUP_DIR/${BACKUP_NAME}.tar.gz"
echo ""
echo -e "${YELLOW}Security reminder:${NC}"
echo "  - Keep backup files secure"
echo "  - Do not commit backups to git"
echo "  - Encrypt backups if storing off-site"
echo ""
