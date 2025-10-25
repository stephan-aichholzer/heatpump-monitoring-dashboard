#!/bin/bash
#
# Modbus Monitoring Stack Backup Script
# Creates a complete backup including git repository, docker volumes, and configuration
#
# Usage: ./backup.sh --output backup_2025_10_5.tar.gz
#        ./backup.sh                          (auto-generates filename with timestamp)

set -euo pipefail

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_NAME="heatpump_dashboard"
DOCKER_COMPOSE_FILE="$SCRIPT_DIR/docker-compose.yml"

# Parse arguments
OUTPUT_FILE=""
while [[ $# -gt 0 ]]; do
    case $1 in
        --output|-o)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [--output FILENAME]"
            echo ""
            echo "Options:"
            echo "  --output, -o    Specify output filename (default: backup_YYYYMMDD_HHMMSS.tar.gz)"
            echo "  --help, -h      Show this help message"
            echo ""
            echo "Example:"
            echo "  $0 --output backup_2025_10_5.tar.gz"
            exit 0
            ;;
        *)
            echo -e "${RED}Error: Unknown argument $1${NC}"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Generate default filename if not provided
if [[ -z "$OUTPUT_FILE" ]]; then
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    OUTPUT_FILE="backup_${TIMESTAMP}.tar.gz"
fi

# Convert to absolute path if relative
if [[ ! "$OUTPUT_FILE" = /* ]]; then
    OUTPUT_FILE="$(pwd)/$OUTPUT_FILE"
fi

echo -e "${GREEN}=== Heat Pump Dashboard Backup ===${NC}"
echo ""
echo "Project directory: $SCRIPT_DIR"
echo "Output file: $OUTPUT_FILE"
echo ""

# Create temporary backup directory
TEMP_DIR=$(mktemp -d)
BACKUP_DIR="$TEMP_DIR/heatpump_dashboard_backup"
mkdir -p "$BACKUP_DIR"

cleanup() {
    echo -e "${YELLOW}Cleaning up temporary files...${NC}"
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

# Step 1: Clone git repository
echo -e "${GREEN}[1/4] Cloning git repository...${NC}"
cd "$SCRIPT_DIR"

# Get current branch and commit
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
CURRENT_COMMIT=$(git rev-parse HEAD)
CURRENT_COMMIT_SHORT=$(git rev-parse --short HEAD)

echo "  Current branch: $CURRENT_BRANCH"
echo "  Current commit: $CURRENT_COMMIT_SHORT"

# Check for uncommitted changes
if ! git diff-index --quiet HEAD -- 2>/dev/null; then
    echo -e "  ${YELLOW}Warning: Uncommitted changes detected!${NC}"
    HAS_CHANGES=true
else
    HAS_CHANGES=false
fi

# Create a clean clone
git clone "$SCRIPT_DIR" "$BACKUP_DIR/repository" --quiet
cd "$BACKUP_DIR/repository"
git checkout "$CURRENT_BRANCH" --quiet

# If there were uncommitted changes, create a patch
if [[ "$HAS_CHANGES" = true ]]; then
    echo -e "  ${YELLOW}Creating patch for uncommitted changes...${NC}"
    cd "$SCRIPT_DIR"
    git diff HEAD > "$BACKUP_DIR/uncommitted_changes.patch"
    git diff --cached > "$BACKUP_DIR/staged_changes.patch"
fi

# Save backup metadata
cat > "$BACKUP_DIR/backup_metadata.txt" <<EOF
Backup Created: $(date -Iseconds)
Git Branch: $CURRENT_BRANCH
Git Commit: $CURRENT_COMMIT
Git Commit (short): $CURRENT_COMMIT_SHORT
Uncommitted Changes: $HAS_CHANGES
Hostname: $(hostname)
User: $(whoami)
Docker Compose Project: ${PROJECT_NAME}
EOF

# Step 2: Export Docker volumes
echo -e "${GREEN}[2/4] Backing up Docker volumes...${NC}"
cd "$SCRIPT_DIR"

# Check if containers are running
if ! docker-compose ps | grep -q "Up"; then
    echo -e "  ${YELLOW}Warning: Some containers are not running${NC}"
fi

# Backup Prometheus data
echo "  Backing up prometheus_data volume..."
mkdir -p "$BACKUP_DIR/volumes"
docker run --rm \
    -v ${PROJECT_NAME}_prometheus_data:/data \
    -v "$BACKUP_DIR/volumes":/backup \
    alpine \
    tar czf /backup/prometheus_data.tar.gz -C /data .

PROM_SIZE=$(du -sh "$BACKUP_DIR/volumes/prometheus_data.tar.gz" | cut -f1)
echo "    Size: $PROM_SIZE"

# Backup Grafana data
echo "  Backing up grafana_data volume..."
docker run --rm \
    -v ${PROJECT_NAME}_grafana_data:/data \
    -v "$BACKUP_DIR/volumes":/backup \
    alpine \
    tar czf /backup/grafana_data.tar.gz -C /data .

GRAFANA_SIZE=$(du -sh "$BACKUP_DIR/volumes/grafana_data.tar.gz" | cut -f1)
echo "    Size: $GRAFANA_SIZE"

# Step 3: Export Grafana dashboards (human-readable backup)
echo -e "${GREEN}[3/4] Exporting Grafana dashboards...${NC}"
mkdir -p "$BACKUP_DIR/grafana_export"

# Check if Grafana is accessible
if curl -s http://localhost:3000/api/health > /dev/null 2>&1; then
    # Export all dashboards (requires Grafana API)
    # Try to use credentials from environment variables, fallback to default
    GRAFANA_USER="${GRAFANA_USER:-admin}"
    GRAFANA_PASS="${GRAFANA_PASS:-admin}"

    echo "  Testing Grafana API access..."
    API_TEST=$(curl -s -u "$GRAFANA_USER:$GRAFANA_PASS" http://localhost:3000/api/search?type=dash-db 2>/dev/null || echo "[]")
    if ! echo "$API_TEST" | grep -q "Invalid username or password"; then
        echo "  Exporting dashboard list..."
        DASHBOARDS=$(curl -s -u "$GRAFANA_USER:$GRAFANA_PASS" http://localhost:3000/api/search?type=dash-db 2>/dev/null || echo "[]")
        echo "$DASHBOARDS" > "$BACKUP_DIR/grafana_export/dashboard_list.json"

        DASHBOARD_COUNT=$(echo "$DASHBOARDS" | grep -o '"uid"' | wc -l)
        echo "  Found $DASHBOARD_COUNT dashboards"

        # Export each dashboard
        if [[ "$DASHBOARD_COUNT" -gt 0 ]]; then
            echo "$DASHBOARDS" | grep -o '"uid":"[^"]*"' | cut -d'"' -f4 | while read -r uid; do
                DASH_JSON=$(curl -s -u "$GRAFANA_USER:$GRAFANA_PASS" "http://localhost:3000/api/dashboards/uid/$uid" 2>/dev/null)
                DASH_TITLE=$(echo "$DASH_JSON" | grep -o '"title":"[^"]*"' | head -1 | cut -d'"' -f4 | tr ' ' '_')
                echo "    Exporting: $DASH_TITLE (uid: $uid)"
                echo "$DASH_JSON" > "$BACKUP_DIR/grafana_export/${uid}_${DASH_TITLE}.json"
            done
        fi

        # Export datasources
        echo "  Exporting datasources..."
        curl -s -u "$GRAFANA_USER:$GRAFANA_PASS" http://localhost:3000/api/datasources > "$BACKUP_DIR/grafana_export/datasources.json" 2>/dev/null || true
    else
        echo -e "  ${YELLOW}Warning: Grafana API authentication failed${NC}"
        echo -e "  ${YELLOW}Set GRAFANA_USER and GRAFANA_PASS environment variables for dashboard export${NC}"
        echo -e "  ${YELLOW}(Volume backup contains all dashboards)${NC}"
    fi
else
    echo -e "  ${YELLOW}Warning: Grafana not accessible, skipping dashboard export${NC}"
    echo -e "  ${YELLOW}(Volume backup contains all dashboards)${NC}"
fi

# Step 4: Create final archive
echo -e "${GREEN}[4/4] Creating final archive...${NC}"
cd "$TEMP_DIR"
tar czf "$OUTPUT_FILE" heatpump_dashboard_backup/

FINAL_SIZE=$(du -sh "$OUTPUT_FILE" | cut -f1)

echo ""
echo -e "${GREEN}=== Backup Complete ===${NC}"
echo ""
echo "Backup file: $OUTPUT_FILE"
echo "Total size: $FINAL_SIZE"
echo ""
echo "Contents:"
echo "  - Git repository (branch: $CURRENT_BRANCH)"
if [[ "$HAS_CHANGES" = true ]]; then
    echo "  - Uncommitted changes (as patch files)"
fi
echo "  - Prometheus data volume ($PROM_SIZE)"
echo "  - Grafana data volume ($GRAFANA_SIZE)"
echo "  - Grafana dashboards export (JSON)"
echo "  - Backup metadata"
echo ""
echo -e "${GREEN}To restore from this backup, use: tar xzf $OUTPUT_FILE${NC}"
echo ""
